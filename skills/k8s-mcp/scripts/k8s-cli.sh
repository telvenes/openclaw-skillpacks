
---

## 3) (Valgfritt, men anbefalt) `skills/k8s-mcp/scripts/k8s-cli.sh`
Dette gjør at du kan skrive “script-kommandoer” (som du savna), men fortsatt bruke MCP under panseret.

**Lag ny fil** `skills/k8s-mcp/scripts/k8s-cli.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_SH="${SCRIPT_DIR}/k8s.sh"

usage() {
  cat <<'EOF'
Usage:
  k8s-cli.sh health
  k8s-cli.sh events <namespace> [warnings|normal|all] [limit]
  k8s-cli.sh get <resource> <namespace> [name] [limit]
  k8s-cli.sh logs <namespace> <pod> [container] [tailLines] [sinceSeconds] [previous:true|false]

Examples:
  ./k8s-cli.sh health
  ./k8s-cli.sh events openclaw warnings 30
  ./k8s-cli.sh get pods openclaw "" 50
  ./k8s-cli.sh get pods openclaw thorsland-agent-0
  ./k8s-cli.sh logs openclaw thorsland-agent-0 "" 200 "" false
EOF
}

mcp_call() {
  local tool="$1"
  local args_json="$2"

  ( \
    printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{}}}'; \
    printf '%s\n' "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"${tool}\",\"arguments\":${args_json}}}"; \
  ) | bash "${SERVER_SH}"
}

cmd="${1:-}"
case "${cmd}" in
  health)
    mcp_call "k8s_health" "{}"
    ;;

  events)
    ns="${2:-default}"
    type="${3:-warnings}"
    limit="${4:-50}"
    mcp_call "k8s_events" "{\"namespace\":\"${ns}\",\"type\":\"${type}\",\"limit\":${limit}}"
    ;;

  get)
    resource="${2:-}"
    ns="${3:-default}"
    name="${4:-}"
    limit="${5:-200}"
    if [[ -z "${resource}" ]]; then usage; exit 2; fi
    if [[ -n "${name}" && "${name}" != "\"\"" ]]; then
      mcp_call "k8s_get" "{\"resource\":\"${resource}\",\"namespace\":\"${ns}\",\"name\":\"${name}\"}"
    else
      mcp_call "k8s_get" "{\"resource\":\"${resource}\",\"namespace\":\"${ns}\",\"limit\":${limit}}"
    fi
    ;;

  logs)
    ns="${2:-default}"
    pod="${3:-}"
    container="${4:-}"
    tail="${5:-200}"
    since="${6:-}"
    prev="${7:-false}"
    if [[ -z "${pod}" ]]; then usage; exit 2; fi

    args="{\"namespace\":\"${ns}\",\"pod\":\"${pod}\",\"tailLines\":${tail},\"previous\":${prev}}"
    if [[ -n "${container}" && "${container}" != "\"\"" ]]; then
      args="$(echo "${args}" | sed "s/}$/,\n\"container\":\"${container}\"}/")"
    fi
    if [[ -n "${since}" && "${since}" != "\"\"" ]]; then
      args="$(echo "${args}" | sed "s/}$/,\n\"sinceSeconds\":${since}}/")"
    fi
    mcp_call "k8s_logs" "${args}"
    ;;

  *)
    usage
    exit 2
    ;;
esac
