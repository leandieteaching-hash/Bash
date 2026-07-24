#!/usr/bin/env bash
set -euo pipefail
if grep -RInE '\.(insert|update|delete|upsert)\(' src/features/spread-manager src/lib --include='*.ts' --include='*.tsx'; then
  echo 'Direct Supabase mutations are forbidden in the Spread Manager service boundary.' >&2
  exit 1
fi
echo 'PASS: Spread Manager TypeScript contains no direct database mutations.'
