-- =========================================================
-- Club annual state, settings, aliases, and profile fields
-- =========================================================

-- ---------------------------------------------------------
-- 1. Maintainable current school-year setting
-- ---------------------------------------------------------

create table if not exists public.app_settings (
  key text primary key,
  value text not null,
  description text,
  updated_at timestamptz not null default now(),
  constraint app_settings_key_not_blank
    check (length(btrim(key)) > 0),
  constraint app_settings_value_not_blank
    check (length(btrim(value)) > 0)
);

drop trigger if exists set_app_settings_updated_at on public.app_settings;
create trigger set_app_settings_updated_at
before update on public.app_settings
for each row
execute function public.set_updated_at();

alter table public.app_settings enable row level security;

revoke all on table public.app_settings from public, anon;
grant select on table public.app_settings to authenticated, anon;

drop policy if exists "app_settings_public_read" on public.app_settings;
create policy "app_settings_public_read"
on public.app_settings
for select
to anon, authenticated
using (true);

insert into public.app_settings (key, value, description)
values (
  'current_club_school_year',
  '2026-2027',
  'Current club school year used for annual club state and re-applications.'
)
on conflict (key) do nothing;

create or replace function public.get_current_club_school_year()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select btrim(value)
      from public.app_settings
      where key = 'current_club_school_year'
    ),
    '2026-2027'
  );
$$;

revoke all on function public.get_current_club_school_year() from public;
grant execute on function public.get_current_club_school_year()
to anon, authenticated;


-- ---------------------------------------------------------
-- 2. Extend permanent clubs identity (one source of truth)
-- ---------------------------------------------------------

alter table public.clubs
  alter column created_by drop not null;

alter table public.clubs
  add column if not exists instagram_handle text,
  add column if not exists meeting_frequency text,
  add column if not exists meeting_days text[] not null default '{}'::text[],
  add column if not exists meeting_time_details text,
  add column if not exists source_label text,
  add column if not exists eligible_for_reapplication boolean not null default false,
  add column if not exists is_imported_seed boolean not null default false,
  add column if not exists source_names text[] not null default '{}'::text[];

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'clubs_meeting_frequency_valid'
  ) then
    alter table public.clubs
      add constraint clubs_meeting_frequency_valid
      check (
        meeting_frequency is null
        or meeting_frequency in (
          'Weekly',
          'Biweekly',
          'Monthly',
          'Event-Based',
          'Irregular',
          'Other'
        )
      );
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'clubs_meeting_days_valid'
  ) then
    alter table public.clubs
      add constraint clubs_meeting_days_valid
      check (
        meeting_days <@ array[
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday'
        ]::text[]
      );
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'clubs_imported_seed_created_by'
  ) then
    alter table public.clubs
      add constraint clubs_imported_seed_created_by
      check (
        (is_imported_seed = true and created_by is null)
        or (is_imported_seed = false and created_by is not null)
      );
  end if;
end $$;

create index if not exists clubs_eligible_reapplication_idx
  on public.clubs (eligible_for_reapplication)
  where eligible_for_reapplication = true;

create index if not exists clubs_imported_seed_idx
  on public.clubs (is_imported_seed)
  where is_imported_seed = true;


-- ---------------------------------------------------------
-- 3. Searchable aliases (canonical name stays on clubs.name)
-- ---------------------------------------------------------

create table if not exists public.club_aliases (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null
    references public.clubs(id)
    on delete cascade,
  alias text not null,
  created_at timestamptz not null default now(),

  constraint club_aliases_alias_valid
    check (
      alias = btrim(alias)
      and char_length(alias) between 2 and 120
    )
);

create unique index if not exists club_aliases_club_alias_lower_uidx
  on public.club_aliases (club_id, lower(alias));

create index if not exists club_aliases_alias_lower_idx
  on public.club_aliases (lower(alias));

alter table public.club_aliases enable row level security;

revoke all on table public.club_aliases from public, anon;
grant select on table public.club_aliases to authenticated, anon;

drop policy if exists "club_aliases_public_read" on public.club_aliases;
create policy "club_aliases_public_read"
on public.club_aliases
for select
to anon, authenticated
using (true);


-- ---------------------------------------------------------
-- 4. Annual club state (no duplicate permanent club rows)
-- ---------------------------------------------------------

create table if not exists public.club_school_years (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null
    references public.clubs(id)
    on delete cascade,
  school_year text not null,
  status text not null default 'INACTIVE',
  supervisor_due_at timestamptz,
  activated_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint club_school_years_year_not_blank
    check (length(btrim(school_year)) > 0),

  constraint club_school_years_status_valid
    check (
      status in (
        'INACTIVE',
        'PENDING_SUPERVISOR',
        'ACTIVE',
        'SUSPENDED'
      )
    ),

  constraint club_school_years_unique_club_year
    unique (club_id, school_year)
);

create index if not exists club_school_years_year_status_idx
  on public.club_school_years (school_year, status);

create index if not exists club_school_years_pending_due_idx
  on public.club_school_years (supervisor_due_at)
  where status = 'PENDING_SUPERVISOR';

