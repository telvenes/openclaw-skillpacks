#!/usr/bin/env node
/**
 * Minimal MCP (stdio) server with NO external dependencies.
 * Implements:
 * - initialize
 * - tools/list
 * - tools/call
 *
 * Kubernetes access:
 * - Uses in-cluster ServiceAccount token + CA
 * - Talks directly to K8s API (no kubectl required)
 * - Read-only allowlist + blocks Secrets
 */

import fs from "fs";
import https from "https";
import readline from "readline";
import { URLSearchParams } from "url";

const SA_DIR = "/var/run/secrets/kubernetes.io/serviceaccount";

function loadInClusterConfig() {
  if (!fs.existsSync(SA_DIR)) {
    throw new Error(
      `Not running in-cluster (missing ${SA_DIR}). This skill requires in-cluster ServiceAccount access.`
    );
  }

  const tokenPath = `${SA_DIR}/token`;
  const caPath = `${SA_DIR}/ca.crt`;

  const token = fs.readFileSync(tokenPath, "utf8").trim();
  const ca = fs.readFileSync(caPath);

  const host = process.env.KUBERNETES_SERVICE_HOST;
  const port = process.env.KUBERNETES_SERVICE_PORT;

  if (!host || !port) {
    throw new Error(
      "Missing KUBERNETES_SERVICE_HOST / KUBERNETES_SERVICE_PORT env vars."
    );
  }

  return {
    token,
    ca,
    baseUrl: `https://${host}:${port}`,
  };
}

function safeJsonParse(s) {
  try {
    return { ok: true, value: JSON.parse(s) };
  } catch {
    return { ok: false, value: null };
  }
}

function formatError(e) {
  return e instanceof Error ? e.message : String(e);
}

function jsonText(obj) {
  return JSON.stringify(obj, null, 2);
}

function pickTimestamp(evt) {
  // Events can have different timestamp fields depending on version/producer
  return (
    evt?.lastTimestamp ||
    evt?.eventTime ||
    evt?.firstTimestamp ||
    evt?.metadata?.creationTimestamp ||
    ""
  );
}

function compareEventsNewestFirst(a, b) {
  const ta = pickTimestamp(a);
  const tb = pickTimestamp(b);
  // ISO strings sort OK lexicographically if present
  if (ta > tb) return -1;
  if (ta < tb) return 1;
  return 0;
}

function makeK8sClient() {
  const cfg = loadInClusterConfig();

  const agent = new https.Agent({
    ca: cfg.ca,
    keepAlive: true,
  });

  async function requestJson(path, query = {}) {
    const qs = new URLSearchParams(query).toString();
    const url = `${cfg.baseUrl}${path}${qs ? `?${qs}` : ""}`;

    return new Promise((resolve, reject) => {
      const req = https.request(
        url,
        {
          method: "GET",
          agent,
          headers: {
            Authorization: `Bearer ${cfg.token}`,
            Accept: "application/json",
          },
        },
        (res) => {
          let data = "";
          res.setEncoding("utf8");
          res.on("data", (chunk) => (data += chunk));
          res.on("end", () => {
            const status = res.statusCode ?? 0;
            const parsed = safeJsonParse(data);

            if (status >= 200 && status < 300) {
              resolve({
                ok: true,
                status,
                body: parsed.ok ? parsed.value : data,
                raw: data,
              });
              return;
            }

            const msg =
              parsed.ok && parsed.value?.message
                ? parsed.value.message
                : data || `HTTP ${status}`;

            resolve({
              ok: false,
              status,
              body: parsed.ok ? parsed.value : data,
              raw: data,
              error: msg,
            });
          });
        }
      );

      req.on("error", (err) => reject(err));
      req.end();
    });
  }

  return { requestJson };
}

