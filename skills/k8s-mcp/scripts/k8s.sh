#!/usr/bin/env bash
set -euo pipefail

# Run MCP server from this script's directory (portable; no hardcoded paths)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_JS="${SCRIPT_DIR}/k8s-mcp.js"

if ! command -v node >/dev/null 2>&1; then
  echo "ERROR: node is not available in PATH." >&2
  exit 127
fi

exec node "${SERVER_JS}"
