-- =========================================================
-- Reapplication withdrawal + conditional supervisor approval
-- =========================================================

-- 1. Allow WITHDRAWN on reapplication requests
alter table public.club_reapplication_requests
  drop constraint if exists club_reapp_v2_status_valid;

alter table public.club_reapplication_requests
  add constraint club_reapp_v2_status_valid
  check (
    status in (
      'SUBMITTED',
      'UNDER_REVIEW',
      'CHANGES_REQUESTED',
      'APPROVED',
      'REJECTED',
      'WITHDRAWN'
    )
  );

-- Blocking unique index already excludes WITHDRAWN / REJECTED.


-- 2. Withdraw reapplication (pre-approval or approved+pending supervisor)
create or replace function public.withdraw_club_reapplication(p_request_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_req public.club_reapplication_requests%rowtype;
  v_year text;
  v_annual public.club_school_years%rowtype;
  v_now timestamptz := now();
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_request_id is null then
    raise exception 'Request ID is required';
  end if;

  v_year := public.get_current_club_school_year();

  select * into v_req
  from public.club_reapplication_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Re-application not found';
  end if;

  -- Case 1: before approval — original applicant only
  if v_req.status in ('SUBMITTED', 'UNDER_REVIEW', 'CHANGES_REQUESTED') then
    if v_req.requested_by <> v_user_id then
      raise exception 'Only the original applicant may withdraw this request'
        using errcode = '42501';
    end if;

    update public.club_reapplication_requests
    set
      status = 'WITHDRAWN',
      reviewed_at = v_now,
      review_notes = coalesce(
        nullif(btrim(coalesce(review_notes, '')), ''),
        'Withdrawn by applicant before approval.'
      )
    where id = p_request_id;

    return p_request_id;
  end if;

  -- Case 2: APPROVED + PENDING_SUPERVISOR — active OWNER only
  if v_req.status = 'APPROVED' then
    perform 1
    from public.clubs c
    where c.id = v_req.club_id
    for update;

    select * into v_annual
    from public.club_school_years
    where club_id = v_req.club_id
      and school_year = v_year
    for update;

    if not found then
      raise exception 'Current school-year record not found for this club';
    end if;

    if v_annual.status = 'ACTIVE' then
      raise exception
        'Active clubs cannot be withdrawn. Use Archive Club instead.';
    end if;

    if v_annual.status is distinct from 'PENDING_SUPERVISOR' then
      raise exception
        'Withdrawal after approval is only allowed while pending teacher supervisor';
    end if;

    if not public.has_club_role(v_req.club_id, array['OWNER']) then
      raise exception
        'Only an active club OWNER may withdraw a pending-supervisor club'
        using errcode = '42501';
    end if;

    -- Annual → INACTIVE first (owner-limit trigger)
    update public.club_school_years
    set
      status = 'INACTIVE',
      supervisor_due_at = null,
      activated_at = null
    where club_id = v_req.club_id
      and school_year = v_year;

    update public.club_memberships
    set status = 'INACTIVE'
    where club_id = v_req.club_id
      and status = 'ACTIVE';

    update public.club_supervisor_requests
    set
      status = 'CANCELLED',
      review_notes = coalesce(
        nullif(btrim(coalesce(review_notes, '')), ''),
        'Cancelled because the re-application was withdrawn.'
      ),
      reviewed_by = v_user_id,
      reviewed_at = v_now
    where club_id = v_req.club_id
      and school_year = v_year
      and status in ('SUBMITTED', 'UNDER_REVIEW', 'CHANGES_REQUESTED');

    update public.club_advisors
    set status = 'INACTIVE'
    where club_id = v_req.club_id
      and school_year = v_year
      and status = 'ACTIVE';

    update public.clubs
    set eligible_for_reapplication = true
    where id = v_req.club_id;

    update public.club_reapplication_requests
    set
      status = 'WITHDRAWN',
      reviewed_at = v_now,
      review_notes = coalesce(
        nullif(btrim(coalesce(review_notes, '')), ''),
        'Withdrawn by owner while pending teacher supervisor.'
      )
    where id = p_request_id;

    return p_request_id;
  end if;

  raise exception 'This re-application cannot be withdrawn from status %', v_req.status;
end;
$$;

revoke all on function public.withdraw_club_reapplication(uuid)
from public, anon;
grant execute on function public.withdraw_club_reapplication(uuid)
to authenticated;


-- 3. Conditional approve: admin chooses supervisor YES/NO + optional deadline
drop function if exists public.approve_club_reapplication(uuid, text);

create or replace function public.approve_club_reapplication(
  p_request_id uuid,
  p_review_notes text default null,
  p_has_teacher_supervisor boolean default null,
  p_supervisor_due_at timestamptz default null
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
  v_due_at timestamptz;
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

  -- Admin explicit choice overrides; otherwise infer from listed supervisors.
  if p_has_teacher_supervisor is null then
    v_has_supervisor := exists (
      select 1
      from public.club_reapplication_supervisors s
      where s.request_id = v_req.id
    );
  else
    v_has_supervisor := p_has_teacher_supervisor;
  end if;

  if v_has_supervisor then
    v_annual_status := 'ACTIVE';
    v_due_at := null;
  else
    v_annual_status := 'PENDING_SUPERVISOR';
    if p_supervisor_due_at is null then
      v_due_at :=
        ((timezone('America/Toronto', v_approved_at) + interval '7 days')
          at time zone 'America/Toronto');
    else
      if p_supervisor_due_at <= v_approved_at then
        raise exception 'Supervisor deadline must be after approval time';
      end if;
      v_due_at := p_supervisor_due_at;
    end if;
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
    archived_by = null,
    eligible_for_reapplication = true
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
    supervisor_due_at = v_due_at,
    activated_at = case
      when v_annual_status = 'ACTIVE' then v_approved_at
      else null
    end
  where club_id = v_req.club_id
    and school_year = v_year;

  -- Only create advisor rows when admin confirms supervisors are present
  -- and the request listed them.
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

revoke all on function public.approve_club_reapplication(uuid, text, boolean, timestamptz)
from public, anon;
grant execute on function public.approve_club_reapplication(uuid, text, boolean, timestamptz)
to authenticated;


-- 4. Reject pending/overdue supervisor club (SAC_ADMIN)
create or replace function public.admin_reject_pending_supervisor_club(
  p_club_id uuid,
  p_review_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_year text;
  v_annual public.club_school_years%rowtype;
  v_now timestamptz := now();
  v_notes text;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not public.has_system_role('SAC_ADMIN') then
    raise exception 'SAC_ADMIN role required' using errcode = '42501';
  end if;

  v_year := public.get_current_club_school_year();
  v_notes := coalesce(
    nullif(btrim(coalesce(p_review_notes, '')), ''),
    'Rejected while pending teacher supervisor.'
  );

  perform 1 from public.clubs where id = p_club_id for update;

  select * into v_annual
  from public.club_school_years
  where club_id = p_club_id
    and school_year = v_year
  for update;

  if not found or v_annual.status <> 'PENDING_SUPERVISOR' then
    raise exception 'Club is not pending teacher supervisor for the current year';
  end if;

  update public.club_school_years
  set
    status = 'INACTIVE',
    supervisor_due_at = null,
    activated_at = null,
    notes = coalesce(notes || E'\n', '') || v_notes
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
      v_notes
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

  update public.club_reapplication_requests
  set
    status = 'REJECTED',
    review_notes = v_notes,
    reviewed_by = v_user_id,
    reviewed_at = v_now
  where club_id = p_club_id
    and school_year = v_year
    and status = 'APPROVED';

  update public.clubs
  set eligible_for_reapplication = true
  where id = p_club_id;

  return p_club_id;
end;
$$;

revoke all on function public.admin_reject_pending_supervisor_club(uuid, text)
from public, anon;
grant execute on function public.admin_reject_pending_supervisor_club(uuid, text)
to authenticated;


-- 5. Extend deadline with audit note
create or replace function public.extend_club_supervisor_deadline(
  p_club_id uuid,
  p_new_due_at timestamptz
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_year text;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not public.has_system_role('SAC_ADMIN') then
    raise exception 'SAC_ADMIN role required' using errcode = '42501';
  end if;

  if p_new_due_at is null or p_new_due_at <= now() then
    raise exception 'New deadline must be in the future';
  end if;

  v_year := public.get_current_club_school_year();

  update public.club_school_years
  set
    supervisor_due_at = p_new_due_at,
    notes = coalesce(notes || E'\n', '')
      || 'Deadline extended to '
      || to_char(p_new_due_at at time zone 'America/Toronto', 'YYYY-MM-DD HH24:MI TZH')
      || ' (America/Toronto).'
  where club_id = p_club_id
    and school_year = v_year
    and status = 'PENDING_SUPERVISOR';

  if not found then
    raise exception 'No PENDING_SUPERVISOR annual record found for this club';
  end if;

  return p_club_id;
end;
$$;

revoke all on function public.extend_club_supervisor_deadline(uuid, timestamptz)
from public, anon;
grant execute on function public.extend_club_supervisor_deadline(uuid, timestamptz)
to authenticated;


-- 6. Richer pending/overdue supervisor admin listing
create or replace function public.list_supervisor_watch_clubs(
  p_mode text default 'PENDING'
)
returns table (
  club_id uuid,
  name text,
  slug text,
  annual_status text,
  school_year text,
  supervisor_due_at timestamptz,
  is_overdue boolean,
  days_overdue integer,
  approved_at timestamptz,
  owner_emails text[],
  supervisor_request_status text,
  reapplication_request_id uuid
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_year text;
  v_mode text;
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
  v_mode := upper(btrim(coalesce(p_mode, 'PENDING')));

  return query
  select
    c.id,
    c.name,
    c.slug,
    csy.status,
    csy.school_year,
    csy.supervisor_due_at,
    (
      csy.supervisor_due_at is not null
      and csy.supervisor_due_at < now()
    ) as is_overdue,
    case
      when csy.supervisor_due_at is not null and csy.supervisor_due_at < now()
        then greatest(
          0,
          ceil(extract(epoch from (now() - csy.supervisor_due_at)) / 86400.0)
        )::integer
      else 0
    end as days_overdue,
    coalesce(
      (
        select r.reviewed_at
        from public.club_reapplication_requests r
        where r.club_id = c.id
          and r.school_year = v_year
          and r.status = 'APPROVED'
        order by r.reviewed_at desc nulls last
        limit 1
      ),
      c.approved_at
    ) as approved_at,
    coalesce(
      (
        select array_agg(p.email order by p.email)
        from public.club_memberships m
        join public.profiles p on p.id = m.user_id
        where m.club_id = c.id
          and m.role = 'OWNER'
          and m.status = 'ACTIVE'
      ),
      '{}'::text[]
    ) as owner_emails,
    (
      select sr.status
      from public.club_supervisor_requests sr
      where sr.club_id = c.id
        and sr.school_year = v_year
      order by sr.submitted_at desc
      limit 1
    ) as supervisor_request_status,
    (
      select r.id
      from public.club_reapplication_requests r
      where r.club_id = c.id
        and r.school_year = v_year
        and r.status = 'APPROVED'
      order by r.reviewed_at desc nulls last
      limit 1
    ) as reapplication_request_id
  from public.clubs c
  join public.club_school_years csy
    on csy.club_id = c.id
   and csy.school_year = v_year
  where csy.status = 'PENDING_SUPERVISOR'
    and c.status <> 'ARCHIVED'
    and (
      v_mode = 'PENDING'
      or (
        v_mode = 'OVERDUE'
        and csy.supervisor_due_at is not null
        and csy.supervisor_due_at < now()
      )
    )
  order by
    csy.supervisor_due_at nulls last,
    c.name;
end;
$$;

revoke all on function public.list_supervisor_watch_clubs(text)
from public, anon;
grant execute on function public.list_supervisor_watch_clubs(text)
to authenticated;


-- Owners may read APPROVED reapplications for clubs they own (withdraw UI).
drop policy if exists "club_reapp_owner_select_approved"
on public.club_reapplication_requests;

create policy "club_reapp_owner_select_approved"
on public.club_reapplication_requests
for select
to authenticated
using (
  status = 'APPROVED'
  and public.has_club_role(club_id, array['OWNER'])
);