// Allowlist mapping for "k8s_get" and "k8s_describe"
const RESOURCE_MAP = {
  // core
  namespaces: { scope: "cluster", path: "/api/v1/namespaces" },
  nodes: { scope: "cluster", path: "/api/v1/nodes" },
  pods: { scope: "namespaced", path: "/api/v1/namespaces/{ns}/pods" },
  services: { scope: "namespaced", path: "/api/v1/namespaces/{ns}/services" },
  svc: { alias: "services" },
  endpoints: { scope: "namespaced", path: "/api/v1/namespaces/{ns}/endpoints" },
  configmaps: { scope: "namespaced", path: "/api/v1/namespaces/{ns}/configmaps" },
  events: { scope: "namespaced", path: "/api/v1/namespaces/{ns}/events" },

  // apps
  deployments: {
    scope: "namespaced",
    path: "/apis/apps/v1/namespaces/{ns}/deployments",
  },
  replicasets: {
    scope: "namespaced",
    path: "/apis/apps/v1/namespaces/{ns}/replicasets",
  },
  statefulsets: {
    scope: "namespaced",
    path: "/apis/apps/v1/namespaces/{ns}/statefulsets",
  },
  daemonsets: {
    scope: "namespaced",
    path: "/apis/apps/v1/namespaces/{ns}/daemonsets",
  },

  // batch
  jobs: { scope: "namespaced", path: "/apis/batch/v1/namespaces/{ns}/jobs" },
  cronjobs: {
    scope: "namespaced",
    path: "/apis/batch/v1/namespaces/{ns}/cronjobs",
  },

  // networking
  ingresses: {
    scope: "namespaced",
    path: "/apis/networking.k8s.io/v1/namespaces/{ns}/ingresses",
  },

  // NOTE: secrets intentionally NOT present (blocked)
};

function normalizeResource(resource) {
  const r = (resource || "").toLowerCase().trim();
  const entry = RESOURCE_MAP[r];
  if (!entry) return null;
  if (entry.alias) return RESOURCE_MAP[entry.alias] ? entry.alias : null;
  return r;
}

function resolvePath(resourceKey, namespace) {
  const entry = RESOURCE_MAP[resourceKey];
  if (!entry || !entry.path) throw new Error("Unknown resource mapping.");

  if (entry.scope === "cluster") return entry.path;

  const ns = namespace?.trim() || "default";
  return entry.path.replace("{ns}", encodeURIComponent(ns));
}

async function tool_k8s_health(k8s) {
  const version = await k8s.requestJson("/version");
  const readyz = await k8s.requestJson("/readyz", { verbose: "1" });

  const out = {
    version: version.ok ? version.body : { error: version.error, status: version.status },
    readyz: readyz.ok ? readyz.raw : `ERROR (${readyz.status}): ${readyz.error}`,
  };

  return { isError: !(version.ok && readyz.ok), text: jsonText(out) };
}

async function tool_k8s_events(k8s, { namespace = "default", limit = 50, type = "all" } = {}) {
  const ns = namespace === "-A" || namespace === "--all-namespaces" ? null : namespace;

  // K8s has no single "all namespaces events" stable endpoint without listing namespaces,
  // so for -A we just return a helpful message.
  if (!ns) {
    return {
      isError: false,
      text:
        "All-namespaces events (-A) is not supported in this minimal read-only skill.\n" +
        "Run per-namespace: namespace: \"<ns>\".\n" +
        "Tip: start with the app namespace first.",
    };
  }

  const res = await k8s.requestJson(`/api/v1/namespaces/${encodeURIComponent(ns)}/events`);
  if (!res.ok) return { isError: true, text: `ERROR (${res.status}): ${res.error}` };

  const items = Array.isArray(res.body?.items) ? res.body.items : [];
  const filtered = items.filter((e) => {
    const t = (e?.type || "").toLowerCase();
    if (type === "warnings") return t === "warning";
    if (type === "normal") return t === "normal";
    return true;
  });

  filtered.sort(compareEventsNewestFirst);
  const sliced = filtered.slice(0, Math.max(1, Math.min(500, Number(limit) || 50)));

  const simplified = sliced.map((e) => ({
    ts: pickTimestamp(e),
    type: e.type,
    reason: e.reason,
    message: e.message,
    involvedObject: {
      kind: e?.involvedObject?.kind,
      name: e?.involvedObject?.name,
      namespace: e?.involvedObject?.namespace,
    },
    source: e?.source?.component || e?.reportingComponent,
  }));

  return { isError: false, text: jsonText({ namespace: ns, count: simplified.length, events: simplified }) };
}

async function tool_k8s_get(
  k8s,
  {
    resource,
    namespace,
    name,
    labelSelector,
    fieldSelector,
    limit = 200,
  } = {}
) {
  if (!resource) return { isError: true, text: "Missing required field: resource" };

  const key = normalizeResource(resource);
  if (!key) {
    return {
      isError: true,
      text:
        `Resource "${resource}" not allowed/known.\n` +
        `Allowed: ${Object.keys(RESOURCE_MAP).filter((k) => !RESOURCE_MAP[k].alias).join(", ")}\n` +
        `Note: secrets are intentionally blocked.`,
    };
  }
  if (key === "secrets") {
    return { isError: true, text: "Secrets are blocked by policy." };
  }

  const pathBase = resolvePath(key, namespace);
  const path = name ? `${pathBase}/${encodeURIComponent(name)}` : pathBase;

  const query = {};
  if (!name) {
    if (labelSelector) query.labelSelector = String(labelSelector);
    if (fieldSelector) query.fieldSelector = String(fieldSelector);
    query.limit = String(Math.max(1, Math.min(500, Number(limit) || 200)));
  }

  const res = await k8s.requestJson(path, query);
  if (!res.ok) return { isError: true, text: `ERROR (${res.status}): ${res.error}` };

  return { isError: false, text: jsonText(res.body) };
}

