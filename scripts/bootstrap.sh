#!/usr/bin/env bash
set -euo pipefail
command -v node >/dev/null || { echo 'Node.js 20+ is required.' >&2; exit 1; }
command -v npm >/dev/null || { echo 'npm 10+ is required.' >&2; exit 1; }
[[ -f .env ]] || cp .env.example .env
npm ci
printf '\nStudio OS dependencies installed.\nRun: npm run dev:services && npm run dev\n'
