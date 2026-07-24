-- Studio OS production operations
create table if not exists public.operational_incidents(
 id uuid primary key default gen_random_uuid(), severity text not null check(severity in('info','warning','critical')), title text not null,
 source text not null, status text not null default 'open' check(status in('open','acknowledged','resolved')),
 details jsonb not null default '{}'::jsonb, acknowledged_by uuid, acknowledged_at timestamptz, resolved_by uuid, resolved_at timestamptz,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table if not exists public.health_check_results(
 id bigint generated always as identity primary key, check_name text not null, state text not null check(state in('healthy','warning','critical','unknown')),
 latency_ms integer, detail jsonb not null default '{}'::jsonb, checked_at timestamptz not null default now());
create table if not exists public.backup_verifications(
 id uuid primary key default gen_random_uuid(), backup_reference text not null, backup_type text not null,
 encrypted boolean not null default true, restore_verified boolean not null default false, checksum text,
 started_at timestamptz not null, completed_at timestamptz, verified_by text, detail jsonb not null default '{}'::jsonb);
create index if not exists operational_incidents_open_idx on public.operational_incidents(status,severity,created_at desc);
create index if not exists health_check_results_recent_idx on public.health_check_results(check_name,checked_at desc);
alter table public.operational_incidents enable row level security;
alter table public.health_check_results enable row level security;
alter table public.backup_verifications enable row level security;
-- Replace app_rls.has_permission with the installed permission helper where required.
create policy operational_incidents_admin_read on public.operational_incidents for select using (app_rls.has_permission('system.health.view'));
create policy health_results_admin_read on public.health_check_results for select using (app_rls.has_permission('system.health.view'));
create policy backup_verifications_admin_read on public.backup_verifications for select using (app_rls.has_permission('system.backup.view'));
