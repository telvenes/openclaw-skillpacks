Proxmox VE Infrastructure Skill
Description: High-fidelity management of Proxmox clusters using the ProxmoxMCP-Plus framework.
🛑 AGENT PROTOCOL: ANTI-HALLUCINATION
 * NO SHELL CODE: You are strictly forbidden from generating Python scripts, using curl, or attempting to install packages via pip to interact with Proxmox.
 * TOOL RELIANCE: If you cannot see the tools (get_vms, get_nodes, etc.) in your tool list, do NOT attempt to guess the API. Instead, verify that the MCP server has started correctly.
 * ENVIRONMENT: Do not look for .env or config.json files. Credentials are pre-injected into the process environment.
🔐 Authentication Specs
This skill uses PVE API Tokens.
 * PROXMOX_TOKEN_VALUE is a UUID-style secret (e.g., xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx).
 * It is NOT a standard password.
 * Connection uses verify_ssl=false for internal lab reliability.
🛠️ Execution Requirements
The server runs in a dedicated Kubernetes workspace. It must be invoked with the specific PYTHONPATH to resolve the proxmox_mcp module:
PYTHONPATH=skills/proxmox-mcp/src python3 -m proxmox_mcp.server

🧰 Available Operations Reference
1. Cluster & Node Discovery
 * get_nodes: Returns a structured table of node health (CPU/RAM/Uptime).
 * get_cluster_status: Verifies quorum and Ceph health indicators.
 * get_storage: Lists all pools (Ceph RBD, LVM-Thin, NFS).
2. Virtualization Management (QEMU & LXC)
 * get_vms / get_containers: The source of truth for all running instances.
 * create_vm / create_container: Used for automated provisioning.
 * start_vm / stop_vm / shutdown_vm: Standard power operations.
 * execute_vm_command: Runs commands inside VMs using the QEMU Guest Agent.
3. Disaster Recovery
 * list_snapshots / create_snapshot: Used before risky operations (like upgrades).
 * list_backups / create_backup: Interfaces with vzdump for full node/storage backups.
📜 Operational Guidelines
 * Verification First: Always run get_vms or get_nodes before attempting any change (Start/Stop/Delete).
 * Naming Convention: Use generic placeholder names (e.g., vm-101, template-ubuntu) in responses unless a specific name is found in the live cluster.
 * Error Handling: If an operation fails with "Permission Denied", inform the user to check the API Token permissions (PVEAdmin/PVEAuditor) in the Proxmox UI.
