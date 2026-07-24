-- Run after 011_row_level_security.sql in a test database.

-- 1. Confirm RLS and FORCE RLS are enabled.
SELECT c.relname AS table_name, c.relrowsecurity AS rls_enabled, c.relforcerowsecurity AS force_rls
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN (
    'spreads','assets','asset_versions','review_requests','reviews','review_comments',
    'approvals','tasks','decisions','character_appearances'
  )
ORDER BY c.relname;

-- 2. Review installed policies.
SELECT schemaname, tablename, policyname, roles, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
    'spreads','assets','asset_versions','review_requests','reviews','review_comments',
    'approvals','tasks','decisions','character_appearances'
  )
ORDER BY tablename, policyname;

-- 3. Confirm every active auth-linked Studio user resolves to a profile.
SELECT u.id, u.email, u.auth_user_id, u.is_active
FROM public.users u
WHERE u.is_active = true
ORDER BY u.email;

-- 4. Confirm permission assignments. Missing rows mean the role cannot perform that action.
SELECT r.name AS role_name, p.code AS permission_code
FROM public.roles r
JOIN public.role_permissions rp ON rp.role_id = r.id
JOIN public.permissions p ON p.id = rp.permission_id
WHERE p.code IN (
  'spread.view','spread.edit_text','spread.lock','asset.view','asset.upload','asset.approve',
  'review.view','review.request','review.complete','review.resolve_comment',
  'task.view','task.edit','decision.view','decision.create','decision.approve',
  'character.view','character.edit'
)
ORDER BY r.name, p.code;
