name: proxmox-mcp description: Proxmox VE MCP server (read-first, optional write ops gated by PROXMOX_ALLOW_WRITE). tools: - type: mcp id: proxmox command: sh args: - "-c" - "pip install -q -r skills/proxmox-mcp/requirements.txt && PYTHONPATH=skills/proxmox-mcp/src python3 -m proxmox_mcp.server" timeout: 300 env: PROXMOX_HOST: "" PROXMOX_USER: "" PROXMOX_TOKEN_NAME: "" PROXMOX_TOKEN_VALUE: "" PROXMOX_VERIFY_SSL: "true" PROXMOX_ALLOW_WRITE: "false"
instructions: |
  CRITICAL:
  - This server supports Proxmox API Token auth (user + token_name + token_value).
  - Read operations are always enabled.
  - Write operations (start/stop/shutdown) are disabled unless PROXMOX_ALLOW_WRITE=true.
  - Config may arrive via process env OR via OpenClaw config in /home/openclaw/.openclaw/openclaw.json under skills.entries.proxmox-mcp.env.
  - If PROXMOX_TOKEN_VALUE contains ${VAR}, the server resolves it from process env (e.g. ${PROXMOX_TOKEN_SECRET}).
