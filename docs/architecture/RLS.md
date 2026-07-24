# Spread Manager Row Level Security

Apply `src/db/011_row_level_security.sql` after migrations 001–010.

## Security model

The original schema has global roles and permissions, not publication memberships. Policies therefore use global RBAC and add row ownership for assigned reviewers, task assignees, task creators, decision owners, and comment authors.

`public.users.auth_user_id` links a Studio profile to `auth.users.id`. The migration attempts a one-time email backfill. New accounts must populate this field when provisioning the Studio profile.

## Critical API requirement

`SUPABASE_SERVICE_ROLE_KEY` bypasses RLS. Normal request handlers must use the authenticated user's access token and the anon key. Reserve the service-role client for tightly controlled administration or `SECURITY DEFINER` workflow functions.

```ts
createClient(url, anonKey, {
  global: { headers: { Authorization: `Bearer ${accessToken}` } },
  auth: { persistSession: false, autoRefreshToken: false },
});
```

The existing `adminDb()` scaffold still bypasses RLS and must not remain the default request client in production.

## Policy summary

- Spreads: authenticated RBAC read; edit/lock permissions for updates.
- Assets and versions: spread-visible reads; upload/approve permissions for writes.
- Review requests: reviewer, requester, or spread-visible access.
- Reviews/comments: request-derived visibility; author/reviewer ownership plus review permissions.
- Approvals: asset-visible reads; asset approvers may create or revoke; hard delete blocked.
- Tasks: assignee/creator/spread visibility; task editors manage; assignees can update their tasks.
- Decisions: owner/spread visibility; decision creators and approvers manage lifecycle.
- Character appearances: spread-visible reads; character editors manage links.

## Verification

Run `src/db/011_rls_verification.sql` in a non-production database. Replace the UUID placeholders with real `auth.users` and `public.users` identifiers, or set JWT claims in a Supabase test session.
