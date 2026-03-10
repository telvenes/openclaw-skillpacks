# Proxmox MCP Skill

## How to use (MANDATORY)

When you need Proxmox inventory (nodes, VMs, containers, storage):

1) **ALWAYS run the debug helper first:**
```sh
sh /home/openclaw/.openclaw/workspace/skills/proxmox-mcp/scripts/proxmox-debug.sh
```

**DO NOT use curl/fetch against :8006 or random hosts.**

If PROXMOX_* env is not visible in the process env, this skill automatically loads it from:
`/home/openclaw/.openclaw/openclaw.json` under `skills.entries.proxmox-mcp.env`.

2) **Start the MCP server:**
```sh
sh /home/openclaw/.openclaw/workspace/skills/proxmox-mcp/scripts/proxmox.sh
```

**Required env:**
- `PROXMOX_HOST`
- `PROXMOX_USER`
- `PROXMOX_TOKEN_NAME`
- `PROXMOX_TOKEN_VALUE` (may be templated as `${PROXMOX_TOKEN_SECRET}`)
- `PROXMOX_VERIFY_SSL` (false recommended for internal)
