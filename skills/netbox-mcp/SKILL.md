name: netbox-mcp
description: NetBox IPAM and DCIM operations via OpenAPI.
tools:
  - type: mcp
    command: sh
    args: 
      - "-c"
      - 'npx -y @ivotoby/openapi-mcp-server --api-base-url ${NETBOX_URL}/api --openapi-spec ${NETBOX_URL}/api/schema/ --headers "Authorization: Token ${NETBOX_TOKEN}"'
