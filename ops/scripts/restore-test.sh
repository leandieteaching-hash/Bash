#!/usr/bin/env bash
set -euo pipefail
backup="${1:?usage: restore-test.sh <backup.dump>}"
: "${RESTORE_DATABASE_URL:?RESTORE_DATABASE_URL is required}"
command -v pg_restore >/dev/null || { echo 'pg_restore is required' >&2; exit 1; }
[[ -f "$backup" && -f "$backup.sha256" ]] || { echo 'backup or checksum missing' >&2; exit 1; }
(cd "$(dirname "$backup")" && sha256sum -c "$(basename "$backup").sha256")
pg_restore --clean --if-exists --no-owner --no-acl --dbname="$RESTORE_DATABASE_URL" "$backup"
psql "$RESTORE_DATABASE_URL" -v ON_ERROR_STOP=1 -c 'SELECT count(*) FROM platform_sessions;' >/dev/null
echo 'Restore verification passed.'
