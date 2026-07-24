#!/usr/bin/env bash
set -euo pipefail

tag="${1:-v1.0.0-alpha.1}"

[[ -f package-lock.json ]] || { echo "package-lock.json is required." >&2; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { echo "Working tree must be clean." >&2; exit 1; }

npm ci
npm run verify

git tag -s "$tag" -m "Studio OS Platform Foundation ${tag}"
echo "Verified and tagged ${tag}. Push with: git push origin main --follow-tags"
