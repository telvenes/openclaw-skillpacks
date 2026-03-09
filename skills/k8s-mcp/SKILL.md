name: k8s-mcp
description: Kubernetes diagnostics via kubernetes-mcp-server (events/config/helm list) without kubectl.
tools:
  - type: exec
instructions: |
  Use the wrapper script to interact with Kubernetes via MCP:

  - `scripts/k8s.sh events <namespace>` (default: openclaw)
    Use this first when troubleshooting restarts, readiness/startup probe failures, or controller rollouts.
    Summarize Warning events and include timestamps.

  - `scripts/k8s.sh config`
    Show the current cluster config (minified).

  - `scripts/k8s.sh helm-list`
    List Helm releases (read-only with current RBAC).
