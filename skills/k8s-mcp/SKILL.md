---
name: k8s-mcp
description: |
  Read-only Kubernetes diagnostics via in-cluster ServiceAccount.
  Does NOT require kubectl. Designed for safe troubleshooting in LLM-driven ops.

tools:
  - type: mcp
    command: bash
    args: ["skills/k8s-mcp/scripts/k8s.sh"]

instructions: |
  Use this MCP server for Kubernetes troubleshooting.

  CRITICAL NAMING:
  - "k8s-mcp" is the SKILL name, NOT a tool.
  - The ONLY valid tool names are: k8s_health, k8s_events, k8s_get, k8s_describe, k8s_logs
  - NEVER call a tool named "k8s-mcp" (it does not exist).

  CRITICAL SAFETY:
  - DO NOT use exec/kubectl (kubectl is not installed). Always use the tools above.
  - This skill is read-only. Secrets are blocked.

  Quick examples (use these patterns exactly):
  - List pods in namespace dev:
    k8s_get {"resource":"pods","namespace":"dev","limit":200}
  - Show warnings in namespace dev:
    k8s_events {"namespace":"dev","type":"warnings","limit":50}
  - Fetch logs:
    k8s_logs {"namespace":"dev","pod":"<pod>","container":"<container>","tailLines":200}

  Tool guide:
  - k8s_health: Cluster reachability + version + readyz
  - k8s_events: Recent events (newest first)
  - k8s_get: Read-only resource fetch (allowlisted)
  - k8s_describe: Object JSON + related events (best-effort)
  - k8s_logs: Pod logs (tail/since/container/previous)

metadata:
  author: telvenes
  version: "0.2.1"
---

# k8s-mcp (read-only)

A minimal, production-safe Kubernetes diagnostics MCP server for OpenClaw.

## Notes
- Uses in-cluster ServiceAccount token + CA.
- No kubectl dependency.
- Blocks Secrets by default.

## Typical workflow
1) `k8s_health`
2) `k8s_events` (namespace)
3) `k8s_get` pods/deployments/services
4) `k8s_describe` for the failing resource
5) `k8s_logs` for the crashing pod
