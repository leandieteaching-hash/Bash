#!/usr/bin/env bash
set -euo pipefail
: "${DATABASE_URL:?Set DATABASE_URL to the test database}"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f ../../database/migrations/012_transactional_workflows.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f ../../database/migrations/013_rpc_mutation_boundary.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f ../../database/migrations/014_realtime_collaboration.sql
./tests/no-direct-mutations.sh
pg_prove --ext .sql --recurse --dbname "$DATABASE_URL" tests/database
