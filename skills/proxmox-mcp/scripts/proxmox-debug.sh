#!/bin/sh
set -eu

WORKDIR="/home/openclaw/.openclaw/workspace"
SKILL_DIR="$WORKDIR/skills/proxmox-mcp"
VENV="$SKILL_DIR/.venv"

cd "$WORKDIR"

# Reuse venv if present (or create)
if [ ! -x "$VENV/bin/python3" ]; then
  python3 -m venv "$VENV"
  "$VENV/bin/python3" -m pip install -q --upgrade pip setuptools wheel || true
  "$VENV/bin/python3" -m pip install -q -r "$SKILL_DIR/requirements.txt"
fi

echo "== PROXMOX_* in process env (redacted) =="
env | grep -E '^PROXMOX_' | sed -E 's/(PROXMOX_TOKEN_VALUE=).+/\1<redacted>/'

echo
echo "== read env mapping from openclaw.json and probe nodes =="

"$VENV/bin/python3" - <<'PY'
import json, os, re
from proxmoxer import ProxmoxAPI

cfg = json.load(open("/home/openclaw/.openclaw/openclaw.json"))
env = cfg["skills"]["entries"]["proxmox-mcp"].get("env", {}) or {}

def expand(v):
    def repl(m):
        k=m.group(1)
        return os.environ.get(k, m.group(0))
    return re.sub(r"\$\{([^}]+)\}", repl, str(v))

for k,v in env.items():
    os.environ.setdefault(k, expand(v))

host=os.environ["PROXMOX_HOST"]
user=os.environ["PROXMOX_USER"]
token_name=os.environ["PROXMOX_TOKEN_NAME"]
token_value=os.environ["PROXMOX_TOKEN_VALUE"]
verify_ssl = os.environ.get("PROXMOX_VERIFY_SSL","false").lower() not in ("0","false","no","off","")

p = ProxmoxAPI(host, user=user, token_name=token_name, token_value=token_value, verify_ssl=verify_ssl)
nodes = p.nodes.get()
print("OK nodes:", [n.get("node") for n in nodes])
PY
