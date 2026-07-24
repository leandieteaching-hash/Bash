begin;

alter table public.platform_sessions
  add column if not exists access_token_hash text,
  add column if not exists rotated_from_session_id uuid references public.platform_sessions(id) on delete set null,
  add column if not exists rotation_counter integer not null default 0,
  add column if not exists absolute_expires_at timestamptz,
  add column if not exists updated_at timestamptz not null default now();

create table if not exists public.platform_login_attempts (
  id bigint generated always as identity primary key,
  email_hash text not null,
  ip_address inet,
  succeeded boolean not null,
  failure_code text,
  attempted_at timestamptz not null default now()
);

create index if not exists idx_login_attempts_email_time
  on public.platform_login_attempts(email_hash, attempted_at desc);
create index if not exists idx_login_attempts_ip_time
  on public.platform_login_attempts(ip_address, attempted_at desc);
create index if not exists idx_sessions_refresh_hash_active
  on public.platform_sessions(refresh_token_hash)
  where revoked_at is null;

create or replace function public.revoke_platform_session(
  target_session_id uuid,
  reason text default 'user_requested'
) returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.platform_sessions
  set revoked_at = coalesce(revoked_at, now()),
      revoke_reason = coalesce(revoke_reason, reason),
      updated_at = now()
  where id = target_session_id
    and user_id = public.request_user_id();
  return found;
end;
$$;

create or replace function public.revoke_all_platform_sessions(
  reason text default 'security_event',
  except_session_id uuid default null
) returns integer
language plpgsql
security definer
set search_path = public
as $$
declare affected integer;
begin
  update public.platform_sessions
  set revoked_at = now(), revoke_reason = reason, updated_at = now()
  where user_id = public.request_user_id()
    and revoked_at is null
    and (except_session_id is null or id <> except_session_id);
  get diagnostics affected = row_count;
  return affected;
end;
$$;

alter table public.platform_login_attempts enable row level security;

insert into public.platform_permissions(code, description) values
  ('identity.password.reset','Request and complete password resets'),
  ('identity.email.verify','Verify an email address'),
  ('identity.session.rotate','Rotate a refresh token'),
  ('identity.session.revoke_all','Revoke every active session')
on conflict(code) do update set description = excluded.description;

commit;
