name: proxmox-mcp
description: Advanced Proxmox VE and Ceph management tools.
tools:
  - type: mcp
    command: sh
    args:
      - "-c"
      - "pip install -r skills/proxmox-mcp/requirements.txt && PYTHONPATH=skills/proxmox-mcp/src python3 -m proxmox_mcp.server"
instructions: |
  CRITICAL: DO NOT attempt to use 'curl', 'pip', or write your own Python scripts to access Proxmox. 
  
  You MUST use the provided MCP tools (e.g., get_vms, get_nodes, get_cluster_status). 
  All credentials and URLs are already handled by the server environment.
