#!/usr/bin/env bash
set -euo pipefail
: "${BASE_URL:?BASE_URL is required}"
max_failures=${MAX_FAILURES:-1}
failures=0
for path in /api/health/live /api/health/ready; do
  if ! curl --fail --silent --show-error --max-time 10 "$BASE_URL$path" >/dev/null; then
    failures=$((failures+1))
  fi
done
(( failures <= max_failures )) || { echo "resilience smoke failed: $failures endpoint failures"; exit 1; }
echo "resilience smoke passed"
