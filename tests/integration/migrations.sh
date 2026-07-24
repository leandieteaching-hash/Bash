#!/usr/bin/env bash
set -euo pipefail
: "${DATABASE_URL:?DATABASE_URL is required}"
command -v psql >/dev/null || { echo 'psql is required' >&2; exit 1; }
for migration in database/migrations/*.sql; do
  echo "Applying $migration"
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$migration" >/dev/null
done
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<'SQL'
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname='public' AND tablename='platform_sessions') THEN
    RAISE EXCEPTION 'platform_sessions missing after migrations';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname='public' AND tablename='spread_annotations') THEN
    RAISE EXCEPTION 'spread_annotations missing after migrations';
  END IF;
END $$;
SQL
echo 'Migration integration test passed.'
