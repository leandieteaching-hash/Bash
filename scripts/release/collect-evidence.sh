#!/usr/bin/env bash
set -euo pipefail

release="${1:-v1.0.0-rc.1}"
out="evidence/${release}"
mkdir -p "$out"

node_version="$(node --version 2>/dev/null || echo unavailable)"
npm_version="$(npm --version 2>/dev/null || echo unavailable)"
commit="$(git rev-parse HEAD)"
branch="$(git branch --show-current)"

cat > "$out/environment.json" <<JSON
{
  "release": "$release",
  "commit": "$commit",
  "branch": "$branch",
  "node": "$node_version",
  "npm": "$npm_version",
  "generatedAtUtc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
JSON

{
  echo "release=$release"
  echo "commit=$commit"
  echo "branch=$branch"
  echo "generated_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo
  echo '[git-status]'
  git status --short
  echo
  echo '[recent-history]'
  git log --oneline -20
} > "$out/repository.txt"

find "$out" -maxdepth 1 -type f ! -name SHA256SUMS -print0 \
  | sort -z \
  | xargs -0 sha256sum > "$out/SHA256SUMS"

echo "Evidence written to $out"
