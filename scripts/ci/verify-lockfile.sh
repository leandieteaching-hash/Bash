#!/usr/bin/env bash
set -euo pipefail
[[ -f package-lock.json ]] || { echo 'ERROR: package-lock.json is required.' >&2; exit 1; }
node -e "const p=require('./package-lock.json'); if (p.lockfileVersion < 3) throw new Error('npm lockfileVersion 3+ required')"
npm ci --ignore-scripts
npm ls --all
