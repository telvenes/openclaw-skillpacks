#!/bin/sh
set -eu

WORKDIR="/home/openclaw/.openclaw/workspace"
SKILL_DIR="$WORKDIR/skills/proxmox-mcp"
VENV="$SKILL_DIR/.venv"
REQ="$SKILL_DIR/requirements.txt"
CFG="/home/openclaw/.openclaw/openclaw.json"

cd "$WORKDIR"

# ---- venv (cached on PVC) ----
if [ ! -x "$VENV/bin/python3" ]; then
  python3 -m venv "$VENV"
  "$VENV/bin/python3" -m pip install -q --upgrade pip setuptools wheel || true
fi

# ---- install deps only when requirements changes ----
REQ_SHA="$("$VENV/bin/python3" - <<'PY'
import hashlib, pathlib
p = pathlib.Path("/home/openclaw/.openclaw/workspace/skills/proxmox-mcp/requirements.txt")
print(hashlib.sha256(p.read_bytes()).hexdigest())
PY
)"
MARKER="$VENV/.requirements.sha256"
if [ ! -f "$MARKER" ] || [ "$(cat "$MARKER")" != "$REQ_SHA" ]; then
  "$VENV/bin/python3" -m pip install -q -r "$REQ"
  echo "$REQ_SHA" > "$MARKER"
fi

# ---- export skill env from openclaw.json if missing ----
if [ -f "$CFG" ]; then
  # Only fill missing vars; supports ${VAR} substitution from current env (secrets)
  eval "$("$VENV/bin/python3" - <<'PY'
import json, os, re

cfg = json.load(open("/home/openclaw/.openclaw/openclaw.json"))
env = cfg.get("skills",{}).get("entries",{}).get("proxmox-mcp",{}).get("env",{}) or {}

def expand(s: str) -> str:
    def repl(m):
        k = m.group(1)
        return os.environ.get(k, m.group(0))
    return re.sub(r"\$\{([^}]+)\}", repl, str(s))

out = []
for k, v in env.items():
    if os.environ.get(k):
        continue
    out.append(f"export {k}={json.dumps(expand(v))}")
print("\n".join(out))
PY
)"
fi

# Defaults
: "${PROXMOX_VERIFY_SSL:=false}"

# Validate required vars
for key in PROXMOX_HOST PROXMOX_USER PROXMOX_TOKEN_NAME PROXMOX_TOKEN_VALUE; do
  val="$(eval "printf '%s' \"\${$key:-}\"")"
  if [ -z "$val" ] || echo "$val" | grep -q '^\${.*}$'; then
    echo "ERROR: $key is missing (or still a placeholder). Check OpenClaw config/secret." >&2
    exit 1
  fi
done

# Run MCP server
PYTHONPATH="skills/proxmox-mcp/src" exec "$VENV/bin/python3" -m proxmox_mcp.server
