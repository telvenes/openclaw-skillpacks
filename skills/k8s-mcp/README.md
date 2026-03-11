# k8s-mcp (read-only)

Minimal, production-safe Kubernetes diagnostics MCP server for OpenClaw.

## What this is
- Works without `kubectl`
- Uses in-cluster ServiceAccount token + CA
- Read-only by design
- Blocks Secrets by policy

## Tools (these are the ONLY tool names)
- `k8s_health`
- `k8s_events`
- `k8s_get`
- `k8s_describe`
- `k8s_logs`

## Manual MCP testing (CLI)

These are low-level JSON-RPC over stdio tests. Run inside the agent container.

### List tools
```bash
(
  printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{}}}';
  printf '%s\n' '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}';
) | bash scripts/k8s.sh
```

### Health
```bash
(
  printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{}}}';
  printf '%s\n' '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"k8s_health","arguments":{}}}';
) | bash scripts/k8s.sh
```
### Events
```bash
(
  printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{}}}';
  printf '%s\n' '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"k8s_events","arguments":{"namespace":"openclaw","limit":30,"type":"warnings"}}}';
) | bash scripts/k8s.sh
```
### Get pods
```bash
(
  printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{}}}';
  printf '%s\n' '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"k8s_get","arguments":{"resource":"pods","namespace":"openclaw","limit":50}}}';
) | bash scripts/k8s.sh
```

### Logs
```bash
(
  printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{}}}';
  printf '%s\n' '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"k8s_logs","arguments":{"namespace":"openclaw","pod":"thorsland-agent-0","tailLines":200}}}';
) | bash scripts/k8s.sh
```
