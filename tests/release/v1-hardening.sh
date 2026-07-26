#!/usr/bin/env bash
set -euo pipefail
test -x scripts/release/verify-migrations.sh
test -x scripts/release/build-manifest.sh
test -x scripts/release/go-no-go.sh
grep -q 'automatic no-go' docs/releases/v1.0.0/RELEASE_HARDENING.md
scripts/release/verify-migrations.sh >/tmp/studio-os-migration-checksums.txt
if scripts/release/go-no-go.sh evidence/v1.0.0/gate-results.json; then
  echo 'expected no-go evidence to be rejected' >&2; exit 1
fi
