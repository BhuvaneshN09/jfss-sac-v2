-- Security hardening: LIKE wildcard escaping, https URL checks,
-- tighter grants, and per-user mutation rate limits.
-- Browser traffic remains on the same-origin /api/x proxy (no supabase.co).

-- ---------------------------------------------------------
-- Search: escape LIKE wildcards in admin/student search RPCs
-- ---------------------------------------------------------

create or replace function public.like_contains_pattern(p_query text)
returns text
language sql
immutable
parallel safe
as $$
  select '%'
    || replace(replace(replace(coalesce(p_query, ''), '\', '\\'), '%', '\%'), '_', '\_')
    || '%';
$$;

revoke all on function public.like_contains_pattern(text)
from public, anon, authenticated;

create or replace function public.list_archived_clubs(
  p_search text default null
)
returns table (
  club_id uuid,
  name text,
  slug text,
  description text,
  short_description text,
  logo_url text,
  last_active_school_year text,
  archived_at timestamptz,
  archived_by uuid,
  archived_by_email text,
  archived_by_name text,
  eligible_for_reapplication boolean,
  creation_origin text,
  registration_request_count bigint,
  reapplication_request_count bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_q text;
  v_year text;
  v_pattern text;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not (
    public.has_system_role('SAC_ADMIN')
    or public.has_system_role('SAC_EXEC')
  ) then
    raise exception 'SAC_ADMIN or SAC_EXEC required' using errcode = '42501';
  end if;

  v_q := nullif(lower(btrim(coalesce(p_search, ''))), '');
  v_pattern := case when v_q is null then null else public.like_contains_pattern(v_q) end;
  v_year := public.get_current_club_school_year();

  return query
  select
    c.id,
    c.name,
    c.slug,
    c.description,
    c.short_description,
    c.logo_url,
    c.last_active_school_year,
    c.archived_at,
    c.archived_by,
    p.email,
    p.full_name,
    c.eligible_for_reapplication,
    c.creation_origin,
    (
      select count(*)::bigint
      from public.club_registration_requests r
      where r.created_club_id = c.id
    ),
    (
      select count(*)::bigint
      from public.club_reapplication_requests r
      where r.club_id = c.id
    )
  from public.clubs c
  left join public.profiles p on p.id = c.archived_by
  where c.status = 'ARCHIVED'
    and c.deleted_at is null
    and not exists (
      select 1
      from public.club_reapplication_requests r
      where r.club_id = c.id
        and r.school_year = v_year
        and r.status in (
          'SUBMITTED',
          'UNDER_REVIEW',
          'CHANGES_REQUESTED',
          'APPROVED'
        )
    )
    and (
      v_pattern is null
      or lower(c.name) like v_pattern escape '\'
      or lower(c.slug) like v_pattern escape '\'
      or lower(coalesce(c.description, '')) like v_pattern escape '\'
      or lower(coalesce(c.short_description, '')) like v_pattern escape '\'
    )
  order by c.archived_at desc nulls last, c.name;
end;
$$;

revoke all on function public.list_archived_clubs(text)
from public, anon;

grant execute on function public.list_archived_clubs(text)
to authenticated;

create or replace function public.list_eligible_clubs_for_reapplication(
  p_search text default null
)
returns table (
  id uuid,
  name text,
  aliases text[],
  historical_description text,
  historical_meeting_schedule text,
  historical_meeting_location text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_year text;
  v_q text;
  v_pattern text;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  v_year := public.get_current_club_school_year();
  v_q := nullif(lower(btrim(coalesce(p_search, ''))), '');
  v_pattern := case when v_q is null then null else public.like_contains_pattern(v_q) end;

  return query
  select
    c.id,
    c.name,
    coalesce(
      (
        select array_agg(a.alias order by a.alias)
        from public.club_aliases a
        where a.club_id = c.id
      ),
      '{}'::text[]
    ) as aliases,
    c.description as historical_description,
    c.meeting_schedule as historical_meeting_schedule,
    c.meeting_location as historical_meeting_location
  from public.clubs c
  join public.club_school_years csy
    on csy.club_id = c.id
   and csy.school_year = v_year
  where c.deleted_at is null
    and c.eligible_for_reapplication = true
    and csy.status = 'INACTIVE'
    and not exists (
      select 1
      from public.club_reapplication_requests r
      where r.club_id = c.id
        and r.school_year = v_year
        and r.status in (
          'SUBMITTED',
          'UNDER_REVIEW',
          'CHANGES_REQUESTED',
          'APPROVED'
        )
    )
    and (
      v_pattern is null
      or lower(c.name) like v_pattern escape '\'
      or exists (
        select 1
        from public.club_aliases a
        where a.club_id = c.id
          and lower(a.alias) like v_pattern escape '\'
      )
      or exists (
        select 1
        from unnest(c.source_names) as sn
        where lower(sn) like v_pattern escape '\'
      )
    )
  order by c.name;
end;
$$;

revoke all on function public.list_eligible_clubs_for_reapplication(text)
from public, anon;

grant execute on function public.list_eligible_clubs_for_reapplication(text)
to authenticated;

-- ---------------------------------------------------------
-- Application URLs: https only for new/changed values
-- ---------------------------------------------------------

create or replace function public.is_safe_https_url(p_url text)
returns boolean
language plpgsql
immutable
as $$
declare
  v text := btrim(coalesce(p_url, ''));
  v_host text;
  v_rest text;
begin
  if v = '' or char_length(v) > 2000 or v ~ '\s' then
    return false;
  end if;
  if v !~* '^https://' then
    return false;
  end if;
  if v ~ '^https://[^/]*@' then
    return false;
  end if;

  v_rest := substr(v, 9);
  v_host := lower(split_part(split_part(v_rest, '/', 1), ':', 1));

  if v_host = '' or v_host ~ '\.\.' then
    return false;
  end if;

  if v_host in ('localhost', '127.0.0.1', '0.0.0.0', '::1', '[::1]')
     or v_host ~ '\.localhost$' then
    return false;
  end if;

  if v_host ~ '^(10|127)\.[0-9]+\.[0-9]+\.[0-9]+$'
     or v_host ~ '^192\.168\.[0-9]+\.[0-9]+$'
     or v_host ~ '^169\.254\.[0-9]+\.[0-9]+$'
     or v_host ~ '^172\.(1[6-9]|2[0-9]|3[0-1])\.[0-9]+\.[0-9]+$' then
    return false;
  end if;

  return true;
end;
$$;

revoke all on function public.is_safe_https_url(text)
from public, anon, authenticated;

create or replace function public.assert_safe_https_url_change(
  p_old text,
  p_new text,
  p_label text
)
returns void
language plpgsql
stable
as $$
declare
  v_new text := nullif(btrim(coalesce(p_new, '')), '');
  v_old text := nullif(btrim(coalesce(p_old, '')), '');
begin
  if v_new is null then
    return;
  end if;
  if v_old is not distinct from v_new then
    return;
  end if;
  if not public.is_safe_https_url(v_new) then
    raise exception 'Enter a valid https %', p_label
      using errcode = '22023';
  end if;
end;
$$;

revoke all on function public.assert_safe_https_url_change(text, text, text)
from public, anon, authenticated;

create or replace function public.tg_assert_safe_https_urls()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if TG_TABLE_NAME = 'clubs' then
    perform public.assert_safe_https_url_change(
      case when TG_OP = 'UPDATE' then old.member_application_url else null end,
      new.member_application_url,
      'member application link'
    );
    perform public.assert_safe_https_url_change(
      case when TG_OP = 'UPDATE' then old.exec_application_url else null end,
      new.exec_application_url,
      'executive application link'
    );
  elsif TG_TABLE_NAME = 'club_registration_requests' then
    perform public.assert_safe_https_url_change(
      case when TG_OP = 'UPDATE' then old.member_application_url else null end,
      new.member_application_url,
      'member application link'
    );
    perform public.assert_safe_https_url_change(
      case when TG_OP = 'UPDATE' then old.exec_application_url else null end,
      new.exec_application_url,
      'executive application link'
    );
    perform public.assert_safe_https_url_change(
      case when TG_OP = 'UPDATE' then old.constitution_url else null end,
      new.constitution_url,
      'constitution link'
    );
  elsif TG_TABLE_NAME = 'club_reapplication_requests' then
    perform public.assert_safe_https_url_change(
      case when TG_OP = 'UPDATE' then old.member_application_url else null end,
      new.member_application_url,
      'member application link'
    );
    perform public.assert_safe_https_url_change(
      case when TG_OP = 'UPDATE' then old.exec_application_url else null end,
      new.exec_application_url,
      'executive application link'
    );
  end if;

  return new;
end;
$$;

drop trigger if exists tg_assert_safe_https_urls on public.clubs;
create trigger tg_assert_safe_https_urls
before insert or update of member_application_url, exec_application_url
on public.clubs
for each row
execute function public.tg_assert_safe_https_urls();

drop trigger if exists tg_assert_safe_https_urls on public.club_registration_requests;
create trigger tg_assert_safe_https_urls
before insert or update of member_application_url, exec_application_url, constitution_url
on public.club_registration_requests
for each row
execute function public.tg_assert_safe_https_urls();

drop trigger if exists tg_assert_safe_https_urls on public.club_reapplication_requests;
create trigger tg_assert_safe_https_urls
before insert or update of member_application_url, exec_application_url
on public.club_reapplication_requests
for each row
execute function public.tg_assert_safe_https_urls();

-- ---------------------------------------------------------
-- Grants: authenticated cannot write annual-state rows
-- ---------------------------------------------------------

revoke insert, update, delete on table public.club_school_years from authenticated;

drop policy if exists "app_settings_public_read" on public.app_settings;
create policy "app_settings_public_read"
on public.app_settings
for select
to anon, authenticated
using (key = 'current_club_school_year');

-- ---------------------------------------------------------
-- Per-user mutation rate limits (not IP — school NAT shares IPs)
-- ---------------------------------------------------------

create table if not exists public.mutation_rate_events (
  id bigint generated always as identity primary key,
  user_id uuid not null,
  action text not null,
  created_at timestamptz not null default now()
);

create index if not exists mutation_rate_events_user_action_created_idx
  on public.mutation_rate_events (user_id, action, created_at desc);

alter table public.mutation_rate_events enable row level security;

revoke all on table public.mutation_rate_events from public, anon, authenticated;

create or replace function public.enforce_user_mutation_rate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_count integer;
begin
  if v_user is null then
    return new;
  end if;

  delete from public.mutation_rate_events
  where user_id = v_user
    and action = TG_TABLE_NAME
    and created_at < now() - interval '2 hours';

  select count(*) into v_count
  from public.mutation_rate_events
  where user_id = v_user
    and action = TG_TABLE_NAME
    and created_at > now() - interval '1 hour';

  if v_count >= 30 then
    raise exception 'Too many submissions. Please wait and try again.'
      using errcode = 'P0001';
  end if;

  insert into public.mutation_rate_events (user_id, action)
  values (v_user, TG_TABLE_NAME);

  return new;
end;
$$;

revoke all on function public.enforce_user_mutation_rate()
from public, anon, authenticated;

do $$
declare
  t text;
begin
  foreach t in array array[
    'club_registration_requests',
    'club_reapplication_requests',
    'club_event_requests',
    'club_funding_requests',
    'club_supervisor_requests',
    'club_promo_lunch_requests',
    'announcements',
    'club_membership_invitations',
    'athletes_of_the_month'
  ]
  loop
    execute format(
      'drop trigger if exists tg_mutation_rate on public.%I',
      t
    );
    execute format(
      'create trigger tg_mutation_rate
       before insert on public.%I
       for each row
       execute function public.enforce_user_mutation_rate()',
      t
    );
  end loop;
end;
$$;
