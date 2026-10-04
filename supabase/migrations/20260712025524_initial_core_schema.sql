-- =========================================================
-- Initial core schema
-- =========================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------
-- Profiles
-- One application profile for every Supabase Auth user.
-- ---------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  full_name text,
  avatar_url text,
  graduation_year smallint,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint profiles_email_lowercase
    check (email = lower(email)),

  constraint profiles_graduation_year_valid
    check (
      graduation_year is null
      or graduation_year between 2020 and 2100
    )
);

-- ---------------------------------------------------------
-- System roles
-- School-wide roles only. Club roles will be stored later
-- in club_memberships.
-- ---------------------------------------------------------

create table public.system_roles (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text,
  created_at timestamptz not null default now(),

  constraint system_roles_code_uppercase
    check (code = upper(code))
);

-- ---------------------------------------------------------
-- User system roles
-- Connects users to school-wide roles.
-- ---------------------------------------------------------

create table public.user_system_roles (
  user_id uuid not null
    references public.profiles(id)
    on delete cascade,

  role_id uuid not null
    references public.system_roles(id)
    on delete cascade,

  assigned_by uuid
    references public.profiles(id)
    on delete set null,

  assigned_at timestamptz not null default now(),
  expires_at timestamptz,

  primary key (user_id, role_id),

  constraint user_system_roles_expiry_valid
    check (
      expires_at is null
      or expires_at > assigned_at
    )
);

create index user_system_roles_user_id_idx
  on public.user_system_roles(user_id);

create index user_system_roles_role_id_idx
  on public.user_system_roles(role_id);

-- ---------------------------------------------------------
-- Required system roles
-- These belong in the migration because both development
-- and production need them.
-- ---------------------------------------------------------

insert into public.system_roles (code, name, description)
values
  (
    'SAC_EXEC',
    'SAC Executive',
    'Can manage SAC events and SAC-created content'
  ),
  (
    'SAC_ADMIN',
    'SAC Administrator',
    'Can review club applications and moderate content'
  ),
  (
    'FACULTY_ADVISOR',
    'Faculty Advisor',
    'School staff member who advises clubs'
  ),
  (
    'SITE_ADMIN',
    'Site Administrator',
    'Full technical administration access'
  )
on conflict (code) do nothing;

-- ---------------------------------------------------------
-- Automatically create a profile after Google sign-in.
-- ---------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (
    id,
    email,
    full_name,
    avatar_url
  )
  values (
    new.id,
    lower(new.email),
    coalesce(
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name'
    ),
    coalesce(
      new.raw_user_meta_data ->> 'avatar_url',
      new.raw_user_meta_data ->> 'picture'
    )
  );

  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_user();

-- Backfill profiles if development already has Auth users.

insert into public.profiles (
  id,
  email,
  full_name,
  avatar_url
)
select
  id,
  lower(email),
  coalesce(
    raw_user_meta_data ->> 'full_name',
    raw_user_meta_data ->> 'name'
  ),
  coalesce(
    raw_user_meta_data ->> 'avatar_url',
    raw_user_meta_data ->> 'picture'
  )
from auth.users
where email is not null
on conflict (id) do nothing;

-- ---------------------------------------------------------
-- Keep updated_at current.
-- ---------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger set_profiles_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();

-- ---------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.system_roles enable row level security;
alter table public.user_system_roles enable row level security;

-- Users may initially see only their own profile.
-- We will later add a safe student-search function.

create policy "Users can read their own profile"
on public.profiles
for select
to authenticated
using (id = auth.uid());

-- All signed-in users may see role definitions.

create policy "Authenticated users can read system roles"
on public.system_roles
for select
to authenticated
using (true);

-- Users may see only their own role assignments.

create policy "Users can read their own system roles"
on public.user_system_roles
for select
to authenticated
using (user_id = auth.uid());