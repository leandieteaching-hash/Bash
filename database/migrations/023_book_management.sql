begin;

create table if not exists public.books (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  code text not null,
  title text not null,
  subtitle text,
  description text,
  status text not null default 'draft' check (status in ('draft','active','on_hold','completed','archived')),
  lifecycle_stage text not null default 'planning' check (lifecycle_stage in ('planning','writing','editing','design','review','production','published')),
  default_language text not null default 'en-ZA',
  target_market text,
  owner_id uuid references auth.users(id),
  cover_asset_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  version integer not null default 1,
  created_by uuid references auth.users(id),
  updated_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  unique (organisation_id, code)
);

create table if not exists public.book_editions (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  book_id uuid not null references public.books(id) on delete cascade,
  edition_number integer not null check (edition_number > 0),
  name text not null,
  isbn_10 text,
  isbn_13 text,
  publication_date date,
  format text not null default 'print' check (format in ('print','ebook','audio','digital','bundle')),
  trim_width_mm numeric(8,2),
  trim_height_mm numeric(8,2),
  status text not null default 'draft' check (status in ('draft','in_production','approved','published','retired')),
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (book_id, edition_number)
);

create table if not exists public.book_sections (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  book_id uuid not null references public.books(id) on delete cascade,
  parent_section_id uuid references public.book_sections(id) on delete cascade,
  section_type text not null default 'chapter' check (section_type in ('part','chapter','unit','lesson','appendix','front_matter','back_matter')),
  title text not null,
  slug text not null,
  sequence integer not null,
  status text not null default 'planned' check (status in ('planned','in_progress','review','approved','published')),
  word_count_target integer,
  notes text,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id),
  updated_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (book_id, slug),
  unique (book_id, parent_section_id, sequence)
);

create table if not exists public.book_contributors (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  book_id uuid not null references public.books(id) on delete cascade,
  user_id uuid references auth.users(id),
  display_name text not null,
  contribution_role text not null,
  credit_order integer not null default 0,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.book_milestones (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  book_id uuid not null references public.books(id) on delete cascade,
  name text not null,
  due_date date,
  status text not null default 'planned' check (status in ('planned','active','completed','missed','cancelled')),
  completed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_books_org_status on public.books(organisation_id,status,updated_at desc);
create index if not exists idx_book_editions_book on public.book_editions(book_id,edition_number);
create index if not exists idx_book_sections_book_sequence on public.book_sections(book_id,parent_section_id,sequence);
create index if not exists idx_book_contributors_book on public.book_contributors(book_id,credit_order);
create index if not exists idx_book_milestones_book_due on public.book_milestones(book_id,due_date);

alter table public.books enable row level security;
alter table public.book_editions enable row level security;
alter table public.book_sections enable row level security;
alter table public.book_contributors enable row level security;
alter table public.book_milestones enable row level security;

create policy books_tenant_read on public.books for select using (organisation_id=public.current_organisation_id() and public.authorize_permission('books.read',organisation_id));
create policy books_tenant_manage on public.books for all using (organisation_id=public.current_organisation_id() and public.authorize_permission('books.update',organisation_id)) with check (organisation_id=public.current_organisation_id() and public.authorize_permission('books.update',organisation_id));
create policy book_editions_tenant on public.book_editions for all using (organisation_id=public.current_organisation_id() and public.authorize_permission('books.read',organisation_id)) with check (organisation_id=public.current_organisation_id() and public.authorize_permission('books.update',organisation_id));
create policy book_sections_tenant on public.book_sections for all using (organisation_id=public.current_organisation_id() and public.authorize_permission('books.read',organisation_id)) with check (organisation_id=public.current_organisation_id() and public.authorize_permission('books.update',organisation_id));
create policy book_contributors_tenant on public.book_contributors for all using (organisation_id=public.current_organisation_id() and public.authorize_permission('books.read',organisation_id)) with check (organisation_id=public.current_organisation_id() and public.authorize_permission('books.update',organisation_id));
create policy book_milestones_tenant on public.book_milestones for all using (organisation_id=public.current_organisation_id() and public.authorize_permission('books.read',organisation_id)) with check (organisation_id=public.current_organisation_id() and public.authorize_permission('books.update',organisation_id));

create or replace function public.create_book_with_first_edition(
  p_organisation_id uuid,
  p_user_id uuid,
  p_code text,
  p_title text,
  p_subtitle text default null,
  p_description text default null,
  p_language text default 'en-ZA'
) returns uuid language plpgsql security definer set search_path=public as $$
declare new_book_id uuid;
begin
  if p_organisation_id <> public.current_organisation_id() or not public.authorize_permission('books.create',p_organisation_id) then raise exception 'forbidden'; end if;
  insert into public.books(organisation_id,code,title,subtitle,description,default_language,owner_id,created_by,updated_by)
  values(p_organisation_id,p_code,p_title,p_subtitle,p_description,p_language,p_user_id,p_user_id,p_user_id)
  returning id into new_book_id;
  insert into public.book_editions(organisation_id,book_id,edition_number,name,created_by)
  values(p_organisation_id,new_book_id,1,'First edition',p_user_id);
  return new_book_id;
end $$;

insert into public.platform_permissions(code,description) values
 ('books.read','View books and their structures'),
 ('books.create','Create books and initial editions'),
 ('books.update','Update books, editions and sections'),
 ('books.archive','Archive and restore books'),
 ('books.contributors.manage','Manage book contributors'),
 ('books.milestones.manage','Manage book milestones')
on conflict(code) do update set description=excluded.description;

commit;
