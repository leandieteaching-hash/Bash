#!/usr/bin/env bash
set -euo pipefail
test -x ops/resilience/chaos-smoke.sh
test -x ops/resilience/verify-rpo-rto.sh
grep -q 'RPO 15 minutes' docs/operations/DISASTER_RECOVERY.md
grep -q 'tenant isolation' docs/operations/DISASTER_RECOVERY.md
