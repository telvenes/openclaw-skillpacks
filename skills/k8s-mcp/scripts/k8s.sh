#!/bin/sh
set -eu

KUBECTL_BIN="${KUBECTL_BIN:-}"

ensure_kubectl() {
  if [ -n "${KUBECTL_BIN}" ] && [ -x "${KUBECTL_BIN}" ]; then
    return 0
  fi

  if command -v kubectl >/dev/null 2>&1; then
    KUBECTL_BIN="$(command -v kubectl)"
    return 0
  fi

  # Download kubectl into a writable path (persist across restarts)
  # Uses in-cluster CA + token by default, so no kubeconfig is needed.
  TARGET="${HOME}/.local/bin/kubectl"
  mkdir -p "$(dirname "$TARGET")"

  if [ ! -x "$TARGET" ]; then
    # Pin to a known stable version (adjust if you want)
    VER="${KUBECTL_VERSION:-v1.31.0}"
    URL="https://dl.k8s.io/release/${VER}/bin/linux/amd64/kubectl"
    curl -fsSL "$URL" -o "$TARGET"
    chmod +x "$TARGET"
  fi

  KUBECTL_BIN="$TARGET"
}

k() {
  ensure_kubectl

  # Use in-cluster auth explicitly (no kubeconfig needed)
  SA_DIR="/var/run/secrets/kubernetes.io/serviceaccount"
  CA="${SA_DIR}/ca.crt"
  TOKEN_FILE="${SA_DIR}/token"
  NS_FILE="${SA_DIR}/namespace"

  TOKEN="$(cat "$TOKEN_FILE")"
  SERVER="https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}"

  # NOTE: kubectl supports these flags broadly; keep it simple and deterministic
  "$KUBECTL_BIN" \
    --server="$SERVER" \
    --certificate-authority="$CA" \
    --token="$TOKEN" \
    "$@"
}

usage() {
  cat <<EOF
Usage:
  $0 events <namespace| -A>
  $0 get <resource> [name] [-n ns|-A] [--field-selector ...] [-o ...]
  $0 describe <kind> <name> -n <namespace>
  $0 logs <pod> [-n ns] [-c container] [--tail N]
  $0 health
EOF
  exit 1
}

cmd="${1:-}"
shift || true

case "$cmd" in
  events)
    ns="${1:-openclaw}"
    if [ "$ns" = "-A" ] || [ "$ns" = "--all-namespaces" ]; then
      k get events -A --sort-by=.lastTimestamp
    else
      k get events -n "$ns" --sort-by=.lastTimestamp
    fi
    ;;

  get)
    # read-only wrapper
    k get "$@"
    ;;

  describe)
    k describe "$@"
    ;;

  logs)
    k logs "$@"
    ;;

  health)
    k version --client=true
    echo "---"
    k cluster-info
    ;;

  ""|-h|--help|help)
    usage
    ;;

  *)
    echo "Unknown command: $cmd" >&2
    usage
    ;;
esac
