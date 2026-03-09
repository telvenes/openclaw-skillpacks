import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { exec as execCb } from "child_process";
import { promisify } from "util";
import fs from "fs";

const exec = promisify(execCb);

// Server-oppsett
const server = new Server(
  {
    name: "k8s-mcp-server",
    version: "1.0.0",
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// Hjelpefunksjon for å kjøre kubectl med in-cluster autentisering
async function runKubectl(args) {
  const saDir = "/var/run/secrets/kubernetes.io/serviceaccount";
  let authFlags = "";

  // Sjekker om vi kjører inne i en pod og legger til auth-flagg hvis ja
  if (fs.existsSync(saDir)) {
    const ca = `${saDir}/ca.crt`;
    const token = fs.readFileSync(`${saDir}/token`, "utf8").trim();
    const serverHost = process.env.KUBERNETES_SERVICE_HOST;
    const serverPort = process.env.KUBERNETES_SERVICE_PORT;
    const apiServer = `https://${serverHost}:${serverPort}`;

    authFlags = `--server=${apiServer} --certificate-authority=${ca} --token=${token}`;
  }

  // Antar at kubectl finnes i PATH. (Kan utvides med auto-nedlasting som i scriptet ditt)
  const command = `kubectl ${authFlags} ${args.join(" ")}`;
  
  try {
    const { stdout, stderr } = await exec(command);
    if (stderr && !stdout) {
      return { isError: true, content: stderr };
    }
    return { isError: false, content: stdout + (stderr ? `\nAdvarsler:\n${stderr}` : "") };
  } catch (error) {
    return { isError: true, content: error.message };
  }
}

// 1. Definer hvilke verktøy MCP-serveren tilbyr
server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "k8s_events",
      description: "Hent Kubernetes-events, sortert på siste tidsstempel.",
      inputSchema: {
        type: "object",
        properties: {
          namespace: { type: "string", description: "Namespace, eller '-A' for alle" }
        }
      }
    },
    {
      name: "k8s_get",
      description: "Kjør 'kubectl get' for å hente ressurser (read-only).",
      inputSchema: {
        type: "object",
        properties: {
          resource: { type: "string", description: "Ressurstype (f.eks. pods, svc)" },
          namespace: { type: "string", description: "Namespace" },
          args: { type: "string", description: "Ekstra argumenter som -o yaml eller --field-selector" }
        },
        required: ["resource"]
      }
    },
    {
      name: "k8s_describe",
      description: "Kjør 'kubectl describe' for detaljert info om en ressurs.",
      inputSchema: {
        type: "object",
        properties: {
          kind: { type: "string", description: "Ressurstype" },
          name: { type: "string", description: "Navn på ressursen" },
          namespace: { type: "string", description: "Namespace" }
        },
        required: ["kind", "name", "namespace"]
      }
    },
    {
      name: "k8s_logs",
      description: "Hent logger for en spesifikk pod.",
      inputSchema: {
        type: "object",
        properties: {
          pod: { type: "string", description: "Navn på pod" },
          namespace: { type: "string", description: "Namespace" },
          container: { type: "string", description: "Spesifikk container (valgfritt)" },
          tail: { type: "number", description: "Antall linjer fra slutten (valgfritt)" }
        },
        required: ["pod", "namespace"]
      }
    },
    {
      name: "k8s_health",
      description: "Sjekk klusterets helse og versjon.",
      inputSchema: {
        type: "object",
        properties: {}
      }
    }
  ]
}));

// 2. Håndter kjøringen av verktøyene
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;
  let kubectlArgs = [];

  switch (name) {
    case "k8s_events":
      const ns = args.namespace || "openclaw";
      kubectlArgs = ["get", "events", "--sort-by=.lastTimestamp"];
      if (ns === "-A" || ns === "--all-namespaces") {
        kubectlArgs.push("-A");
      } else {
        kubectlArgs.push("-n", ns);
      }
      break;

    case "k8s_get":
      kubectlArgs = ["get", args.resource];
      if (args.namespace) {
        if (args.namespace === "-A") kubectlArgs.push("-A");
        else kubectlArgs.push("-n", args.namespace);
      }
      if (args.args) kubectlArgs.push(...args.args.split(" "));
      break;

    case "k8s_describe":
      kubectlArgs = ["describe", args.kind, args.name, "-n", args.namespace];
      break;

    case "k8s_logs":
      kubectlArgs = ["logs", args.pod, "-n", args.namespace];
      if (args.container) kubectlArgs.push("-c", args.container);
      if (args.tail) kubectlArgs.push(`--tail=${args.tail}`);
      break;

    case "k8s_health":
      // Kjører versjon først
      const versionResult = await runKubectl(["version", "--client=true"]);
      const infoResult = await runKubectl(["cluster-info"]);
      return {
        content: [
          { type: "text", text: `${versionResult.content}\n---\n${infoResult.content}` }
        ]
      };

    default:
      throw new Error(`Ukjent verktøy: ${name}`);
  }

  const result = await runKubectl(kubectlArgs);
  return {
    content: [{ type: "text", text: result.content }],
    isError: result.isError,
  };
});

// Start serveren med Stdio (Standard I/O brukes for å kommunisere med MCP-klienter)
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("K8s MCP Server kjører via stdio");
}

main().catch((error) => console.error("Server feilet:", error));
