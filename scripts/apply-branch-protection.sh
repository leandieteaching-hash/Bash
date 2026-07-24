#!/usr/bin/env bash
set -euo pipefail

repo="${1:-}"
branch="${2:-main}"

if [[ -z "$repo" ]]; then
  echo "Usage: $0 OWNER/REPOSITORY [BRANCH]" >&2
  exit 64
fi

command -v gh >/dev/null || { echo "GitHub CLI (gh) is required." >&2; exit 69; }
gh auth status >/dev/null

gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "repos/${repo}/branches/${branch}/protection" \
  --input .github/branch-protection.json
