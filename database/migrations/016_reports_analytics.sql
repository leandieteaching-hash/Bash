-- Studio OS Reports & Analytics
create table if not exists public.report_schedules (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id), book_id uuid null, name text not null,
 dashboard text not null check (dashboard in ('production','team','review','workload','executive')),
 cadence text not null check (cadence in ('daily','weekly','monthly')), delivery_time time not null default '08:00', timezone text not null default 'Africa/Johannesburg',
 recipients text[] not null default '{}', format text not null check (format in ('csv','pdf')), filters jsonb not null default '{}', enabled boolean not null default true,
 next_run_at timestamptz, last_run_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.report_runs (id uuid primary key default gen_random_uuid(),schedule_id uuid references public.report_schedules(id) on delete set null,requested_by uuid references auth.users(id),dashboard text not null,format text not null,status text not null default 'queued',filters jsonb not null default '{}',storage_path text,error text,started_at timestamptz,completed_at timestamptz,created_at timestamptz not null default now());
create index if not exists report_schedules_due_idx on public.report_schedules(enabled,next_run_at);create index if not exists report_runs_created_idx on public.report_runs(created_at desc);
alter table public.report_schedules enable row level security;alter table public.report_runs enable row level security;
create policy report_schedules_owner on public.report_schedules for all using(owner_id=auth.uid()) with check(owner_id=auth.uid());
create policy report_runs_requester on public.report_runs for select using(requested_by=auth.uid());
create or replace view public.report_production_progress as select s.book_id,count(*) as spread_count,count(*) filter(where s.status='complete') as complete_count,round(100.0*count(*) filter(where s.status='complete')/nullif(count(*),0),1) as completion_pct from public.spreads s group by s.book_id;
create or replace view public.report_review_turnaround as select r.book_id,count(*) as reviews_completed,percentile_cont(.5) within group(order by extract(epoch from (r.completed_at-r.created_at))/3600) as median_hours from public.reviews r where r.completed_at is not null group by r.book_id;
create or replace view public.report_task_completion as select t.book_id,t.assignee_id,count(*) as task_count,count(*) filter(where t.status='complete') as completed_count,count(*) filter(where t.due_at<now() and t.status<>'complete') as overdue_count from public.tasks t group by t.book_id,t.assignee_id;
