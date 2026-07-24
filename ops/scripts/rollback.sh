#!/usr/bin/env bash
set -euo pipefail
: "${KUBE_NAMESPACE:?KUBE_NAMESPACE is required}"
revision="${1:-}"
command -v kubectl >/dev/null || { echo 'kubectl is required' >&2; exit 1; }
if [[ -n "$revision" ]]; then
  kubectl -n "$KUBE_NAMESPACE" rollout undo deployment/studio-os-web --to-revision="$revision"
else
  kubectl -n "$KUBE_NAMESPACE" rollout undo deployment/studio-os-web
fi
kubectl -n "$KUBE_NAMESPACE" rollout status deployment/studio-os-web --timeout=5m
