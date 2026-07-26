create table if not exists public.customer_onboarding_runs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  source_system text not null,
  status text not null check (status in ('planned','validating','importing','verifying','completed','failed','rolled_back')),
  idempotency_key text not null,
  requested_by uuid,
  totals jsonb not null default '{}'::jsonb,
  errors jsonb not null default '[]'::jsonb,
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (organization_id, idempotency_key)
);

alter table public.customer_onboarding_runs enable row level security;
create policy customer_onboarding_runs_tenant_isolation on public.customer_onboarding_runs
  using (organization_id = nullif(current_setting('app.organization_id', true), '')::uuid)
  with check (organization_id = nullif(current_setting('app.organization_id', true), '')::uuid);