async function tool_k8s_describe(k8s, { resource, name, namespace } = {}) {
  if (!resource || !name) {
    return { isError: true, text: "Missing required fields: resource, name" };
  }

  const key = normalizeResource(resource);
  if (!key) return { isError: true, text: `Resource "${resource}" not allowed/known.` };
  if (key === "secrets") return { isError: true, text: "Secrets are blocked by policy." };

  const entry = RESOURCE_MAP[key];
  const ns =
    entry.scope === "cluster"
      ? null
      : (namespace?.trim() || "default");

  const objRes = await tool_k8s_get(k8s, { resource: key, namespace: ns || undefined, name });
  if (objRes.isError) return objRes;

  // Related events for this object (best-effort)
  let eventsText = "Related events: (not available)";
  if (ns) {
    const fieldSelector = [
      `involvedObject.name=${name}`,
      // not all emit kind consistently, so keep it simple
    ].join(",");

    const evRes = await tool_k8s_events(k8s, { namespace: ns, limit: 50, type: "all" });
    if (!evRes.isError) {
      // Filter the already simplified list if possible
      const parsed = safeJsonParse(evRes.text);
      if (parsed.ok && parsed.value?.events) {
        const filtered = parsed.value.events.filter(
          (e) =>
            e?.involvedObject?.name === name &&
            (!e?.involvedObject?.kind || e.involvedObject.kind.toLowerCase().includes(resource.toLowerCase().slice(0, 6)))
        );
        eventsText = jsonText({ namespace: ns, object: name, events: filtered });
      } else {
        eventsText = evRes.text;
      }
    }
  }

  const out =
    `Object:\n${objRes.text}\n\n` +
    `---\n${eventsText}\n`;

  return { isError: false, text: out };
}

async function tool_k8s_logs(
  k8s,
  { pod, namespace = "default", container, tailLines = 200, sinceSeconds, previous = false } = {}
) {
  if (!pod) return { isError: true, text: "Missing required field: pod" };

  const ns = namespace?.trim() || "default";
  const path = `/api/v1/namespaces/${encodeURIComponent(ns)}/pods/${encodeURIComponent(pod)}/log`;

  const query = {};
  if (container) query.container = String(container);
  query.tailLines = String(Math.max(1, Math.min(2000, Number(tailLines) || 200)));
  if (sinceSeconds) query.sinceSeconds = String(Math.max(1, Number(sinceSeconds)));
  if (previous) query.previous = "true";

  const res = await k8s.requestJson(path, query);
  if (!res.ok) return { isError: true, text: `ERROR (${res.status}): ${res.error}` };

  // logs endpoint is plain text; we used requestJson but it returns body/raw
  return { isError: false, text: typeof res.body === "string" ? res.body : res.raw };
}

// ---- MCP (JSON-RPC over stdio, line-delimited) ----

const TOOLS = [
  {
    name: "k8s_health",
    description: "Cluster reachability + Kubernetes version + readyz verbose output.",
    inputSchema: { type: "object", properties: {} },
  },
  {
    name: "k8s_events",
    description: "Recent events in a namespace (sorted newest first).",
    inputSchema: {
      type: "object",
      properties: {
        namespace: { type: "string", description: "Namespace (default: default). '-A' not supported here." },
        limit: { type: "number", description: "Max events (default: 50, max: 500)." },
        type: { type: "string", description: "all | warnings | normal (default: all)." },
      },
    },
  },
  {
    name: "k8s_get",
    description: "Read-only resource fetch (allowlisted resources only; secrets blocked).",
    inputSchema: {
      type: "object",
      properties: {
        resource: { type: "string", description: "e.g. pods, deployments, services, nodes, namespaces, ingresses" },
        namespace: { type: "string", description: "Namespace (default: default for namespaced resources)" },
        name: { type: "string", description: "Optional: get a single object by name" },
        labelSelector: { type: "string", description: "Optional: label selector (list only)" },
        fieldSelector: { type: "string", description: "Optional: field selector (list only)" },
        limit: { type: "number", description: "List limit (default: 200, max: 500)" },
      },
      required: ["resource"],
    },
  },
  {
    name: "k8s_describe",
    description: "Focused describe: object JSON plus related events (best-effort).",
    inputSchema: {
      type: "object",
      properties: {
        resource: { type: "string", description: "Resource type (allowlisted). e.g. pod(s), deployment(s), service(s)" },
        name: { type: "string", description: "Object name" },
        namespace: { type: "string", description: "Namespace (required for namespaced resources; default: default)" },
      },
      required: ["resource", "name"],
    },
  },
  {
    name: "k8s_logs",
    description: "Pod logs (tail/since/container/previous).",
    inputSchema: {
      type: "object",
      properties: {
        pod: { type: "string", description: "Pod name" },
        namespace: { type: "string", description: "Namespace (default: default)" },
        container: { type: "string", description: "Optional container name" },
        tailLines: { type: "number", description: "Tail lines (default: 200, max: 2000)" },
        sinceSeconds: { type: "number", description: "Optional: only return logs newer than X seconds" },
        previous: { type: "boolean", description: "Optional: previous container logs (default: false)" },
      },
      required: ["pod"],
    },
  },
];

