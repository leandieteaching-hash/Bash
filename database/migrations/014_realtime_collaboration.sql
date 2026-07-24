-- Studio OS · Spread Manager realtime collaboration
-- Apply after 013_rpc_mutation_boundary.sql.
-- Postgres Changes are emitted only after commit, preserving transactional UI state.

begin;

-- UPDATE/DELETE payloads need complete old rows for reliable client reconciliation.
alter table public.spreads replica identity full;
alter table public.assets replica identity full;
alter table public.asset_versions replica identity full;
alter table public.review_requests replica identity full;
alter table public.reviews replica identity full;
alter table public.review_comments replica identity full;
alter table public.approvals replica identity full;
alter table public.tasks replica identity full;
alter table public.decisions replica identity full;
alter table public.character_appearances replica identity full;

-- Idempotently add workflow tables to Supabase Realtime publication.
do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'spreads', 'assets', 'asset_versions', 'review_requests', 'reviews',
    'review_comments', 'approvals', 'tasks', 'decisions', 'character_appearances'
  ] loop
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = table_name
    ) then
      execute format('alter publication supabase_realtime add table public.%I', table_name);
    end if;
  end loop;
end $$;

commit;
