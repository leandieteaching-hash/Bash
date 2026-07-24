#!/usr/bin/env bash
set -euo pipefail
required=(src/app/admin/system-health/page.tsx src/features/operations/OperationsDashboard.tsx src/app/api/operations/health/route.ts src/app/api/operations/metrics/route.ts ../../database/migrations/017_production_operations.sql ../../ops/scripts/backup.sh ../../ops/scripts/verify-restore.sh ../../ops/alerts/prometheus.rules.yml ../../.github/workflows/ci.yml ../../.github/workflows/deploy.yml ../../docs/architecture/PRODUCTION_OPERATIONS.md)
for f in "${required[@]}"; do test -f "$f" || { echo "Missing $f"; exit 1; }; done
grep -q "System Health" src/features/registry.ts
grep -q "test:operations" package.json
echo "Production operations structural checks passed."
