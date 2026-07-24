#!/usr/bin/env bash
set -euo pipefail
required=(
 'src/app/admin/platform/page.tsx'
 'src/app/design-system/page.tsx'
 'src/app/api/v1/platform/status/route.ts'
 'src/app/api/v1/platform/events/route.ts'
 'src/app/api/v1/platform/audit/route.ts'
 'src/lib/platform/context.ts'
 'src/lib/platform/event-bus.ts'
 'src/lib/platform/audit.ts'
 '../../database/migrations/018_platform_foundation.sql'
 '../../docs/architecture/PLATFORM_FOUNDATION.md'
)
for file in "${required[@]}"; do test -f "$file" || { echo "Missing $file"; exit 1; }; done
grep -q 'enable row level security' ../../database/migrations/018_platform_foundation.sql
grep -q 'platform_event_outbox' ../../database/migrations/018_platform_foundation.sql
grep -q '/admin/platform' src/components/layout/AppShell.tsx
grep -q 'platform.admin' src/features/registry.ts
echo 'Platform Foundation structural validation passed.'
