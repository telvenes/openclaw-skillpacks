name: proxmox-mcp
description: Advanced Proxmox VE management via Model Context Protocol.
tools:
  - type: mcp
    command: sh
    args:
      - "-c"
      - "PYTHONPATH=skills/proxmox-mcp/src python3 -m proxmox_mcp.server"
instructions: |
  CRITICAL: Authentication strictly uses API Token authentication. Do NOT attempt to use standard passwords or curl.

  Available Tools:
  - get_nodes: List cluster nodes and resource usage.
  - get_cluster_status: Check cluster quorum and health.
  - get_storage: List storage pools (Ceph, LVM, NFS).
  - get_node_status: Detailed metrics for a specific node.
  - get_vms / get_containers: List all instances and current status.
  - create_vm / create_container: Provision new resources.
  - start_vm / stop_vm / shutdown_vm / reset_vm: Power management operations.
  - execute_vm_command: Run commands via QEMU Guest Agent.

  Usage Rules:
  1. Tool Priority: Use these structured tools for ALL Proxmox queries. NEVER use raw curl, pip, or manual Python scripts.
  2. Generic Naming: Always use generic examples (e.g., vmid: 100) when discussing actions.
  3. Safety: Always verify the current state of a resource (using get_vms) before performing power or deletion tasks.


