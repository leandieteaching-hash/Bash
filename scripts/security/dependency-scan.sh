#!/usr/bin/env bash
set -euo pipefail
[[ -f package-lock.json ]] || { echo 'ERROR: dependency scan requires package-lock.json.' >&2; exit 1; }
npm audit --audit-level=high
