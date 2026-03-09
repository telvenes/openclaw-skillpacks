name: k8s-mcp
description: Read-only Kubernetes diagnostics (events/logs/describe/get) using the in-cluster ServiceAccount.
tools:
  - type: exec
instructions: |
  Always use this skill for Kubernetes troubleshooting in this OpenClaw instance.

  Primary entrypoint:
    sh skills/k8s-mcp/scripts/k8s.sh <command> [args...]

  Commands:
    events <namespace>         - Show recent events in YAML-ish format (includes Warning)
    get <resource> [-n ns|-A]  - kubectl get wrapper (read-only)
    describe <kind> <name> -n ns
    logs <pod> [-n ns] [-c container] [--tail N]
    health                    - Quick cluster reachability test

  Rules:
    - Prefer "events <ns>" first when debugging restarts/probes.
    - Do NOT attempt write operations (apply/delete/patch/scale). This is read-only on purpose.
    - When user asks "check my cluster for errors", run:
        1) events -A
        2) get pods -A
        3) summarize only Warning events + the top restart offenders
