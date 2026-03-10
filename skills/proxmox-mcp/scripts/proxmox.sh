#!/bin/sh
set -eu

WS="${OPENCLAW_WORKSPACE:-/home/openclaw/.openclaw/workspace}"
SKDIR="$WS/skills/proxmox-mcp"
CFG="/home/openclaw/.openclaw/openclaw.json"

cd "$WS"

# Install deps (quiet-ish, safe to rerun)
python3 -m pip install -q --no-cache-dir -r "$SKDIR/requirements.txt"

# Export env from OpenClaw config if present
if [ -f "$CFG" ]; then
  python3 - <<'PY'
import json, os, sys
cfg_path="/home/openclaw/.openclaw/openclaw.json"
cfg=json.load(open(cfg_path))
env = (((cfg.get("skills") or {}).get("entries") or {}).get("proxmox-mcp") or {}).get("env") or {}
for k,v in env.items():
    # don't overwrite real env if user/operator already set it
    os.environ.setdefault(k, str(v))
# If PROXMOX_TOKEN_VALUE is templated, substitute from PROXMOX_TOKEN_SECRET if present
tv=os.environ.get("PROXMOX_TOKEN_VALUE","")
if tv.startswith("${") and tv.endswith("}") and "PROXMOX_TOKEN_SECRET" in os.environ:
    os.environ["PROXMOX_TOKEN_VALUE"]=os.environ["PROXMOX_TOKEN_SECRET"]
# Print exports for parent shell
for k in sorted([k for k in os.environ.keys() if k.startswith("PROXMOX_")]):
    val=os.environ[k].replace('"','\\"')
    print(f'export {k}="{val}"')
PY
fi | sh -eu

# Defaults
: "${PROXMOX_VERIFY_SSL:=false}"

export PYTHONPATH="$SKDIR/src:${PYTHONPATH:-}"
exec python3 -m proxmox_mcp.server
