#!/usr/bin/env bash
set -euo pipefail
base_url="${1:-http://localhost:3000}"
headers="$(mktemp)"; trap 'rm -f "$headers"' EXIT
curl --fail --silent --show-error --dump-header "$headers" --output /dev/null "$base_url/login"
for header in content-security-policy x-content-type-options referrer-policy permissions-policy; do
  grep -qi "^${header}:" "$headers" || { echo "Missing security header: $header" >&2; exit 1; }
done
echo 'Runtime security headers verified.'
