#!/bin/sh
set -eu

WS="${OPENCLAW_WORKSPACE:-/home/openclaw/.openclaw/workspace}"
SKDIR="$WS/skills/proxmox-mcp"
CFG="/home/openclaw/.openclaw/openclaw.json"

load_env_from_openclaw_json() {
  # Hvis PROXMOX_HOST allerede finnes, ikke gjør noe.
  if [ "${PROXMOX_HOST:-}" != "" ]; then
    return 0
  fi

  if [ ! -f "$CFG" ]; then
    echo "ERROR: Missing $CFG and PROXMOX_HOST not set" >&2
    return 1
  fi

  # Les skills.entries.proxmox-mcp.env og print som KEY=VALUE (shell-safe)
  python3 - <<'PY'
import json, shlex
cfg_path="/home/openclaw/.openclaw/openclaw.json"
cfg=json.load(open(cfg_path))
env = (((cfg.get("skills") or {}).get("entries") or {}).get("proxmox-mcp") or {}).get("env") or {}
for k,v in env.items():
    if v is None:
        continue
    print(f"export {k}={shlex.quote(str(v))}")
PY
}

normalize_token_value() {
  # Hvis PROXMOX_TOKEN_VALUE er templated som ${PROXMOX_TOKEN_SECRET}, bytt den ut.
  if [ "${PROXMOX_TOKEN_VALUE:-}" = "\${PROXMOX_TOKEN_SECRET}" ] || \
     [ "${PROXMOX_TOKEN_VALUE:-}" = "${PROXMOX_TOKEN_SECRET:-__MISSING__}" ]; then
    if [ "${PROXMOX_TOKEN_SECRET:-}" != "" ]; then
      export PROXMOX_TOKEN_VALUE="${PROXMOX_TOKEN_SECRET}"
    fi
  fi
}

install_deps_if_needed() {
  # Installer kun hvis imports feiler
  python3 -c "import proxmoxer" >/dev/null 2>&1 && return 0
  echo "Installing Python deps from $SKDIR/requirements.txt ..."
  python3 -m pip install -q --no-cache-dir -r "$SKDIR/requirements.txt"
}

main() {
  cd "$WS"

  # 1) Autoload env hvis ikke satt
  eval "$(load_env_from_openclaw_json)"

  # 2) Normaliser token
  normalize_token_value

  # 3) Sanity check (ikke print secret)
  if [ "${PROXMOX_HOST:-}" = "" ] || [ "${PROXMOX_USER:-}" = "" ] || \
     [ "${PROXMOX_TOKEN_NAME:-}" = "" ] || [ "${PROXMOX_TOKEN_VALUE:-}" = "" ]; then
    echo "ERROR: Missing required env. Need PROXMOX_HOST/USER/TOKEN_NAME/TOKEN_VALUE" >&2
    echo "Hint: put them in openclaw.json under skills.entries.proxmox-mcp.env" >&2
    exit 1
  fi

  # 4) deps
  install_deps_if_needed

  # 5) start MCP server (module path)
  export PYTHONPATH="$SKDIR/src:${PYTHONPATH:-}"
  exec python3 -m proxmox_mcp.server
}

main "$@"
