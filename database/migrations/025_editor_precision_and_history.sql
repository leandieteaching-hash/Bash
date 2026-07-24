-- PR-012 Editor precision tools and history
alter table spread_documents
  add column if not exists zoom_percent integer not null default 100 check (zoom_percent between 25 and 400),
  add column if not exists show_rulers boolean not null default true,
  add column if not exists show_guides boolean not null default true,
  add column if not exists margin_pt numeric(10,2) not null default 24;

insert into platform_permissions(code, description) values
 ('spreads.editor.history.restore','Restore a prior spread document revision')
on conflict (code) do update set description=excluded.description;

create or replace function restore_spread_document_revision(
  p_document_id uuid,
  p_revision_id uuid,
  p_organisation_id uuid,
  p_user_id uuid,
  p_expected_version integer
) returns table(document_id uuid, version integer)
language plpgsql security definer set search_path=public as $$
declare v_current spread_documents%rowtype; v_revision spread_document_revisions%rowtype; v_next integer;
begin
  select * into v_current from spread_documents
  where id=p_document_id and organisation_id=p_organisation_id for update;
  if not found then raise exception 'DOCUMENT_NOT_FOUND'; end if;
  if v_current.version <> p_expected_version then raise exception 'VERSION_CONFLICT'; end if;
  select * into v_revision from spread_document_revisions
  where id=p_revision_id and document_id=p_document_id and organisation_id=p_organisation_id;
  if not found then raise exception 'REVISION_NOT_FOUND'; end if;
  v_next := v_current.version + 1;
  insert into spread_document_revisions(organisation_id,document_id,version,content,change_summary,created_by)
  values(p_organisation_id,p_document_id,v_current.version,v_current.content,'Snapshot before revision restore',p_user_id);
  update spread_documents set content=v_revision.content,version=v_next,updated_by=p_user_id,updated_at=now()
  where id=p_document_id;
  return query select p_document_id,v_next;
end $$;