drop trigger if exists set_club_school_years_updated_at on public.club_school_years;
create trigger set_club_school_years_updated_at
before update on public.club_school_years
for each row
execute function public.set_updated_at();

alter table public.club_school_years enable row level security;

revoke all on table public.club_school_years from public, anon;
grant select on table public.club_school_years to authenticated, anon;
grant select, insert, update, delete
on table public.club_school_years
to authenticated;

drop policy if exists "club_school_years_public_active_read"
on public.club_school_years;
drop policy if exists "club_school_years_member_read"
on public.club_school_years;
drop policy if exists "club_school_years_sac_read"
on public.club_school_years;

-- Public may only discover ACTIVE annual rows (Explore joins on this).
create policy "club_school_years_public_active_read"
on public.club_school_years
for select
to anon, authenticated
using (
  status = 'ACTIVE'
  and school_year = public.get_current_club_school_year()
);

create policy "club_school_years_member_read"
on public.club_school_years
for select
to authenticated
using (
  public.has_club_role(club_id, array['OWNER', 'EXEC', 'MEMBER'])
);

create policy "club_school_years_sac_read"
on public.club_school_years
for select
to authenticated
using (
  public.has_system_role('SAC_ADMIN')
  or public.has_system_role('SAC_EXEC')
);


-- ---------------------------------------------------------
-- 5. Public Explore view: current-year ACTIVE clubs only
-- ---------------------------------------------------------

create or replace view public.public_active_clubs
with (security_invoker = true)
as
select
  c.id,
  c.name,
  c.slug,
  c.short_description,
  c.description,
  c.logo_url,
  c.banner_url,
  c.contact_email,
  c.instagram_handle,
  c.meeting_location,
  c.meeting_schedule,
  c.meeting_frequency,
  c.meeting_days,
  c.meeting_time_details,
  c.status as club_record_status,
  csy.school_year,
  csy.status as annual_status,
  csy.activated_at,
  c.created_at,
  c.updated_at
from public.clubs c
join public.club_school_years csy
  on csy.club_id = c.id
where csy.school_year = public.get_current_club_school_year()
  and csy.status = 'ACTIVE'
  and c.status = 'APPROVED';

grant select on public.public_active_clubs to anon, authenticated;


-- ---------------------------------------------------------
-- 6. Helper: current annual row for a club
-- ---------------------------------------------------------

create or replace function public.get_club_current_annual_status(p_club_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select csy.status
  from public.club_school_years csy
  where csy.club_id = p_club_id
    and csy.school_year = public.get_current_club_school_year()
  limit 1;
$$;

revoke all on function public.get_club_current_annual_status(uuid) from public;
grant execute on function public.get_club_current_annual_status(uuid)
to authenticated;


create or replace function public.club_is_publicly_active(p_club_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.club_school_years csy
    join public.clubs c on c.id = csy.club_id
    where csy.club_id = p_club_id
      and csy.school_year = public.get_current_club_school_year()
      and csy.status = 'ACTIVE'
      and c.status = 'APPROVED'
  );
$$;

revoke all on function public.club_is_publicly_active(uuid) from public;
grant execute on function public.club_is_publicly_active(uuid)
to anon, authenticated;


-- ---------------------------------------------------------
-- 7. Tighten public club SELECT: ACTIVE annual state only
-- ---------------------------------------------------------

drop policy if exists "clubs_select_approved" on public.clubs;
create policy "clubs_select_approved"
on public.clubs
for select
to anon, authenticated
using (
  status = 'APPROVED'
  and public.club_is_publicly_active(id)
);

drop policy if exists "clubs_select_members" on public.clubs;
create policy "clubs_select_members"
on public.clubs
for select
to authenticated
using (
  public.has_club_role(id, array['OWNER', 'EXEC', 'MEMBER'])
);

drop policy if exists "clubs_admin_select_all" on public.clubs;
create policy "clubs_admin_select_all"
on public.clubs
for select
to authenticated
using (
  public.has_system_role('SAC_ADMIN')
  or public.has_system_role('SAC_EXEC')
);

-- Owners may update profile fields for PENDING_SUPERVISOR / ACTIVE clubs.
drop policy if exists "clubs_owner_update_profile" on public.clubs;
create policy "clubs_owner_update_profile"
on public.clubs
for update
to authenticated
using (
  public.has_club_role(id, array['OWNER'])
  and public.get_club_current_annual_status(id) in (
    'PENDING_SUPERVISOR',
    'ACTIVE'
  )
)
with check (
  public.has_club_role(id, array['OWNER'])
  and public.get_club_current_annual_status(id) in (
    'PENDING_SUPERVISOR',
    'ACTIVE'
  )
);


-- Backfill current-year ACTIVE annual rows for existing approved clubs
-- so Explore does not go empty before the past-clubs seed lands.
insert into public.club_school_years (club_id, school_year, status, activated_at)
select
  c.id,
  public.get_current_club_school_year(),
  'ACTIVE',
  coalesce(c.approved_at, c.created_at, now())
from public.clubs c
where c.status = 'APPROVED'
  and coalesce(c.is_imported_seed, false) = false
on conflict (club_id, school_year) do nothing;
