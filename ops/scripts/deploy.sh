#!/usr/bin/env bash
set -euo pipefail
environment="${1:?usage: deploy.sh <staging|production>}"
case "$environment" in staging|production) ;; *) echo 'invalid environment' >&2; exit 2;; esac
: "${IMAGE_REF:?IMAGE_REF is required}"
: "${KUBE_NAMESPACE:?KUBE_NAMESPACE is required}"
command -v kubectl >/dev/null || { echo 'kubectl is required' >&2; exit 1; }
kubectl -n "$KUBE_NAMESPACE" set image deployment/studio-os-web web="$IMAGE_REF" --record
kubectl -n "$KUBE_NAMESPACE" rollout status deployment/studio-os-web --timeout=5m
kubectl -n "$KUBE_NAMESPACE" annotate deployment/studio-os-web "studio-os/deployed-at=$(date -u +%FT%TZ)" --overwrite
echo "Deployment completed for $environment: $IMAGE_REF"
