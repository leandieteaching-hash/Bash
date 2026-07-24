#!/usr/bin/env bash
set -euo pipefail
: "${DATABASE_URL:?DATABASE_URL is required}"
: "${BACKUP_DIR:?BACKUP_DIR is required}"
command -v pg_dump >/dev/null || { echo 'pg_dump is required' >&2; exit 1; }
mkdir -p "$BACKUP_DIR"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
out="$BACKUP_DIR/studio-os-$stamp.dump"
pg_dump "$DATABASE_URL" --format=custom --no-owner --no-acl --file="$out"
sha256sum "$out" > "$out.sha256"
echo "$out"