function makeResponse(id, result) {
  return { jsonrpc: "2.0", id, result };
}

function makeError(id, message, code = -32000) {
  return { jsonrpc: "2.0", id, error: { code, message } };
}

async function handleCallTool(k8s, toolName, args) {
  switch (toolName) {
    case "k8s_health": {
      const r = await tool_k8s_health(k8s);
      return { content: [{ type: "text", text: r.text }], isError: r.isError };
    }
    case "k8s_events": {
      const r = await tool_k8s_events(k8s, args);
      return { content: [{ type: "text", text: r.text }], isError: r.isError };
    }
    case "k8s_get": {
      const r = await tool_k8s_get(k8s, args);
      return { content: [{ type: "text", text: r.text }], isError: r.isError };
    }
    case "k8s_describe": {
      const r = await tool_k8s_describe(k8s, args);
      return { content: [{ type: "text", text: r.text }], isError: r.isError };
    }
    case "k8s_logs": {
      const r = await tool_k8s_logs(k8s, args);
      return { content: [{ type: "text", text: r.text }], isError: r.isError };
    }
    default:
      return { content: [{ type: "text", text: `Unknown tool: ${toolName}` }], isError: true };
  }
}

async function main() {
  let k8s;
  try {
    k8s = makeK8sClient();
  } catch (e) {
    // We still start MCP so the client sees a meaningful error on tool calls
    k8s = null;
    console.error(`k8s-mcp: WARNING: ${formatError(e)}`);
  }

  const rl = readline.createInterface({ input: process.stdin, crlfDelay: Infinity });

  rl.on("line", async (line) => {
    const trimmed = line.trim();
    if (!trimmed) return;

    const msg = safeJsonParse(trimmed);
    if (!msg.ok || !msg.value) {
      // ignore garbage
      return;
    }

    const req = msg.value;
    const id = req.id;

    try {
      if (req.method === "initialize") {
        const result = {
          protocolVersion: req.params?.protocolVersion || "2024-11-05",
          serverInfo: { name: "k8s-mcp", version: "0.2.0" },
          capabilities: { tools: {} },
        };
        process.stdout.write(JSON.stringify(makeResponse(id, result)) + "\n");
        return;
      }

      if (req.method === "tools/list") {
        process.stdout.write(JSON.stringify(makeResponse(id, { tools: TOOLS })) + "\n");
        return;
      }

      if (req.method === "tools/call") {
        const toolName = req.params?.name;
        const args = req.params?.arguments || {};

        if (!k8s) {
          process.stdout.write(
            JSON.stringify(
              makeResponse(id, {
                content: [{ type: "text", text: "Kubernetes client not initialized (not running in-cluster or missing env/token/CA)." }],
                isError: true,
              })
            ) + "\n"
          );
          return;
        }

        const result = await handleCallTool(k8s, toolName, args);
        process.stdout.write(JSON.stringify(makeResponse(id, result)) + "\n");
        return;
      }

      // Unknown method
      if (typeof id !== "undefined") {
        process.stdout.write(JSON.stringify(makeError(id, `Unknown method: ${req.method}`)) + "\n");
      }
    } catch (e) {
      if (typeof id !== "undefined") {
        process.stdout.write(JSON.stringify(makeError(id, formatError(e))) + "\n");
      }
    }
  });

  // stderr log so it doesn't break stdio protocol
  console.error("k8s-mcp: started (stdio)");
}

main().catch((e) => {
  console.error("k8s-mcp: fatal:", formatError(e));
  process.exit(1);
});
