#!/usr/bin/env bash
set -euo pipefail
: "${DATABASE_URL:?DATABASE_URL is required}"
DEST=${BACKUP_DESTINATION:-./backups}; mkdir -p "$DEST"; TS=$(date -u +%Y%m%dT%H%M%SZ); FILE="$DEST/studio-os-$TS.dump"
pg_dump --format=custom --no-owner --no-acl "$DATABASE_URL" > "$FILE"
sha256sum "$FILE" > "$FILE.sha256"
echo "Created $FILE"
