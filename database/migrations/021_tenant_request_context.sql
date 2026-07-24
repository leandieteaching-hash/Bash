-- PR-004: authenticated tenant request context and isolation hardening.
create or replace function public.set_request_context(
  p_organisation_id uuid,
  p_user_id uuid,
  p_request_id uuid default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null and auth.uid() <> p_user_id then
    raise exception 'REQUEST_USER_MISMATCH';
  end if;
  if not exists (select 1 from public.organisation_members m where m.organisation_id = p_organisation_id and m.user_id = p_user_id and m.status = 'active') then
    raise exception 'TENANT_ACCESS_DENIED';
  end if;
  perform set_config('app.organisation_id', p_organisation_id::text, true);
  perform set_config('app.user_id', p_user_id::text, true);
  perform set_config('app.request_id', coalesce(p_request_id::text, ''), true);
end;
$$;

revoke all on function public.set_request_context(uuid, uuid, uuid) from public;
grant execute on function public.set_request_context(uuid, uuid, uuid) to authenticated, service_role;

create or replace function public.current_organisation_id() returns uuid
language sql stable
as $$
  select nullif(current_setting('app.organisation_id', true), '')::uuid
$$;

create or replace function public.current_request_user_id() returns uuid
language sql stable
as $$
  select coalesce(nullif(current_setting('app.user_id', true), '')::uuid, auth.uid())
$$;

create or replace function public.switch_active_organisation(p_session_id uuid, p_organisation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare v_user_id uuid;
begin
  select user_id into v_user_id from public.platform_sessions
  where id = p_session_id and revoked_at is null and expires_at > now();
  if v_user_id is null then raise exception 'SESSION_NOT_ACTIVE'; end if;
  if auth.uid() is not null and auth.uid() <> v_user_id then raise exception 'SESSION_USER_MISMATCH'; end if;
  if not exists (select 1 from public.organisation_members m where m.organisation_id = p_organisation_id and m.user_id = v_user_id and m.status = 'active') then raise exception 'TENANT_ACCESS_DENIED'; end if;
  update public.platform_sessions set organisation_id = p_organisation_id, last_seen_at = now() where id = p_session_id;
end;
$$;

revoke all on function public.switch_active_organisation(uuid, uuid) from public;
grant execute on function public.switch_active_organisation(uuid, uuid) to authenticated, service_role;


create or replace function public.get_tenant_settings(
  p_organisation_id uuid,
  p_user_id uuid,
  p_request_id uuid default null
) returns table(id uuid, slug text, name text, locale text, timezone text, settings jsonb)
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.set_request_context(p_organisation_id, p_user_id, p_request_id);
  return query select o.id, o.slug, o.name, o.locale, o.timezone, o.settings
    from public.organisations o where o.id = public.current_organisation_id();
end;
$$;
revoke all on function public.get_tenant_settings(uuid, uuid, uuid) from public;
grant execute on function public.get_tenant_settings(uuid, uuid, uuid) to authenticated, service_role;

-- Ensure tenant-owned platform records cannot cross organisation boundaries.
alter table public.platform_audit_events enable row level security;
alter table public.platform_event_outbox enable row level security;

drop policy if exists platform_audit_tenant_select on public.platform_audit_events;
create policy platform_audit_tenant_select on public.platform_audit_events
for select using (
  organisation_id = public.current_organisation_id()
  and public.is_organisation_member(organisation_id)
);

drop policy if exists platform_outbox_tenant_select on public.platform_event_outbox;
create policy platform_outbox_tenant_select on public.platform_event_outbox
for select using (
  organisation_id = public.current_organisation_id()
  and public.is_organisation_member(organisation_id)
);

create index if not exists organisation_members_user_active_idx
  on public.organisation_members(user_id, organisation_id) where status = 'active';
create index if not exists platform_sessions_user_org_active_idx
  on public.platform_sessions(user_id, organisation_id) where revoked_at is null;
