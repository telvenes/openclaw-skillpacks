#!/bin/sh
set -eu

WS="${OPENCLAW_WORKSPACE:-/home/openclaw/.openclaw/workspace}"
SKDIR="$WS/skills/proxmox-mcp"

echo "== files =="
find "$SKDIR" -maxdepth 3 -type f | sort

echo
echo "== env (redacted) =="
env | grep '^PROXMOX_' | sed -E 's/(PROXMOX_TOKEN_VALUE=).+/\1<redacted>/'

echo
echo "== python probe =="
python3 - <<'PY'
import os, json
from proxmoxer import ProxmoxAPI

# Read env from openclaw.json if needed (same logic as wrapper)
cfg=json.load(open("/home/openclaw/.openclaw/openclaw.json"))
env = cfg["skills"]["entries"]["proxmox-mcp"].get("env", {})
for k,v in env.items():
    os.environ.setdefault(k, str(v))
tv=os.environ.get("PROXMOX_TOKEN_VALUE","")
if tv.startswith("${") and "PROXMOX_TOKEN_SECRET" in os.environ:
    os.environ["PROXMOX_TOKEN_VALUE"]=os.environ["PROXMOX_TOKEN_SECRET"]

host=os.environ["PROXMOX_HOST"]
user=os.environ["PROXMOX_USER"]
token_name=os.environ["PROXMOX_TOKEN_NAME"]
token_value=os.environ["PROXMOX_TOKEN_VALUE"]
verify_ssl = os.environ.get("PROXMOX_VERIFY_SSL","false").lower() not in ("0","false","no")

p=ProxmoxAPI(host, user=user, token_name=token_name, token_value=token_value, verify_ssl=verify_ssl)
nodes=p.nodes.get()
print("OK nodes:", [n.get("node") for n in nodes])
PY
