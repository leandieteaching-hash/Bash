# Completed Spread Manager mutations

Implemented:

- Create a review request from the asset/version screen.
- Complete an assigned review with any number of comments.
- Resolve required-change comments with a resolution note.
- Approve an asset version only after a completed review and no unresolved required changes.
- Revoke an approval and return the asset to Changes Requested.
- Lock and unlock a spread with an audited reason.
- Edit task title, description, status, priority, assignee, due date, and blocker.
- Approve proposed decisions.
- Supersede approved decisions by creating a replacement and preserving the original record.

## Apply migration

```bash
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f src/db/010_complete_spread_manager_mutations.sql
```

## Required permissions

- `spread.view`
- `spread.lock`
- `review.request`
- `review.complete`
- `review.complete_any` (optional elevated permission)
- `review.resolve_comment`
- `asset.approve`
- `task.edit`
- `decision.approve`

## Authentication adapter

Replace the development implementation in `src/lib/spread-manager-server.ts` with the application's existing Supabase session/profile/RBAC resolver.
