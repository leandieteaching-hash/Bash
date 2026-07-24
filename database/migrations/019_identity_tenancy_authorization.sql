begin;

create extension if not exists pgcrypto;

create table if not exists public.platform_user_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  locale text not null default 'en-ZA',
  timezone text not null default 'Africa/Johannesburg',
  status text not null default 'active' check (status in ('active','locked','disabled')),
  last_login_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.platform_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  organisation_id uuid references public.organisations(id) on delete cascade,
  refresh_token_hash text not null unique,
  device_name text,
  ip_address inet,
  user_agent text,
  remember_me boolean not null default false,
  expires_at timestamptz not null,
  last_seen_at timestamptz not null default now(),
  revoked_at timestamptz,
  revoke_reason text,
  created_at timestamptz not null default now(),
  check (expires_at > created_at)
);

create table if not exists public.platform_email_verification_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token_hash text not null unique,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.platform_password_reset_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token_hash text not null unique,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  requested_ip inet,
  created_at timestamptz not null default now()
);

alter table public.organisation_members
  add column if not exists is_default boolean not null default false,
  add column if not exists invited_by uuid,
  add column if not exists updated_at timestamptz not null default now();

alter table public.platform_roles
  add column if not exists parent_role_id uuid references public.platform_roles(id) on delete set null,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

create unique index if not exists idx_default_organisation_per_user
  on public.organisation_members(user_id) where is_default and status = 'active';
create index if not exists idx_membership_user_active
  on public.organisation_members(user_id, organisation_id) where status = 'active';
create index if not exists idx_sessions_user_active
  on public.platform_sessions(user_id, expires_at desc) where revoked_at is null;
create index if not exists idx_email_verification_expiry
  on public.platform_email_verification_tokens(expires_at) where consumed_at is null;
create index if not exists idx_password_reset_expiry
  on public.platform_password_reset_tokens(expires_at) where consumed_at is null;

create or replace function public.request_user_id()
returns uuid language sql stable as $$
  select coalesce(
    auth.uid(),
    nullif(current_setting('app.user_id', true), '')::uuid
  )
$$;

create or replace function public.current_organisation_id()
returns uuid language sql stable as $$
  select coalesce(
    nullif(auth.jwt()->>'organisation_id','')::uuid,
    nullif(current_setting('app.organisation_id', true), '')::uuid
  )
$$;

create or replace function public.is_organisation_member(target_organisation_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.organisation_members member
    where member.organisation_id = target_organisation_id
      and member.user_id = public.request_user_id()
      and member.status = 'active'
  )
$$;

create or replace function public.has_permission(permission text, target_organisation_id uuid default public.current_organisation_id())
returns boolean language sql stable security definer set search_path = public as $$
  with recursive assigned_roles as (
    select role.id, role.parent_role_id
    from public.platform_user_roles assignment
    join public.platform_roles role on role.id = assignment.role_id
    where assignment.user_id = public.request_user_id()
      and assignment.organisation_id = target_organisation_id
    union
    select parent.id, parent.parent_role_id
    from public.platform_roles parent
    join assigned_roles child on child.parent_role_id = parent.id
  )
  select exists (
    select 1 from assigned_roles role
    join public.platform_role_permissions grant_row on grant_row.role_id = role.id
    where grant_row.permission_code = permission
  )
$$;

alter table public.platform_user_profiles enable row level security;
alter table public.platform_sessions enable row level security;
alter table public.platform_email_verification_tokens enable row level security;
alter table public.platform_password_reset_tokens enable row level security;

create policy platform_profiles_self_read on public.platform_user_profiles
  for select using (user_id = public.request_user_id());
create policy platform_profiles_self_update on public.platform_user_profiles
  for update using (user_id = public.request_user_id())
  with check (user_id = public.request_user_id());
create policy platform_sessions_self_read on public.platform_sessions
  for select using (user_id = public.request_user_id());
create policy platform_sessions_self_revoke on public.platform_sessions
  for update using (user_id = public.request_user_id())
  with check (user_id = public.request_user_id());
create policy organisation_members_member_read on public.organisation_members
  for select using (
    user_id = public.request_user_id()
    or (organisation_id = public.current_organisation_id() and public.has_permission('identity.manage', organisation_id))
  );
create policy platform_user_roles_member_read on public.platform_user_roles
  for select using (
    user_id = public.request_user_id()
    or (organisation_id = public.current_organisation_id() and public.has_permission('identity.manage', organisation_id))
  );

insert into public.platform_permissions(code, description) values
  ('identity.profile.read','Read the current user profile'),
  ('identity.session.read','Read the current user sessions'),
  ('identity.session.revoke','Revoke user sessions'),
  ('identity.members.read','Read organisation members'),
  ('identity.members.manage','Invite, disable and update organisation members'),
  ('identity.roles.read','Read roles and permission assignments'),
  ('identity.roles.manage','Manage roles and permission assignments'),
  ('tenant.read','Read organisation settings'),
  ('tenant.switch','Switch active organisation'),
  ('tenant.provision','Provision organisations')
on conflict(code) do update set description = excluded.description;

commit;
