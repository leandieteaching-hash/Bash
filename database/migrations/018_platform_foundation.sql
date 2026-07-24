begin;
create extension if not exists pgcrypto;
create table if not exists public.organisations(
 id uuid primary key default gen_random_uuid(),
 slug text not null unique check(slug ~ '^[a-z0-9-]+$'),
 name text not null,
 region text not null default 'af-south-1',
 plan text not null default 'pilot',
 status text not null default 'active' check(status in ('active','trial','suspended')),
 settings jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table if not exists public.organisation_members(
 organisation_id uuid not null references public.organisations(id) on delete cascade,
 user_id uuid not null,
 status text not null default 'active' check(status in ('active','invited','disabled')),
 joined_at timestamptz not null default now(),
 primary key(organisation_id,user_id)
);
create table if not exists public.platform_roles(
 id uuid primary key default gen_random_uuid(), organisation_id uuid references public.organisations(id) on delete cascade,
 code text not null, name text not null, description text, is_system boolean not null default false,
 unique(organisation_id,code)
);
create table if not exists public.platform_permissions(
 code text primary key, description text not null
);
create table if not exists public.platform_role_permissions(
 role_id uuid not null references public.platform_roles(id) on delete cascade,
 permission_code text not null references public.platform_permissions(code) on delete cascade,
 primary key(role_id,permission_code)
);
create table if not exists public.platform_user_roles(
 organisation_id uuid not null references public.organisations(id) on delete cascade,
 user_id uuid not null, role_id uuid not null references public.platform_roles(id) on delete cascade,
 primary key(organisation_id,user_id,role_id)
);
create table if not exists public.platform_audit_events(
 id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
 request_id text not null, actor_id uuid, action text not null, resource_type text not null, resource_id text,
 metadata jsonb not null default '{}'::jsonb, occurred_at timestamptz not null default now()
);
create table if not exists public.platform_event_outbox(
 id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
 event_type text not null, aggregate_type text, aggregate_id text, payload jsonb not null default '{}'::jsonb,
 status text not null default 'pending' check(status in ('pending','processing','published','failed')),
 attempts integer not null default 0, available_at timestamptz not null default now(), published_at timestamptz,
 created_at timestamptz not null default now()
);
create table if not exists public.platform_api_keys(
 id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
 name text not null, key_prefix text not null, secret_hash text not null, scopes text[] not null default '{}',
 expires_at timestamptz, revoked_at timestamptz, last_used_at timestamptz, created_by uuid, created_at timestamptz not null default now()
);
create index if not exists idx_platform_audit_tenant_time on public.platform_audit_events(organisation_id,occurred_at desc);
create index if not exists idx_platform_outbox_dispatch on public.platform_event_outbox(status,available_at) where status in ('pending','failed');
create index if not exists idx_platform_api_keys_tenant on public.platform_api_keys(organisation_id) where revoked_at is null;
alter table public.organisations enable row level security;
alter table public.organisation_members enable row level security;
alter table public.platform_roles enable row level security;
alter table public.platform_user_roles enable row level security;
alter table public.platform_audit_events enable row level security;
alter table public.platform_event_outbox enable row level security;
alter table public.platform_api_keys enable row level security;
create or replace function public.current_organisation_id() returns uuid language sql stable as $$ select nullif(auth.jwt()->>'organisation_id','')::uuid $$;
create policy organisations_member_read on public.organisations for select using(id=public.current_organisation_id());
create policy organisation_members_tenant on public.organisation_members using(organisation_id=public.current_organisation_id());
create policy platform_roles_tenant on public.platform_roles using(organisation_id is null or organisation_id=public.current_organisation_id());
create policy platform_user_roles_tenant on public.platform_user_roles using(organisation_id=public.current_organisation_id());
create policy platform_audit_tenant_read on public.platform_audit_events for select using(organisation_id=public.current_organisation_id());
create policy platform_event_outbox_tenant_read on public.platform_event_outbox for select using(organisation_id=public.current_organisation_id());
create policy platform_api_keys_tenant on public.platform_api_keys using(organisation_id=public.current_organisation_id());
insert into public.platform_permissions(code,description) values
 ('platform.admin','Manage platform foundation'),('tenant.manage','Manage tenant configuration'),('identity.manage','Manage members and roles'),
 ('audit.read','Read audit events'),('events.publish','Publish platform events'),('health.read','Read system health')
on conflict(code) do update set description=excluded.description;
commit;
