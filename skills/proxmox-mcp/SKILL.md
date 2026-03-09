Proxmox MCP Skill
Description: Advanced Proxmox VE and Ceph management via Model Context Protocol.
🛑 CRITICAL: Authentication
This skill strictly uses API Token authentication. Do NOT attempt to use standard passwords.
Required Environment Variables:
 * PROXMOX_HOST: API host IP or FQDN (e.g., 10.0.0.1).
 * PROXMOX_USER: Username with realm (e.g., mcp-user@pam).
 * PROXMOX_TOKEN_NAME: The ID assigned to the token in PVE (e.g., openclaw).
 * PROXMOX_TOKEN_VALUE: The actual Token Secret value.
 * PROXMOX_VERIFY_SSL: Set to false for self-signed certificates.
🛠️ Execution Context
The server must be executed as a module with the correct PYTHONPATH to find the source code:
PYTHONPATH=skills/proxmox-mcp/src python3 -m proxmox_mcp.server

🧰 Available Tools
Monitoring & Status
 * get_nodes: List cluster nodes and resource usage.
 * get_cluster_status: Check cluster quorum and health.
 * get_storage: List storage pools (Ceph, LVM, NFS).
 * get_node_status: Detailed metrics for a specific node.
VM & Container Management
 * get_vms / get_containers: List all instances and current status.
 * create_vm / create_container: Provision new resources.
 * start_vm / stop_vm / shutdown_vm / reset_vm: Power management operations.
 * execute_vm_command: Run commands via QEMU Guest Agent.
 * execute_container_command: Run commands via SSH + pct exec.
Snapshots & Backups
 * list_snapshots / create_snapshot: Manage recovery states.
 * list_backups / create_backup: Monitor and trigger vzdump operations.
📜 Usage Rules
 * Tool Priority: Use these structured tools for ALL Proxmox queries. Never use curl, pip, or manual Python scripts.
 * Generic Naming: Always use generic examples (e.g., vmid: 100, name: "vm-web-01") when discussing or suggesting actions.
 * Safety: Always verify the current state of a resource (using get_vms) before performing power or deletion tasks.
