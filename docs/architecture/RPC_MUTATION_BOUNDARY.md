# RPC mutation boundary

Migration `013_rpc_mutation_boundary.sql` moves every remaining Spread Manager write into PostgreSQL workflow functions.

## RPC-only actions

- asset version upload and current-version switching
- task creation, editing, dependency add, and dependency removal
- decision creation, approval, and supersession
- spread lock and unlock
- review-request creation, review completion, and comment resolution
- approval and revocation
- character appearance add and remove

Each function locks its workflow root, checks the spread state, performs all related writes, and records activity in the same transaction. `service.ts` performs reads directly but contains no `.insert()`, `.update()`, `.delete()`, or `.upsert()` calls.

## Apply

```bash
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f src/db/013_rpc_mutation_boundary.sql
```

## Verify

```bash
./tests/no-direct-mutations.sh
DATABASE_URL="postgresql://..." tests/database/run.sh
```

The static guard should run in CI to prevent future direct mutations from being added to the TypeScript service layer.
