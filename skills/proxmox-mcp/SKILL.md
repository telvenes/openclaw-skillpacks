name: proxmox-mcp
description: Proxmox VE MCP (nodes, vms, status) via proxmoxer + FastMCP.
tools:
  - type: mcp
    command: sh
    args:
      - "-lc"
      - "chmod +x skills/proxmox-mcp/scripts/proxmox.sh && skills/proxmox-mcp/scripts/proxmox.sh"
instructions: |
  Use proxmox-mcp for Proxmox queries.
  Prefer read-only actions unless explicitly asked (start/stop/reboot not provided in this minimal server).
