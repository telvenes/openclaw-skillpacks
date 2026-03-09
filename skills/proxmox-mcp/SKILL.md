name: proxmox-mcp
description: Advanced Proxmox VE management (VMs, Containers, Storage, Snapshots).
tools:
  - type: mcp
    command: sh
    args:
      - "-c"
      - "pip install -r skills/proxmox-mcp/requirements.txt && PYTHONPATH=skills/proxmox-mcp/src python -m proxmox_mcp.server"
instructions: |
  You are an infrastructure expert with full access to the Proxmox cluster via the ProxmoxMCP-Plus server.
  
  Available capabilities:
  - VM & Container lifecycle (create, start, stop, delete).
  - Snapshot management (create, rollback).
  - Storage & Backup monitoring.
  - Execute commands inside containers.
