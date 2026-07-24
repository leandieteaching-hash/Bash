-- PR-013 Review, comments and annotations
create table if not exists review_cycles (
 id uuid primary key default gen_random_uuid(), organisation_id uuid not null references organisations(id), spread_id uuid not null,
 title text not null, round_number integer not null default 1 check(round_number>0), status text not null default 'open' check(status in ('open','in_review','completed','cancelled')),
 due_at timestamptz, created_by uuid, completed_by uuid, completed_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists review_assignments (
 id uuid primary key default gen_random_uuid(), organisation_id uuid not null references organisations(id), review_cycle_id uuid not null references review_cycles(id) on delete cascade,
 reviewer_id uuid not null, status text not null default 'assigned' check(status in ('assigned','in_progress','completed','declined')), assigned_by uuid, assigned_at timestamptz not null default now(), completed_at timestamptz,
 unique(review_cycle_id, reviewer_id)
);
create table if not exists spread_annotations (
 id uuid primary key default gen_random_uuid(), organisation_id uuid not null references organisations(id), spread_id uuid not null, review_cycle_id uuid references review_cycles(id) on delete cascade,
 element_id text, annotation_type text not null default 'pin' check(annotation_type in ('pin','region','highlight','drawing')),
 x numeric(10,2), y numeric(10,2), width numeric(10,2), height numeric(10,2), geometry jsonb not null default '{}'::jsonb,
 status text not null default 'open' check(status in ('open','in_discussion','resolved','verified','closed')), created_by uuid, resolved_by uuid, resolved_at timestamptz,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists review_comments (
 id uuid primary key default gen_random_uuid(), organisation_id uuid not null references organisations(id), annotation_id uuid not null references spread_annotations(id) on delete cascade,
 parent_comment_id uuid references review_comments(id) on delete cascade, body text not null check(length(trim(body))>0), mentions uuid[] not null default '{}',
 created_by uuid, edited_at timestamptz, deleted_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists review_comment_history (
 id uuid primary key default gen_random_uuid(), organisation_id uuid not null references organisations(id), comment_id uuid not null references review_comments(id) on delete cascade,
 body text not null, edited_by uuid, created_at timestamptz not null default now()
);
create index if not exists review_cycles_tenant_spread_idx on review_cycles(organisation_id,spread_id,status);
create index if not exists annotations_tenant_spread_idx on spread_annotations(organisation_id,spread_id,status);
create index if not exists comments_annotation_idx on review_comments(annotation_id,created_at);

alter table review_cycles enable row level security; alter table review_assignments enable row level security; alter table spread_annotations enable row level security; alter table review_comments enable row level security; alter table review_comment_history enable row level security;
create policy review_cycles_tenant on review_cycles using (organisation_id=current_organisation_id()) with check (organisation_id=current_organisation_id());
create policy review_assignments_tenant on review_assignments using (organisation_id=current_organisation_id()) with check (organisation_id=current_organisation_id());
create policy annotations_tenant on spread_annotations using (organisation_id=current_organisation_id()) with check (organisation_id=current_organisation_id());
create policy review_comments_tenant on review_comments using (organisation_id=current_organisation_id()) with check (organisation_id=current_organisation_id());
create policy review_comment_history_tenant on review_comment_history using (organisation_id=current_organisation_id()) with check (organisation_id=current_organisation_id());

insert into platform_permissions(code,description) values
 ('reviews.read','Read review cycles, annotations and comments'),('reviews.create','Create review cycles'),('reviews.assign','Assign reviewers'),
 ('reviews.comment','Create and reply to review comments'),('reviews.resolve','Resolve and reopen annotations'),('reviews.complete','Complete review cycles'),
 ('annotations.create','Create spread annotations'),('annotations.delete','Delete spread annotations')
on conflict(code) do update set description=excluded.description;

create or replace function resolve_spread_annotation(p_annotation_id uuid,p_organisation_id uuid,p_user_id uuid,p_status text)
returns table(annotation_id uuid,status text) language plpgsql security definer set search_path=public as $$
begin
 if p_status not in ('open','in_discussion','resolved','verified','closed') then raise exception 'INVALID_ANNOTATION_STATUS'; end if;
 update spread_annotations set status=p_status,resolved_by=case when p_status in ('resolved','verified','closed') then p_user_id else null end,
 resolved_at=case when p_status in ('resolved','verified','closed') then now() else null end,updated_at=now()
 where id=p_annotation_id and organisation_id=p_organisation_id;
 if not found then raise exception 'ANNOTATION_NOT_FOUND'; end if;
 return query select p_annotation_id,p_status;
end $$;
