#!/usr/bin/env bash
set -euo pipefail
grep -q 'customer_onboarding_runs' database/migrations/028_customer_onboarding.sql
grep -q 'enable row level security' database/migrations/028_customer_onboarding.sql
grep -q 'idempotency_key' database/migrations/028_customer_onboarding.sql
test -x scripts/migration/validate-import.sh
test -x scripts/migration/reconcile-counts.sh
