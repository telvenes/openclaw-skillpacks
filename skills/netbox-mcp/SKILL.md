name: netbox-mcp
description: NetBox IPAM and DCIM operations.
tools:
  - type: mcp
    command: sh
    args: 
      - "-c"
      - 'npx -y @ivotoby/openapi-mcp-server --api-base-url "${NETBOX_URL}/api" --openapi-spec "${NETBOX_URL}/api/schema/" --headers "Authorization: Token ${NETBOX_TOKEN}"'
instructions: |
  You have DIRECT access to NetBox through this MCP server. 
  
  DO NOT look for tokens, URLs, or .env files. They are already injected into the environment.
  DO NOT use 'curl' or 'fetch' to call the NetBox API manually.
  
  Use ONLY the structured MCP tools provided by this skill to query:
  - Prefixes (IP ranges)
  - IP Addresses
  - Devices/VMs
  
  If you are asked for IP ranges, look for 'ipam_prefixes_list' or similar tools provided by the server.
