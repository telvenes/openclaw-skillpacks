name: k8s-mcp
description: Kubernetes diagnostics via kubernetes-mcp-server (events/config/helm list) using MCP.
tools:
  - type: exec
instructions: |
  Always use the exec tool to run the wrapper script. Do not ask questions first.

  Commands (default namespace: openclaw):
  - `sh /home/openclaw/.openclaw/workspace/skills/k8s-mcp/scripts/k8s.sh events [namespace]`
  - `sh /home/openclaw/.openclaw/workspace/skills/k8s-mcp/scripts/k8s.sh config`
  - `sh /home/openclaw/.openclaw/workspace/skills/k8s-mcp/scripts/k8s.sh helm-list`

  When asked to troubleshoot, run `events` immediately and summarize Warning events with timestamps.
