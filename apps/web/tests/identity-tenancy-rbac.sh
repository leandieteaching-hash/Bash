#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
MIGRATION="$ROOT/database/migrations/019_identity_tenancy_authorization.sql"

test -f "$MIGRATION"
grep -q "create table if not exists public.platform_sessions" "$MIGRATION"
grep -q "create or replace function public.has_permission" "$MIGRATION"
grep -q "enable row level security" "$MIGRATION"
grep -q "platform_password_reset_tokens" "$MIGRATION"

test -f "$ROOT/packages/auth/src/index.ts"
test -f "$ROOT/packages/tenancy/src/index.ts"
test -f "$ROOT/packages/permissions/src/index.ts"
test -f "$ROOT/apps/web/src/app/api/v1/auth/session/route.ts"
test -f "$ROOT/apps/web/src/app/api/v1/organisations/switch/route.ts"
test -f "$ROOT/docs/adr/0002-identity-tenancy-and-authorization.md"

echo "Identity, tenancy and RBAC foundation checks passed."
