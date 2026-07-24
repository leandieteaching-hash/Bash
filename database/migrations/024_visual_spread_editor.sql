-- PR-011 Visual Spread Editor and Asset Placement
create table if not exists spread_documents (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references organisations(id) on delete cascade,
  spread_id uuid not null unique,
  width_pt numeric(10,2) not null default 1190.55,
  height_pt numeric(10,2) not null default 841.89,
  bleed_pt numeric(10,2) not null default 8.50,
  grid_size_pt numeric(10,2) not null default 12,
  snap_to_grid boolean not null default true,
  version integer not null default 1,
  content jsonb not null default '{"elements":[]}'::jsonb,
  created_by uuid references user_profiles(id),
  updated_by uuid references user_profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists spread_document_revisions (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references organisations(id) on delete cascade,
  document_id uuid not null references spread_documents(id) on delete cascade,
  version integer not null,
  content jsonb not null,
  change_summary text,
  created_by uuid references user_profiles(id),
  created_at timestamptz not null default now(),
  unique(document_id, version)
);

create index if not exists spread_documents_tenant_spread_idx on spread_documents(organisation_id, spread_id);
create index if not exists spread_document_revisions_document_idx on spread_document_revisions(document_id, version desc);

alter table spread_documents enable row level security;
alter table spread_document_revisions enable row level security;

create policy spread_documents_tenant_policy on spread_documents
  using (organisation_id = current_organisation_id())
  with check (organisation_id = current_organisation_id());
create policy spread_document_revisions_tenant_policy on spread_document_revisions
  using (organisation_id = current_organisation_id())
  with check (organisation_id = current_organisation_id());

insert into platform_permissions(code, description) values
 ('spreads.editor.read','Open the visual spread editor'),
 ('spreads.editor.update','Edit spread documents and place assets'),
 ('spreads.editor.history','View spread document revision history')
on conflict (code) do update set description=excluded.description;

create or replace function save_spread_document(
  p_document_id uuid,
  p_organisation_id uuid,
  p_user_id uuid,
  p_expected_version integer,
  p_content jsonb,
  p_change_summary text default null
) returns table(document_id uuid, version integer)
language plpgsql security definer set search_path=public as $$
declare v_current spread_documents%rowtype; v_next integer;
begin
  select * into v_current from spread_documents
  where id=p_document_id and organisation_id=p_organisation_id for update;
  if not found then raise exception 'DOCUMENT_NOT_FOUND'; end if;
  if v_current.version <> p_expected_version then raise exception 'VERSION_CONFLICT'; end if;
  v_next := v_current.version + 1;
  insert into spread_document_revisions(organisation_id,document_id,version,content,change_summary,created_by)
  values(p_organisation_id,p_document_id,v_current.version,v_current.content,p_change_summary,p_user_id);
  update spread_documents set content=p_content,version=v_next,updated_by=p_user_id,updated_at=now() where id=p_document_id;
  return query select p_document_id,v_next;
end $$;
