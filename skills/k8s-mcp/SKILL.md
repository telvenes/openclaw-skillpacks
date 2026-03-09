name: k8s-mcp
description: Read-only Kubernetes diagnostics tools using the in-cluster ServiceAccount.
tools:
  - type: mcp
    command: sh
    args: ["skills/k8s-mcp/scripts/k8s.sh"]
instructions: |
  Always use this MCP server for Kubernetes troubleshooting in this OpenClaw instance.
  
  The server provides the following structured tools:
  - k8s_events: Show recent events
  - k8s_get: Get resources (read-only)
  - k8s_describe: Describe a specific resource
  - k8s_logs: Get logs for a pod
  - k8s_health: Quick cluster reachability test

  Rules:
    - Prefer using the `k8s_events` tool first when debugging restarts/probes.
    - Do NOT attempt write operations. This is read-only on purpose.
