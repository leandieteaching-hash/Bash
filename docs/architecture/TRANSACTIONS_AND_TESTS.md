# Transactional workflows and integration tests

## Migration order

1. Apply migrations 001–011.
2. Apply `src/db/012_transactional_workflows.sql`.
3. Regenerate Supabase database types so the RPC names are available to TypeScript.
4. Deploy the updated Spread Manager service.

## Atomic RPCs

- `workflow_upload_asset_version`
- `workflow_switch_asset_version`
- `workflow_complete_review`
- `workflow_approve_asset_version`
- `workflow_revoke_approval`
- `workflow_add_task_dependency`

Each function obtains row-level locks and either commits its full state transition and activity event or rolls back the complete call.

## First integration tests

`tests/database/012_transactional_workflows.test.sql` verifies:

1. Uploading version 2 leaves version 1 intact.
2. Approval fails with unresolved required-change comments.
3. Active approval prevents changing the current version.
4. Task dependency cycles are rejected.
5. Locked spreads reject both workflow RPCs and direct task edits.
6. Approved decisions cannot be modified; only a content-preserving transition to `Superseded` is allowed.

## CI example

```yaml
- name: Apply database migrations
  run: supabase db reset

- name: Run PostgreSQL integration tests
  env:
    DATABASE_URL: postgresql://postgres:postgres@127.0.0.1:54322/postgres
  run: tests/database/run.sh
```

Use a disposable database. The suite begins a transaction and rolls back its test changes, but the migration itself is intentionally persistent.
