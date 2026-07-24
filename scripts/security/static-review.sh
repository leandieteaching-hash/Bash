#!/usr/bin/env bash
set -euo pipefail
fail=0
scan() {
  local label="$1" pattern="$2"
  if grep -RInE --exclude-dir=.git --exclude='package-lock.json' "$pattern" apps packages database ops scripts .github 2>/dev/null; then
    echo "SECURITY REVIEW FAILURE: $label" >&2
    fail=1
  fi
}
scan 'private key material detected' 'BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY'
scan 'hard-coded bearer token detected' 'Authorization:[[:space:]]*Bearer[[:space:]]+[A-Za-z0-9._-]{20,}'
scan 'service role key assigned in source' '(SUPABASE_SERVICE_ROLE_KEY|DATABASE_PASSWORD)[[:space:]]*=[[:space:]]*[^${[:space:]]'
scan 'unsafe dynamic code execution' '\beval\s*\(|new Function\s*\('
scan 'shell invocation from application code' 'child_process|execSync\s*\(|spawnSync\s*\('
if [[ $fail -ne 0 ]]; then exit 1; fi
echo 'Static security review passed.'
