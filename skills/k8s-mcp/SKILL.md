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
  Use this MCP server for Kubernetes troubleshooting in this OpenClaw instance.

  Available tools:
  - k8s_health: Cluster reachability + version
  - k8s_events: Recent events (sorted newest first)
  - k8s_get: Read-only resource fetch (allowlisted resources only)
  - k8s_describe: Focused “describe” (object + related events)
  - k8s_logs: Pod logs (tail/since/container/previous)

  Rules / guardrails:
  - Prefer k8s_events early when debugging restarts/probes/scheduling.
  - This skill is read-only by design.
  - Secrets are intentionally blocked (no fetching Secret objects).

metadata:
  author: telvenes
  version: "0.2.0"
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
