begin;

alter table public.platform_roles
  add column if not exists status text not null default 'active' check(status in ('active','disabled')),
  add column if not exists version integer not null default 1;

create unique index if not exists idx_platform_roles_tenant_code
  on public.platform_roles(coalesce(organisation_id,'00000000-0000-0000-0000-000000000000'::uuid),code);
create index if not exists idx_platform_role_permissions_permission on public.platform_role_permissions(permission_code,role_id);
create index if not exists idx_platform_user_roles_user_tenant on public.platform_user_roles(user_id,organisation_id);

create or replace function public.effective_permissions(target_user_id uuid, target_organisation_id uuid)
returns table(permission_code text, source_role_code text, inherited boolean)
language sql stable security definer set search_path=public as $$
  with recursive role_tree as (
    select r.id,r.code,r.parent_role_id,false as inherited
    from public.platform_user_roles ur join public.platform_roles r on r.id=ur.role_id
    where ur.user_id=target_user_id and ur.organisation_id=target_organisation_id and r.status='active'
    union
    select parent.id,parent.code,parent.parent_role_id,true
    from public.platform_roles parent join role_tree child on child.parent_role_id=parent.id
    where parent.status='active'
  )
  select distinct rp.permission_code,rt.code,rt.inherited
  from role_tree rt join public.platform_role_permissions rp on rp.role_id=rt.id
$$;

create or replace function public.authorize_permission(permission text,target_organisation_id uuid default public.current_organisation_id())
returns boolean language sql stable security definer set search_path=public as $$
  select public.is_organisation_member(target_organisation_id) and exists(
    select 1 from public.effective_permissions(public.request_user_id(),target_organisation_id) ep
    where ep.permission_code=permission or ep.permission_code='platform.admin'
  )
$$;

create or replace function public.replace_role_permissions(target_role_id uuid, permission_codes text[])
returns void language plpgsql security definer set search_path=public as $$
declare role_org uuid;
begin
  select organisation_id into role_org from public.platform_roles where id=target_role_id for update;
  if role_org is null or not public.authorize_permission('identity.roles.manage',role_org) then raise exception 'forbidden'; end if;
  delete from public.platform_role_permissions where role_id=target_role_id;
  insert into public.platform_role_permissions(role_id,permission_code)
    select target_role_id,code from public.platform_permissions where code=any(permission_codes);
  update public.platform_roles set version=version+1,updated_at=now() where id=target_role_id;
end $$;

alter table public.platform_role_permissions enable row level security;
drop policy if exists platform_roles_tenant on public.platform_roles;
create policy platform_roles_tenant_read on public.platform_roles for select using(organisation_id is null or organisation_id=public.current_organisation_id());
create policy platform_roles_tenant_manage on public.platform_roles for all using(organisation_id=public.current_organisation_id() and public.authorize_permission('identity.roles.manage',organisation_id)) with check(organisation_id=public.current_organisation_id() and public.authorize_permission('identity.roles.manage',organisation_id));
create policy platform_role_permissions_read on public.platform_role_permissions for select using(exists(select 1 from public.platform_roles r where r.id=role_id and (r.organisation_id is null or r.organisation_id=public.current_organisation_id())));
create policy platform_role_permissions_manage on public.platform_role_permissions for all using(exists(select 1 from public.platform_roles r where r.id=role_id and r.organisation_id=public.current_organisation_id() and public.authorize_permission('identity.roles.manage',r.organisation_id))) with check(exists(select 1 from public.platform_roles r where r.id=role_id and r.organisation_id=public.current_organisation_id() and public.authorize_permission('identity.roles.manage',r.organisation_id)));

insert into public.platform_permissions(code,description) values
 ('identity.permission_matrix.read','Read the role permission matrix'),
 ('identity.role.assign','Assign roles to organisation members'),
 ('identity.role.create','Create organisation roles'),
 ('identity.role.update','Update organisation roles')
on conflict(code) do update set description=excluded.description;
commit;
