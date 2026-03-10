#!/bin/sh
set -eu

WS="${OPENCLAW_WORKSPACE:-/home/openclaw/.openclaw/workspace}"
SKDIR="$WS/skills/proxmox-mcp"
CFG="/home/openclaw/.openclaw/openclaw.json"

load_env_from_openclaw_json() {
  if [ "${PROXMOX_HOST:-}" != "" ]; then
    return 0
  fi

  if [ ! -f "$CFG" ]; then
    echo "ERROR: Missing $CFG and PROXMOX_HOST not set" >&2
    return 1
  fi

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
  if [ "${PROXMOX_TOKEN_VALUE:-}" = "\${PROXMOX_TOKEN_SECRET}" ] || \
     [ "${PROXMOX_TOKEN_VALUE:-}" = "${PROXMOX_TOKEN_SECRET:-__MISSING__}" ]; then
    if [ "${PROXMOX_TOKEN_SECRET:-}" != "" ]; then
      export PROXMOX_TOKEN_VALUE="${PROXMOX_TOKEN_SECRET}"
    fi
  fi
}

install_deps_if_needed() {
  python3 -c "import proxmoxer" >/dev/null 2>&1 && return 0
  echo "Installing Python deps from $SKDIR/requirements.txt ..."
  python3 -m pip install -q --no-cache-dir -r "$SKDIR/requirements.txt"
}

main() {
  cd "$WS"
  eval "$(load_env_from_openclaw_json)"
  normalize_token_value
  install_deps_if_needed

  echo "== files =="
  find "$SKDIR" -maxdepth 4 -type f | sed -n '1,120p'
  echo

  echo "== env (redacted) =="
  env | grep -E '^PROXMOX_' | sed -E 's/(PROXMOX_TOKEN_VALUE=).+/\1<redacted>/' | sed -E 's/(PROXMOX_TOKEN_SECRET=).+/\1<redacted>/'
  echo

  echo "== python probe =="
  python3 - <<'PY'
import os
from proxmoxer import ProxmoxAPI

def b(v: str) -> bool:
    return str(v).lower() not in ("0","false","no","off","")

host=os.environ["PROXMOX_HOST"]
user=os.environ["PROXMOX_USER"]
token_name=os.environ["PROXMOX_TOKEN_NAME"]
token_value=os.environ["PROXMOX_TOKEN_VALUE"]
verify_ssl = b(os.environ.get("PROXMOX_VERIFY_SSL","false"))

p=ProxmoxAPI(host, user=user, token_name=token_name, token_value=token_value, verify_ssl=verify_ssl)

nodes = p.nodes.get()
node_names = [n.get("node") for n in nodes if n.get("node")]
print("OK nodes:", node_names)

running = []
for nn in node_names:
    # QEMU VMs
    for vm in p.nodes(nn).qemu.get():
        if vm.get("status") == "running":
            running.append((nn, "qemu", vm.get("vmid"), vm.get("name")))
    # LXC containers
    for ct in p.nodes(nn).lxc.get():
        if ct.get("status") == "running":
            running.append((nn, "lxc", ct.get("vmid"), ct.get("name")))

print("\n== RUNNING (qemu+lxc) ==")
for nn, typ, vmid, name in sorted(running, key=lambda x: (x[0], x[1], int(x[2] or 0))):
    print(f"{nn}: {typ} {vmid} {name}")
print(f"\nTotal running: {len(running)}")
PY
}

main "$@"
