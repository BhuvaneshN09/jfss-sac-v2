-- =========================================================
-- Permanent club archive rule: clubs can NEVER be deleted.
-- Archive-only workflow + admin archived list + no direct restore.
-- =========================================================

-- Archive metadata
alter table public.clubs
  add column if not exists archived_at timestamptz,
  add column if not exists archived_by uuid
    references public.profiles(id)
    on delete set null,
  add column if not exists last_active_school_year text;

create index if not exists clubs_archived_at_idx
  on public.clubs (archived_at desc)
  where status = 'ARCHIVED';


-- Block permanent deletion at the database level.
create or replace function public.prevent_club_permanent_delete()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception
    'Clubs cannot be permanently deleted. Use archive workflow.'
    using errcode = 'P0001';
end;
$$;

drop trigger if exists prevent_club_permanent_delete_trigger on public.clubs;
create trigger prevent_club_permanent_delete_trigger
before delete on public.clubs
for each row
execute function public.prevent_club_permanent_delete();


-- Block direct reactivation (ARCHIVED → other status) outside approved RPCs.
create or replace function public.prevent_club_direct_reactivation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
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

drop trigger if exists prevent_club_direct_reactivation_trigger on public.clubs;
create trigger prevent_club_direct_reactivation_trigger
before update on public.clubs
for each row
execute function public.prevent_club_direct_reactivation();


-- Remove DELETE privilege / policy so clients cannot attempt club deletes.
drop policy if exists "clubs_admin_delete" on public.clubs;
revoke delete on table public.clubs from authenticated, anon, public;


-- Owner-only archive RPC (no permanent delete, no direct restore).
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

  -- Active OWNER of this exact club only.
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

  if v_club.status = 'ARCHIVED' then
    raise exception 'This club is already archived';
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

  if v_annual.status = 'INACTIVE' then
    raise exception 'This club is already inactive for the current school year';
  end if;

  if v_annual.status not in ('ACTIVE', 'PENDING_SUPERVISOR') then
    raise exception
      'Club annual status % cannot be archived',
      v_annual.status;
  end if;

  -- Annual → INACTIVE before memberships (owner-limit trigger).
  update public.club_school_years
  set
    status = 'INACTIVE',
    supervisor_due_at = null,
    activated_at = null
  where club_id = p_club_id
    and school_year = v_year;

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


