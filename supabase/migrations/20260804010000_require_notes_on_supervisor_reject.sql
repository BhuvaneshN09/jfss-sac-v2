-- Require review notes on all SAC reject actions for supervisor workflows.
-- Approvals remain optional for notes.

create or replace function public.review_club_supervisor_request(
  p_request_id uuid,
  p_action text,
  p_review_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_req public.club_supervisor_requests%rowtype;
  v_action text;
  v_notes text;
  v_year text;
  v_active_count int;
  v_new_emails int;
  v_now timestamptz := now();
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not public.has_system_role('SAC_ADMIN') then
    raise exception 'SAC_ADMIN role required' using errcode = '42501';
  end if;

  v_action := upper(btrim(p_action));
  v_notes := nullif(btrim(coalesce(p_review_notes, '')), '');
  v_year := public.get_current_club_school_year();

  select * into v_req
  from public.club_supervisor_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Supervisor request not found';
  end if;

  if v_action = 'APPROVED' and v_req.submitted_by = v_user_id then
    raise exception
      'You cannot approve a supervisor request you submitted'
      using errcode = '42501';
  end if;

  if v_req.status not in ('SUBMITTED', 'UNDER_REVIEW', 'CHANGES_REQUESTED')
     and v_action in ('APPROVED', 'REJECTED', 'UNDER_REVIEW', 'CHANGES_REQUESTED') then
    raise exception 'This supervisor request is no longer open for review';
  end if;

  if v_action = 'UNDER_REVIEW' then
    update public.club_supervisor_requests
    set status = 'UNDER_REVIEW',
        reviewed_by = v_user_id,
        reviewed_at = v_now,
        review_notes = coalesce(v_notes, review_notes)
    where id = p_request_id;

  elsif v_action = 'CHANGES_REQUESTED' then
    if v_notes is null then
      raise exception 'Review notes are required when requesting changes';
    end if;
    update public.club_supervisor_requests
    set status = 'CHANGES_REQUESTED',
        review_notes = v_notes,
        reviewed_by = v_user_id,
        reviewed_at = v_now
    where id = p_request_id;

  elsif v_action = 'REJECTED' then
    if v_notes is null then
      raise exception 'Review notes are required when rejecting';
    end if;
    update public.club_supervisor_requests
    set status = 'REJECTED',
        review_notes = v_notes,
        reviewed_by = v_user_id,
        reviewed_at = v_now
    where id = p_request_id;

  elsif v_action = 'APPROVED' then
    select count(*)::integer into v_new_emails
    from public.club_supervisor_request_supervisors s
    where s.supervisor_request_id = v_req.id
      and not exists (
        select 1
        from public.club_advisors a
        where a.club_id = v_req.club_id
          and a.school_year = v_year
          and a.supervisor_email = s.supervisor_email
          and a.status = 'ACTIVE'
      );

    v_active_count := public.count_active_club_advisors(v_req.club_id, v_year);
    if v_active_count + v_new_emails > 3 then
      raise exception
        'Approving this request would exceed three teacher supervisors for the club';
    end if;

    update public.club_supervisor_requests
    set status = 'APPROVED',
        review_notes = coalesce(v_notes, review_notes),
        reviewed_by = v_user_id,
        reviewed_at = v_now
    where id = p_request_id;

    insert into public.club_advisors (
      club_id,
      school_year,
      supervisor_name,
      supervisor_email,
      status,
      approved_from_request_id,
      approved_by,
      approved_at
    )
    select
      v_req.club_id,
      v_year,
      s.supervisor_name,
      s.supervisor_email,
      'ACTIVE',
      v_req.id,
      v_user_id,
      v_now
    from public.club_supervisor_request_supervisors s
    where s.supervisor_request_id = v_req.id
    on conflict (club_id, school_year, supervisor_email)
      where status = 'ACTIVE'
      do nothing;

    select count(*) into v_active_count
    from public.club_advisors
    where club_id = v_req.club_id
      and school_year = v_year
      and status = 'ACTIVE';

    if v_active_count >= 1 then
      update public.club_school_years
      set status = 'ACTIVE',
          supervisor_due_at = null,
          activated_at = coalesce(activated_at, v_now)
      where club_id = v_req.club_id
        and school_year = v_year
        and status = 'PENDING_SUPERVISOR';
    end if;

  else
    raise exception 'Unsupported review action %', v_action;
  end if;

  return p_request_id;
end;
$$;

revoke all on function public.review_club_supervisor_request(uuid, text, text)
from public, anon;
grant execute on function public.review_club_supervisor_request(uuid, text, text)
to authenticated;


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

  v_notes := nullif(btrim(coalesce(p_review_notes, '')), '');
  if v_notes is null then
    raise exception 'Review notes are required when rejecting';
  end if;

  v_year := public.get_current_club_school_year();

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
