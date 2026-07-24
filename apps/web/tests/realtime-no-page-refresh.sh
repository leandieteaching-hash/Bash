#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="$ROOT/src/features/spread-manager"

if grep -R -n -E 'window\.location\.reload|location\.reload|router\.refresh\(' "$TARGET"; then
  echo "Realtime UI must reconcile in place; full-page refresh detected." >&2
  exit 1
fi

grep -q "useSpreadRealtime" "$TARGET/SpreadManager.tsx"
grep -q "postgres_changes" "$TARGET/use-spread-realtime.ts"
echo "Realtime collaboration static checks passed."
