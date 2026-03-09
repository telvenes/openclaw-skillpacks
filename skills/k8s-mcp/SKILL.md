name: k8s-mcp
description: >
  Read-only Kubernetes diagnostics using in-cluster ServiceAccount (no kubectl required).
  Commands: events, warnings, helm-list, config, version.
tools:
  - type: exec
    instructions: |
      Use the wrapper script (read-only).

      Preferred usage (stable path when installed into workspace):
        sh /home/openclaw/.openclaw/workspace/skills/k8s-mcp/scripts/k8s.sh <command> [args...]

      If your environment installs skills elsewhere (e.g. under argocd/apps/openclaw),
      locate the script first:
        find /home/openclaw/.openclaw/workspace -name k8s.sh 2>/dev/null

      Commands:
        events [namespace] [limit]
          - Lists recent events in YAML-like blocks (default namespace: openclaw, default limit: 200)

        warnings [namespace] [limit]
          - Same as events, but only Type=Warning.

        helm-list [namespace]
          - Lists Helm releases in the namespace by inspecting secrets labeled owner=helm.
            (Requires RBAC to list secrets in that namespace.)

        config
          - Prints in-cluster API endpoint, namespace, and basic runtime info.

        version
          - Prints Kubernetes /version from the API.

      Output rules for assistants:
        - Do NOT guess.
        - Prefer summarizing Warning events with timestamp + message.
        - If RBAC denies access, include the error output verbatim.
