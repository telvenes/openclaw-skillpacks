name: proxmox-mcp
description: Proxmox VE MCP (read-only): nodes, VMs, status
tools:
  - type: mcp
    command: sh
    args:
      - "-lc"
      - "cd /home/openclaw/.openclaw/workspace && sh skills/proxmox-mcp/scripts/proxmox.sh"
instructions: |
  You are an infrastructure assistant with read-only access to Proxmox VE via MCP.
  Prefer safe, non-destructive operations.

  Available tools:
  - list_nodes()
  - list_vms(type='all')
  - get_vm_status(node, vmid, type='vm'|'container')
