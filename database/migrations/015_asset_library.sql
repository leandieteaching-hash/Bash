-- Studio OS Asset Library / DAM
begin;

create table if not exists public.tags (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  normalized_name text generated always as (lower(trim(name))) stored,
  created_at timestamptz not null default now(),
  unique(normalized_name)
);

create table if not exists public.asset_tags (
  asset_id uuid not null references public.assets(id) on delete cascade,
  tag_id uuid not null references public.tags(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(asset_id,tag_id)
);

create table if not exists public.asset_collections (
  id uuid primary key default gen_random_uuid(),
  publication_id uuid not null references public.publications(id) on delete cascade,
  name text not null,
  description text,
  created_by uuid references public.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(publication_id,name)
);

create table if not exists public.asset_collection_items (
  collection_id uuid not null references public.asset_collections(id) on delete cascade,
  asset_id uuid not null references public.assets(id) on delete cascade,
  added_by uuid references public.users(id),
  added_at timestamptz not null default now(),
  primary key(collection_id,asset_id)
);

create table if not exists public.asset_relationships (
  id uuid primary key default gen_random_uuid(),
  source_asset_id uuid not null references public.assets(id) on delete cascade,
  target_asset_id uuid not null references public.assets(id) on delete cascade,
  relationship_type text not null check (relationship_type in ('variant_of','derived_from','references','companion_to')),
  created_by uuid references public.users(id),
  created_at timestamptz not null default now(),
  check(source_asset_id<>target_asset_id),
  unique(source_asset_id,target_asset_id,relationship_type)
);

create table if not exists public.asset_usage (
  id uuid primary key default gen_random_uuid(),
  asset_id uuid not null references public.assets(id) on delete cascade,
  asset_version_id uuid references public.asset_versions(id) on delete set null,
  context_type text not null check(context_type in ('spread','character','environment','export')),
  context_id uuid not null,
  usage_role text not null default 'reference',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(asset_id,context_type,context_id,usage_role)
);

alter table public.assets add column if not exists description text;
alter table public.assets add column if not exists asset_type text not null default 'illustration';
alter table public.assets add column if not exists lifecycle_status text not null default 'active';
alter table public.assets add column if not exists archived_at timestamptz;
alter table public.assets add column if not exists scheduled_delete_at timestamptz;
alter table public.assets add constraint assets_lifecycle_status_check check(lifecycle_status in ('active','archived','cold_storage','scheduled_deletion')) not valid;
alter table public.assets validate constraint assets_lifecycle_status_check;

alter table public.asset_versions add column if not exists filename text;
alter table public.asset_versions add column if not exists mime_type text;
alter table public.asset_versions add column if not exists size_bytes bigint;
alter table public.asset_versions add column if not exists width integer;
alter table public.asset_versions add column if not exists height integer;
alter table public.asset_versions add column if not exists checksum text;
alter table public.asset_versions add column if not exists thumbnail_storage_path text;
alter table public.asset_versions add column if not exists technical_metadata jsonb not null default '{}'::jsonb;

create index if not exists asset_tags_tag_idx on public.asset_tags(tag_id,asset_id);
create index if not exists asset_collections_publication_idx on public.asset_collections(publication_id,updated_at desc);
create index if not exists asset_usage_asset_idx on public.asset_usage(asset_id,updated_at desc);
create index if not exists asset_relationships_source_idx on public.asset_relationships(source_asset_id);
create index if not exists assets_publication_lifecycle_idx on public.assets(publication_id,lifecycle_status,updated_at desc);
create index if not exists assets_search_idx on public.assets using gin(to_tsvector('simple',coalesce(title,'')||' '||coalesce(description,'')));

create or replace function public.workflow_finalize_asset_upload(
 p_publication_id uuid,p_spread_id uuid,p_asset_id uuid,p_title text,p_asset_type text,p_storage_path text,p_filename text,p_content_type text,p_size_bytes bigint,p_tags text[],p_actor_profile_id uuid
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_asset_id uuid:=coalesce(p_asset_id,gen_random_uuid());v_version public.asset_versions;v_tag text;v_tag_id uuid;
begin
 if p_asset_id is null then
   if p_spread_id is null then raise exception using errcode='22023',message='SPREAD_REQUIRED_FOR_NEW_ASSET'; end if;
   insert into assets(id,publication_id,spread_id,asset_code,asset_type,title,status,created_by,created_at,updated_at)
   values(v_asset_id,p_publication_id,p_spread_id,'AST-'||upper(substr(replace(v_asset_id::text,'-',''),1,8)),p_asset_type,p_title,'In Progress',p_actor_profile_id,now(),now());
 end if;
 select * into v_version from public.workflow_upload_asset_version(v_asset_id,p_actor_profile_id,p_filename,p_storage_path,p_size_bytes,p_content_type,null,'Uploaded through Asset Library',true);
 foreach v_tag in array coalesce(p_tags,array[]::text[]) loop
   insert into tags(name) values(trim(v_tag)) on conflict(normalized_name) do update set name=excluded.name returning id into v_tag_id;
   insert into asset_tags(asset_id,tag_id) values(v_asset_id,v_tag_id) on conflict do nothing;
 end loop;
 return jsonb_build_object('asset_id',v_asset_id,'version_id',v_version.id,'version',v_version.version_number);
end$$;

create or replace function public.workflow_bulk_update_assets(
 p_asset_ids uuid[],p_operation text,p_tags text[] default array[]::text[],p_collection_id uuid default null,p_lifecycle_status text default null,p_actor_profile_id uuid default null
) returns jsonb language plpgsql security definer set search_path=public as $$
declare v_id uuid;v_tag text;v_tag_id uuid;v_count integer:=0;
begin
 foreach v_id in array p_asset_ids loop
  perform 1 from assets where id=v_id for update;
  if p_operation='archive' then update assets set lifecycle_status='archived',archived_at=now(),updated_at=now() where id=v_id;
  elsif p_operation='restore' then update assets set lifecycle_status='active',archived_at=null,scheduled_delete_at=null,updated_at=now() where id=v_id;
  elsif p_operation='lifecycle' then update assets set lifecycle_status=p_lifecycle_status,updated_at=now() where id=v_id;
  elsif p_operation='add_collection' then insert into asset_collection_items(collection_id,asset_id,added_by) values(p_collection_id,v_id,p_actor_profile_id) on conflict do nothing;
  elsif p_operation='add_tags' then foreach v_tag in array p_tags loop insert into tags(name) values(trim(v_tag)) on conflict(normalized_name) do update set name=excluded.name returning id into v_tag_id;insert into asset_tags values(v_id,v_tag_id,now()) on conflict do nothing;end loop;
  elsif p_operation='remove_tags' then delete from asset_tags at using tags t where at.asset_id=v_id and at.tag_id=t.id and t.normalized_name=any(select lower(unnest(p_tags)));
  else raise exception 'Unsupported asset bulk operation: %',p_operation;
  end if;
  perform log_activity(p_actor_profile_id,'asset.bulk_'||p_operation,'asset',v_id,'{}'::jsonb);v_count:=v_count+1;
 end loop;
 return jsonb_build_object('updated',v_count,'operation',p_operation);
end$$;

create or replace function public.search_assets(p_publication_id uuid,p_query text default null,p_asset_types text[] default array[]::text[],p_review_statuses text[] default array[]::text[],p_tags text[] default array[]::text[],p_collection_id uuid default null,p_lifecycle_status text default null,p_limit integer default 100,p_offset integer default 0)
returns setof jsonb language sql stable security invoker set search_path=public as $$
 select jsonb_build_object('id',a.id,'publication_id',a.publication_id,'title',a.title,'description',a.description,'asset_type',a.asset_type,'lifecycle_status',a.lifecycle_status,'updated_at',a.updated_at,'tags',coalesce(array_agg(distinct t.name) filter(where t.id is not null),array[]::text[]),'usage_count',(select count(*) from asset_usage u where u.asset_id=a.id))
 from assets a left join asset_tags at on at.asset_id=a.id left join tags t on t.id=at.tag_id
 where a.publication_id=p_publication_id and (p_query is null or to_tsvector('simple',coalesce(a.title,'')||' '||coalesce(a.description,''))@@plainto_tsquery('simple',p_query)) and (cardinality(p_asset_types)=0 or a.asset_type=any(p_asset_types)) and (p_lifecycle_status is null or a.lifecycle_status=p_lifecycle_status) and (p_collection_id is null or exists(select 1 from asset_collection_items ci where ci.asset_id=a.id and ci.collection_id=p_collection_id)) and (cardinality(p_tags)=0 or exists(select 1 from asset_tags at2 join tags t2 on t2.id=at2.tag_id where at2.asset_id=a.id and t2.normalized_name=any(select lower(unnest(p_tags)))))
 group by a.id order by a.updated_at desc limit p_limit offset p_offset
$$;

alter table public.tags enable row level security;alter table public.asset_tags enable row level security;alter table public.asset_collections enable row level security;alter table public.asset_collection_items enable row level security;alter table public.asset_relationships enable row level security;alter table public.asset_usage enable row level security;
-- Reuse the application permission helper introduced in migration 011.
create policy tags_read on public.tags for select using (studio_security.has_permission('asset.view'));
create policy asset_tags_read on public.asset_tags for select using (studio_security.has_permission('asset.view'));
create policy collections_book_read on public.asset_collections for select using (studio_security.has_permission('asset.view'));
create policy collection_items_read on public.asset_collection_items for select using (exists(select 1 from assets a where a.id=asset_id and studio_security.can_view_spread(a.spread_id)));
create policy relationships_read on public.asset_relationships for select using (exists(select 1 from assets a where a.id=source_asset_id and studio_security.can_view_spread(a.spread_id)));
create policy usage_read on public.asset_usage for select using (exists(select 1 from assets a where a.id=asset_id and studio_security.can_view_spread(a.spread_id)));

commit;
