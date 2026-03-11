# k8s-mcp (read-only)

Minimal, production-safe Kubernetes diagnostics MCP server for OpenClaw.

## What this is
- Works without `kubectl`
- Uses in-cluster ServiceAccount token + CA
- Read-only by design
- Secrets are blocked by policy

## Tools (these are the ONLY tool names)
- `k8s_health`
- `k8s_events`
- `k8s_get`
- `k8s_describe`
- `k8s_logs`

## Manual MCP testing (CLI)
These are low-level protocol tests (JSON-RPC over stdio). Run inside the agent container.

### List tools
```bash
( \
  printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{}}}'; \
  printf '%s\n' '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'; \
) | bash scripts/k8s.sh
