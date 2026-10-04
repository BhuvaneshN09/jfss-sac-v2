-- Archived clubs can be re-applied for regardless of how they were created.
-- This supersedes the earlier terminal-archive behavior for NEW_APPLICATION
-- clubs, which incorrectly prevented clubs such as Data Science Club from
-- being re-registered after an owner archived them.

-- Keep creation origin immutable, but allow the old terminal-archive markers
-- to be cleared during the one-time repair below.
create or replace function public.clubs_enforce_origin_and_deletion()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.creation_origin is null or new.creation_origin = 'UNKNOWN' then
      if coalesce(new.is_imported_seed, false) then
        new.creation_origin := 'HISTORICAL_IMPORT';
      elsif new.created_by is not null then
        new.creation_origin := 'NEW_APPLICATION';
      else
        new.creation_origin := 'UNKNOWN';
      end if;
    end if;
    return new;
  end if;

  if new.creation_origin is distinct from old.creation_origin then
    raise exception 'creation_origin is immutable'
      using errcode = 'P0001';
  end if;

  if old.deleted_at is not null
     and coalesce(
       nullif(current_setting('app.allow_archived_club_repair', true), ''),
       'off'
     ) <> 'on' then
    if new.deleted_at is distinct from old.deleted_at then
      raise exception 'deleted_at cannot be changed once set'
        using errcode = 'P0001';
    end if;
    if new.eligible_for_reapplication is distinct from false then
      raise exception
        'Permanently removed clubs cannot become reapplication-eligible'
        using errcode = 'P0001';
    end if;
    if new.status is distinct from 'ARCHIVED' then
      raise exception
        'Permanently removed clubs cannot change status'
        using errcode = 'P0001';
    end if;
  end if;

  return new;
end;
$$;

-- Allow the one-time repair to clear legacy deleted_at values.
create or replace function public.prevent_club_direct_reactivation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.deleted_at is not null
     and coalesce(
       nullif(current_setting('app.allow_archived_club_repair', true), ''),
       'off'
     ) <> 'on' then
    raise exception
      'This club was permanently removed and cannot be reactivated or re-applied for.'
      using errcode = 'P0001';
  end if;

  if old.status = 'ARCHIVED'
     and new.status is distinct from 'ARCHIVED'
     and coalesce(
       nullif(current_setting('app.allow_club_unarchive', true), ''),
       'off'
     ) <> 'on' then
    raise exception
      'Archived clubs cannot be reactivated directly. Submit a re-application for SAC approval.'
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;

-- Convert legacy terminal archives into ordinary reapplication-eligible
-- archives. The setting is transaction-local and cannot be supplied by the
-- client through the normal RPCs.
select set_config('app.allow_archived_club_repair', 'on', true);

update public.clubs
set
  deleted_at = null,
  eligible_for_reapplication = true
where status = 'ARCHIVED'
  and creation_origin = 'NEW_APPLICATION';

-- Reapplication targets are governed by the eligibility flag, not origin.
create or replace function public.enforce_reapplication_target_eligibility()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_club public.clubs%rowtype;
begin
  select * into v_club
  from public.clubs
  where id = new.club_id;

  if not found then
    raise exception 'Club not found';
  end if;

  if v_club.eligible_for_reapplication is not true then
    raise exception 'This club is not eligible for re-application';
  end if;

  return new;
end;
$$;

-- Future owner archives also remain eligible for reapplication.
create or replace function public.archive_owned_club(p_club_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_club public.clubs%rowtype;
  v_year text;
  v_annual public.club_school_years%rowtype;
  v_now timestamptz := now();
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  if p_club_id is null then
    raise exception 'Club ID is required';
  end if;

  if not public.has_club_role(p_club_id, array['OWNER']) then
    raise exception 'Only an active club OWNER may archive this club'
      using errcode = '42501';
  end if;

  v_year := public.get_current_club_school_year();

  select *
  into v_club
  from public.clubs
  where id = p_club_id
  for update;

  if not found then
    raise exception 'Club not found';
  end if;

  if v_club.deleted_at is not null then
    raise exception 'This club was permanently removed and cannot be archived';
  end if;

  if v_club.status = 'ARCHIVED' then
    return p_club_id;
  end if;

  insert into public.club_school_years (club_id, school_year, status)
  values (p_club_id, v_year, 'INACTIVE')
  on conflict (club_id, school_year) do nothing;

  select *
  into v_annual
  from public.club_school_years
  where club_id = p_club_id
    and school_year = v_year
  for update;

  if not found then
    raise exception 'Could not load the current club school year record';
  end if;

  if v_annual.status = 'INACTIVE' and v_club.status <> 'ARCHIVED' then
    null;
  elsif v_annual.status not in ('ACTIVE', 'PENDING_SUPERVISOR', 'INACTIVE') then
    raise exception
      'Club annual status % cannot be archived',
      v_annual.status;
  end if;

  if v_annual.status in ('ACTIVE', 'PENDING_SUPERVISOR') then
    update public.club_school_years
    set
      status = 'INACTIVE',
      supervisor_due_at = null,
      activated_at = null
    where club_id = p_club_id
      and school_year = v_year;
  end if;

  update public.club_memberships
  set status = 'INACTIVE'
  where club_id = p_club_id
    and status = 'ACTIVE';

  update public.club_supervisor_requests
  set
    status = 'CANCELLED',
    review_notes = coalesce(
      nullif(btrim(coalesce(review_notes, '')), ''),
      'Cancelled because the club was archived by an owner.'
    ),
    reviewed_by = v_user_id,
    reviewed_at = v_now
  where club_id = p_club_id
    and school_year = v_year
    and status in ('SUBMITTED', 'UNDER_REVIEW', 'CHANGES_REQUESTED');

  update public.club_advisors
  set status = 'INACTIVE'
  where club_id = p_club_id
    and school_year = v_year
    and status = 'ACTIVE';

  update public.clubs
  set
    status = 'ARCHIVED',
    eligible_for_reapplication = true,
    deleted_at = null,
    archived_at = v_now,
    archived_by = v_user_id,
    last_active_school_year = v_year
  where id = p_club_id;

  return p_club_id;
end;
$$;

revoke all on function public.archive_owned_club(uuid)
from public, anon;

grant execute on function public.archive_owned_club(uuid)
to authenticated;

-- Include archived new-application clubs in the reapplication picker.
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
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  v_year := public.get_current_club_school_year();
  v_q := nullif(lower(btrim(coalesce(p_search, ''))), '');

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
      v_q is null
      or lower(c.name) like '%' || v_q || '%'
      or exists (
        select 1
        from public.club_aliases a
        where a.club_id = c.id
          and lower(a.alias) like '%' || v_q || '%'
      )
      or exists (
        select 1
        from unnest(c.source_names) as sn
        where lower(sn) like '%' || v_q || '%'
      )
    )
  order by c.name;
end;
$$;

revoke all on function public.list_eligible_clubs_for_reapplication(text)
from public, anon;

grant execute on function public.list_eligible_clubs_for_reapplication(text)
to authenticated;
