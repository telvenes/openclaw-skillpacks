#!/bin/sh
set -eu

SERVER_CMD='npx -y kubernetes-mcp-server@latest'
MCP='npx -y mcporter'

case "${1:-}" in
  events)
    ns="${2:-openclaw}"
    exec $MCP call --stdio "$SERVER_CMD" events_list "namespace=$ns"
    ;;
  config)
    exec $MCP call --stdio "$SERVER_CMD" configuration_view minified=true
    ;;
  helm-list)
    exec $MCP call --stdio "$SERVER_CMD" helm_list all_namespaces=true
    ;;
  *)
    echo "Usage: k8s.sh {events [namespace]|config|helm-list}" >&2
    exit 2
    ;;
esac
