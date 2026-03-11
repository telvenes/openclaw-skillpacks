---
name: k8s-mcp
description: |
  Read-only Kubernetes diagnostics via in-cluster ServiceAccount.
  Does NOT require kubectl. Designed for safe troubleshooting in LLM-driven ops.

tools:
  - type: mcp
    command: bash
    args: ["skills/k8s-mcp/scripts/k8s.sh"]

instructions: |
  Use this skill for Kubernetes troubleshooting.

  IMPORTANT:
  - The skill name is "k8s-mcp". It is NOT a tool name.
  - Valid tool names are:
    - k8s_health
    - k8s_events
    - k8s_get
    - k8s_describe
    - k8s_logs
  - Never call a tool named "k8s-mcp" (it does not exist).
  - Do not use exec/kubectl. kubectl is not installed.

  Safety:
  - Read-only only.
  - Secrets are blocked.

  Common patterns:
  - List pods in a namespace:
    Use k8s_get with resource "pods" and the namespace.
  - Show warnings:
    Use k8s_events with type "warnings".
  - Fetch logs:
    Use k8s_logs with pod + optional container.

  Examples (exact argument shapes):
  - Pods in namespace dev:
    k8s_get {"resource":"pods","namespace":"dev","limit":200}
  - Warning events in namespace dev:
    k8s_events {"namespace":"dev","type":"warnings","limit":50}
  - Logs:
    k8s_logs {"namespace":"dev","pod":"<pod>","container":"<container>","tailLines":200}

metadata:
  author: telvenes
  version: "0.2.1"
---

# k8s-mcp (read-only)

Minimal Kubernetes diagnostics for OpenClaw.

## Notes
- In-cluster ServiceAccount token + CA
- No kubectl dependency
- Secrets blocked by design

## Typical workflow
1. k8s_health
2. k8s_events (namespace)
3. k8s_get (pods/deployments/services)
4. k8s_describe (failing object)
5. k8s_logs (crashing pod)
