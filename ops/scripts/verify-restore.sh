#!/usr/bin/env bash
set -euo pipefail
: "${BACKUP_FILE:?BACKUP_FILE is required}"; : "${RESTORE_DATABASE_URL:?RESTORE_DATABASE_URL is required}"
sha256sum -c "$BACKUP_FILE.sha256"
pg_restore --clean --if-exists --no-owner --no-acl --dbname "$RESTORE_DATABASE_URL" "$BACKUP_FILE"
psql "$RESTORE_DATABASE_URL" -v ON_ERROR_STOP=1 -c "select count(*) from public.spreads;"
echo "Restore verification passed"
