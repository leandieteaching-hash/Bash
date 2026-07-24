#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
required=(
  "$root/database/migrations/020_email_password_authentication.sql"
  "$root/apps/web/src/lib/auth/service.ts"
  "$root/apps/web/src/lib/auth/cookies.ts"
  "$root/apps/web/src/app/api/v1/auth/login/route.ts"
  "$root/apps/web/src/app/api/v1/auth/refresh/route.ts"
  "$root/apps/web/src/app/api/v1/auth/password/forgot/route.ts"
  "$root/apps/web/src/app/api/v1/auth/password/reset/route.ts"
  "$root/apps/web/src/app/(auth)/login/page.tsx"
  "$root/docs/adr/0003-authentication-and-session-lifecycle.md"
)
for file in "${required[@]}"; do test -f "$file" || { echo "Missing $file"; exit 1; }; done
grep -q "refresh_token_hash" "$root/database/migrations/020_email_password_authentication.sql"
grep -q "rotation_counter" "$root/database/migrations/020_email_password_authentication.sql"
grep -q "httpOnly: true" "$root/apps/web/src/lib/auth/config.ts"
grep -q "signInWithPassword" "$root/apps/web/src/lib/auth/service.ts"
grep -q "refreshSession" "$root/apps/web/src/lib/auth/service.ts"
grep -q "RATE_LIMITED" "$root/apps/web/src/app/api/v1/auth/login/route.ts"
echo "Email/password authentication structural test passed."
