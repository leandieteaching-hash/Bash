#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
repo="$(cd "$root/../.." && pwd)"
required=(
  "$repo/database/migrations/021_tenant_request_context.sql"
  "$root/src/lib/tenancy/context.ts"
  "$root/src/lib/tenancy/switch.ts"
  "$root/src/app/api/v1/tenant/context/route.ts"
  "$root/src/app/api/v1/tenant/settings/route.ts"
  "$root/src/components/tenancy/OrganisationSwitcher.tsx"
)
for file in "${required[@]}"; do test -f "$file" || { echo "Missing $file"; exit 1; }; done
grep -q "TENANT_ACCESS_DENIED" "$repo/database/migrations/021_tenant_request_context.sql"
grep -q "switch_active_organisation" "$repo/database/migrations/021_tenant_request_context.sql"
grep -q "platform_audit_tenant_select" "$repo/database/migrations/021_tenant_request_context.sql"
grep -q "response.cookies.set(ACTIVE_ORGANISATION_COOKIE" "$root/src/app/api/v1/organisations/switch/route.ts"
grep -q "withTenantContext" "$root/src/app/api/v1/tenant/context/route.ts"
echo "Multi-tenancy request context and isolation checks passed."
