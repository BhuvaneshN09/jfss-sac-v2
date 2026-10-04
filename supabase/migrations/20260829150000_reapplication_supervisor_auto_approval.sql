-- Determine re-application approval state from the applicant's supervisor
-- selection. Admin approval no longer asks for or overrides this choice.

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

  -- The applicant's "still looking" choice is authoritative. A listed
  -- supervisor means ACTIVE; otherwise the club stays pending.
  v_has_supervisor :=
    not coalesce(v_req.is_seeking_teacher_supervisor, false)
    and exists (
      select 1
      from public.club_reapplication_supervisors s
      where s.request_id = v_req.id
    );

  if v_has_supervisor then
    v_annual_status := 'ACTIVE';
    v_due_at := null;
  else
    v_annual_status := 'PENDING_SUPERVISOR';
    v_due_at :=
      ((timezone('America/Toronto', v_approved_at) + interval '7 days')
        at time zone 'America/Toronto');
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

revoke all on function public.approve_club_reapplication(
  uuid, text, boolean, timestamptz
) from public, anon;

grant execute on function public.approve_club_reapplication(
  uuid, text, boolean, timestamptz
) to authenticated;
