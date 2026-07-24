# Realtime collaboration

Migration `014_realtime_collaboration.sql` publishes committed Spread Manager changes through Supabase Realtime. The browser subscribes with the signed-in user's Supabase session, so table RLS remains the visibility boundary.

## Covered changes

- assets and asset versions
- review requests, completed reviews, and review comments
- approvals and revocations
- tasks
- spread lock and unlock changes
- decisions and character appearances used by the same manager payload

## Client behavior

`useSpreadRealtime()` opens one channel per spread and listens for Postgres Changes. Events are debounced for 180 ms because one transactional workflow can update several tables. After the transaction commits, the manager payload is silently fetched with `cache: 'no-store'` and reconciled in place.

The UI does not call `window.location.reload()`, `location.reload()`, or `router.refresh()`. The active tab, modal state, and selected asset remain intact. Out-of-order responses are ignored with a request sequence guard.

## Authentication requirement

The browser must have a normal Supabase Auth session. Configure:

```env
NEXT_PUBLIC_SUPABASE_URL=...
NEXT_PUBLIC_SUPABASE_ANON_KEY=...
```

Never expose `SUPABASE_SERVICE_ROLE_KEY` to the browser. Postgres Changes are delivered only for rows the authenticated user may select under RLS.

## Apply

```bash
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 \
  -f src/db/014_realtime_collaboration.sql
```

## Verify

Open the same spread in two authenticated browsers. Complete a review, approve a version, edit a task, add or resolve a comment, and lock/unlock the spread in one browser. The second browser should update without navigation or a page refresh.

Static verification:

```bash
./tests/realtime-no-page-refresh.sh
```