-- Reapplication approval may unarchive (only path back to active).
create or replace function public.approve_club_reapplication(
  p_request_id uuid,
  p_review_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_req public.club_reapplication_requests%rowtype;
  v_club public.clubs%rowtype;
  v_year text;
  v_approved_at timestamptz;
  v_has_supervisor boolean;
  v_annual_status text;
  v_logo_url text;
  v_schedule text;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not public.has_system_role('SAC_ADMIN') then
    raise exception 'SAC_ADMIN role required' using errcode = '42501';
  end if;

  v_year := public.get_current_club_school_year();
  v_approved_at := now();

  select * into v_req
  from public.club_reapplication_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Request not found';
  end if;

  if v_req.status not in ('SUBMITTED', 'UNDER_REVIEW', 'CHANGES_REQUESTED') then
    raise exception 'Request is not approvable from status %', v_req.status;
  end if;

  if v_req.school_year <> v_year then
    raise exception 'Request school year does not match the current club school year';
  end if;

  select * into v_club
  from public.clubs
  where id = v_req.club_id
  for update;

  if not found then
    raise exception 'Club not found';
  end if;

  insert into public.club_school_years (club_id, school_year, status)
  values (v_req.club_id, v_year, 'INACTIVE')
  on conflict (club_id, school_year) do nothing;

  perform 1
  from public.club_school_years
  where club_id = v_req.club_id
    and school_year = v_year
  for update;

  if exists (
    select 1
    from public.club_school_years
    where club_id = v_req.club_id
      and school_year = v_year
      and status in ('PENDING_SUPERVISOR', 'ACTIVE')
  ) then
    raise exception 'Club is already pending or active for this school year';
  end if;

  if exists (
    select 1
    from public.club_reapplication_requests r
    where r.club_id = v_req.club_id
      and r.school_year = v_year
      and r.id <> v_req.id
      and r.status in (
        'SUBMITTED',
        'UNDER_REVIEW',
        'CHANGES_REQUESTED',
        'APPROVED'
      )
  ) then
    raise exception 'Conflicting re-application exists for this club';
  end if;

  v_has_supervisor := exists (
    select 1
    from public.club_reapplication_supervisors s
    where s.request_id = v_req.id
  );

  if v_has_supervisor then
    v_annual_status := 'ACTIVE';
  else
    v_annual_status := 'PENDING_SUPERVISOR';
  end if;

  v_logo_url := v_club.logo_url;
  if v_req.proposed_logo_storage_path is not null
     and length(btrim(v_req.proposed_logo_storage_path)) > 0 then
    v_logo_url := btrim(v_req.proposed_logo_storage_path);
  end if;

  v_schedule := case
    when cardinality(v_req.meeting_days) > 0 then
      v_req.meeting_frequency || ' · ' || array_to_string(v_req.meeting_days, ', ')
      || coalesce(' · ' || nullif(v_req.meeting_time_details, ''), '')
    else
      v_req.meeting_frequency
      || coalesce(' · ' || nullif(v_req.meeting_time_details, ''), '')
  end;

  -- Only reapplication approval may leave ARCHIVED status.
  perform set_config('app.allow_club_unarchive', 'on', true);

  update public.clubs
  set
    short_description = v_req.short_description,
    description = v_req.description,
    contact_email = v_req.public_email,
    instagram_handle = v_req.instagram_handle,
    meeting_frequency = v_req.meeting_frequency,
    meeting_days = v_req.meeting_days,
    meeting_time_details = v_req.meeting_time_details,
    meeting_location = v_req.meeting_location,
    meeting_schedule = nullif(btrim(v_schedule), ''),
    logo_url = v_logo_url,
    status = 'APPROVED',
    approved_by = v_user_id,
    approved_at = coalesce(approved_at, v_approved_at),
    archived_at = null,
    archived_by = null
  where id = v_req.club_id;

  delete from public.club_memberships
  where club_id = v_req.club_id;

  insert into public.club_memberships (
    club_id, user_id, role, status, added_by, joined_at
  )
  values (
    v_req.club_id,
    v_req.requested_by,
    'OWNER',
    'ACTIVE',
    v_user_id,
    v_approved_at
  );

  update public.club_school_years
  set
    status = v_annual_status,
    supervisor_due_at = case
      when v_annual_status = 'PENDING_SUPERVISOR'
        then v_approved_at + interval '7 days'
      else null
    end,
    activated_at = case
      when v_annual_status = 'ACTIVE' then v_approved_at
      else null
    end
  where club_id = v_req.club_id
    and school_year = v_year;

  if v_has_supervisor then
    insert into public.club_advisors (
      club_id, school_year, supervisor_name, supervisor_email,
      status, approved_by, approved_at
    )
    select
      v_req.club_id, v_year, s.supervisor_name, s.supervisor_email,
      'ACTIVE', v_user_id, v_approved_at
    from public.club_reapplication_supervisors s
    where s.request_id = v_req.id
    on conflict (club_id, school_year, supervisor_email)
      where (status = 'ACTIVE')
      do nothing;
  end if;

  update public.club_reapplication_requests
  set
    status = 'APPROVED',
    review_notes = coalesce(
      nullif(btrim(coalesce(p_review_notes, '')), ''),
      review_notes
    ),
    reviewed_by = v_user_id,
    reviewed_at = v_approved_at
  where id = p_request_id;

  return v_req.club_id;
end;
$$;

revoke all on function public.approve_club_reapplication(uuid, text)
from public, anon;
grant execute on function public.approve_club_reapplication(uuid, text)
to authenticated;


-- Support OVERDUE filter for exec dashboard.
create or replace function public.list_clubs_by_annual_status(
  p_status text
)
returns table (
  club_id uuid,
  name text,
  slug text,
  annual_status text,
  school_year text,
  supervisor_due_at timestamptz,
  is_overdue boolean,
  eligible_for_reapplication boolean,
  aliases text[]
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_year text;
  v_status text;
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

  v_year := public.get_current_club_school_year();
  v_status := upper(btrim(coalesce(p_status, '')));

  return query
  select
    c.id,
    c.name,
    c.slug,
    csy.status,
    csy.school_year,
    csy.supervisor_due_at,
    (
      csy.status = 'PENDING_SUPERVISOR'
      and csy.supervisor_due_at is not null
      and csy.supervisor_due_at < now()
    ) as is_overdue,
    c.eligible_for_reapplication,
    coalesce(
      (
        select array_agg(a.alias order by a.alias)
        from public.club_aliases a
        where a.club_id = c.id
      ),
      '{}'::text[]
    )
  from public.clubs c
  join public.club_school_years csy
    on csy.club_id = c.id
   and csy.school_year = v_year
  where c.status <> 'ARCHIVED'
    and (
      (
        v_status = 'OVERDUE'
        and csy.status = 'PENDING_SUPERVISOR'
        and csy.supervisor_due_at is not null
        and csy.supervisor_due_at < now()
      )
      or (
        v_status <> 'OVERDUE'
        and csy.status = v_status
      )
    )
  order by c.name;
end;
$$;

revoke all on function public.list_clubs_by_annual_status(text)
from public, anon;
grant execute on function public.list_clubs_by_annual_status(text)
to authenticated;


create or replace function public.list_archived_clubs(
  p_search text default null
)
returns table (
  club_id uuid,
  name text,
  slug text,
  last_active_school_year text,
  archived_at timestamptz,
  archived_by uuid,
  archived_by_email text,
  archived_by_name text,
  eligible_for_reapplication boolean,
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

  return query
  select
    c.id,
    c.name,
    c.slug,
    c.last_active_school_year,
    c.archived_at,
    c.archived_by,
    p.email,
    p.full_name,
    c.eligible_for_reapplication,
    (
      select count(*)::bigint
      from public.club_registration_requests r
      where r.created_club_id = c.id
         or lower(btrim(r.proposed_name)) = lower(btrim(c.name))
    ),
    (
      select count(*)::bigint
      from public.club_reapplication_requests r
      where r.club_id = c.id
    )
  from public.clubs c
  left join public.profiles p on p.id = c.archived_by
  where c.status = 'ARCHIVED'
    and (
      v_q is null
      or lower(c.name) like '%' || v_q || '%'
      or lower(c.slug) like '%' || v_q || '%'
    )
  order by c.archived_at desc nulls last, c.name;
end;
$$;

revoke all on function public.list_archived_clubs(text)
from public, anon;
grant execute on function public.list_archived_clubs(text)
to authenticated;


-- Backfill archive metadata for already-archived clubs.
update public.clubs c
set
  archived_at = coalesce(c.archived_at, c.updated_at, now()),
  last_active_school_year = coalesce(
    c.last_active_school_year,
    public.get_current_club_school_year()
  ),
  eligible_for_reapplication = true
where c.status = 'ARCHIVED';
