# k8s-mcp (read-only)

A minimal, production-safe Kubernetes diagnostics wrapper for OpenClaw.

## Why this exists
- Works without `kubectl`
- Uses in-cluster ServiceAccount token + CA
- Read-only commands only (safer for LLM-driven ops)

## Commands
- `events [namespace] [limit]`
- `warnings [namespace] [limit]`
- `helm-list [namespace]`
- `config`
- `version`

## Examples
```sh
sh skills/k8s-mcp/scripts/k8s.sh events openclaw
sh skills/k8s-mcp/scripts/k8s.sh warnings openclaw 200
sh skills/k8s-mcp/scripts/k8s.sh version
sh skills/k8s-mcp/scripts/k8s.sh helm-list cvat
