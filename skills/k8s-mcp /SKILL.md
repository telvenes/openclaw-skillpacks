name: k8s-mcp
description: Kubernetes diagnostics via kubernetes-mcp-server (events/config/helm list) without kubectl.
tools:
  - type: exec
instructions: |
  Use scripts/k8s.sh for Kubernetes diagnostics.
  Prefer:
  - `scripts/k8s.sh events <namespace>` to fetch recent events and warnings (default namespace: openclaw).
  - `scripts/k8s.sh config` to view the current kube context (minified).
  - `scripts/k8s.sh helm-list` to list Helm releases (read-only with current RBAC).
  When the user asks about restarts, readiness issues, or failures, run events first and summarize warnings with timestamps.
