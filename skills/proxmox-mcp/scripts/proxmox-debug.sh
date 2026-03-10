#!/usr/bin/env sh
set -eu

cd /home/openclaw/.openclaw/workspace/skills/proxmox-mcp 2>/dev/null || true

python3 - << "PY"
import os, json
from proxmoxer import ProxmoxAPI

cfg_path="/home/openclaw/.openclaw/openclaw.json"
cfg=json.load(open(cfg_path, "r", encoding="utf-8"))

env = cfg["skills"]["entries"]["proxmox-mcp"].get("env", {})
for k,v in env.items():
    os.environ[k]=str(v)

# resolve ${VAR} patterns
for k,v in list(os.environ.items()):
    if v.startswith("${") and v.endswith("}"):
        key=v[2:-1]
        if os.environ.get(key):
            os.environ[k]=os.environ[key]

need=["PROXMOX_HOST","PROXMOX_USER","PROXMOX_TOKEN_NAME","PROXMOX_TOKEN_VALUE"]
missing=[k for k in need if not os.environ.get(k)]
if missing:
    raise SystemExit("Missing: "+", ".join(missing))

print("== effective proxmox env ==")
print("PROXMOX_HOST=", os.environ["PROXMOX_HOST"])
print("PROXMOX_USER=", os.environ["PROXMOX_USER"])
print("PROXMOX_TOKEN_NAME=", os.environ["PROXMOX_TOKEN_NAME"])
print("PROXMOX_TOKEN_VALUE=<redacted>")
print("PROXMOX_VERIFY_SSL=", os.environ.get("PROXMOX_VERIFY_SSL","true"))

verify_ssl = os.environ.get("PROXMOX_VERIFY_SSL","true").lower() in ("1","true","yes","on")

p=ProxmoxAPI(
    os.environ["PROXMOX_HOST"],
    user=os.environ["PROXMOX_USER"],
    token_name=os.environ["PROXMOX_TOKEN_NAME"],
    token_value=os.environ["PROXMOX_TOKEN_VALUE"],
    verify_ssl=verify_ssl,
)

nodes=p.nodes.get()
print("OK nodes:", [n.get("node") for n in nodes])
PY
