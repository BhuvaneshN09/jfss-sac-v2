-- Remove the per-club teacher supervisor count limit.
-- Duplicate emails, valid PDSB emails, signatures, and review permissions
-- remain enforced.

create or replace function public.submit_club_supervisor_request(
  p_request_id uuid,
  p_club_id uuid,
  p_supervisors jsonb,
  p_attachments jsonb default '[]'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_year text;
  v_annual_status text;
  v_sup jsonb;
  v_att jsonb;
  v_att_count int;
  v_name text;
  v_email text;
  v_emails text[] := '{}'::text[];
  v_row jsonb;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_request_id is null or p_club_id is null then
    raise exception 'Request ID and club ID are required';
  end if;

  if not public.has_club_role(p_club_id, array['OWNER']) then
    raise exception 'Only active club OWNERs may submit supervisor information'
      using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.clubs c
    where c.id = p_club_id
      and c.deleted_at is null
      and c.status = 'APPROVED'
  ) then
    raise exception 'Club not found or unavailable';
  end if;

  v_year := public.get_current_club_school_year();
  v_annual_status := public.get_club_current_annual_status(p_club_id);

  if v_annual_status is distinct from 'PENDING_SUPERVISOR'
     and v_annual_status is distinct from 'ACTIVE' then
    raise exception
      'Supervisor submissions are only allowed for pending or active clubs';
  end if;

  v_sup := coalesce(p_supervisors, '[]'::jsonb);
  if jsonb_typeof(v_sup) <> 'array' then
    raise exception 'Supervisors must be an array';
  end if;

  if jsonb_array_length(v_sup) < 1 then
    raise exception 'Provide at least one teacher supervisor';
  end if;

  v_att := coalesce(p_attachments, '[]'::jsonb);
  if jsonb_typeof(v_att) <> 'array' then
    raise exception 'Attachments must be an array';
  end if;
  v_att_count := jsonb_array_length(v_att);
  if v_att_count < 1 then
    raise exception
      'A teacher signature attachment is required';
  end if;

  for v_row in
    select value from jsonb_array_elements(v_sup)
  loop
    v_name := btrim(coalesce(v_row->>'name', ''));
    v_email := lower(btrim(coalesce(v_row->>'email', '')));

    if char_length(v_name) < 2 or char_length(v_name) > 120 then
      raise exception 'Each supervisor needs a full name';
    end if;

    if v_email is null
       or v_email !~ '^[^[:space:]@]+@pdsb[.]net$' then
      raise exception
        'Each supervisor email must be an exact @pdsb.net address';
    end if;

    if v_email = any (v_emails) then
      raise exception 'Duplicate supervisor email in this request';
    end if;

    v_emails := array_append(v_emails, v_email);

    if exists (
      select 1
      from public.club_advisors a
      where a.club_id = p_club_id
        and a.school_year = v_year
        and a.supervisor_email = v_email
        and a.status = 'ACTIVE'
    ) then
      raise exception
        'This teacher is already an approved supervisor for this club';
    end if;

    if exists (
      select 1
      from public.club_supervisor_requests r
      join public.club_supervisor_request_supervisors s
        on s.supervisor_request_id = r.id
      where r.club_id = p_club_id
        and r.school_year = v_year
        and r.status in ('SUBMITTED', 'UNDER_REVIEW', 'CHANGES_REQUESTED')
        and s.supervisor_email = v_email
    ) then
      raise exception
        'A pending supervisor request already exists for this teacher email';
    end if;
  end loop;

  insert into public.club_supervisor_requests (
    id, club_id, school_year, submitted_by, status, submitted_at
  )
  values (
    p_request_id, p_club_id, v_year, v_user_id, 'SUBMITTED', now()
  );

  insert into public.club_supervisor_request_supervisors (
    supervisor_request_id, supervisor_name, supervisor_email
  )
  select
    p_request_id,
    btrim(s->>'name'),
    lower(btrim(s->>'email'))
  from jsonb_array_elements(v_sup) as s;

  insert into public.club_supervisor_request_attachments (
    supervisor_request_id,
    storage_path,
    original_filename,
    mime_type,
    size_bytes,
    uploaded_by
  )
  select
    p_request_id,
    btrim(a->>'storage_path'),
    btrim(a->>'original_filename'),
    btrim(a->>'mime_type'),
    (a->>'size_bytes')::bigint,
    v_user_id
  from jsonb_array_elements(v_att) as a
  where btrim(coalesce(a->>'storage_path', ''))
        like ('supervisor-requests/' || v_user_id::text || '/%');

  if not exists (
    select 1
    from public.club_supervisor_request_attachments att
    where att.supervisor_request_id = p_request_id
  ) then
    raise exception
      'A teacher signature attachment is required';
  end if;

  return p_request_id;
end;
$$;

revoke all on function public.submit_club_supervisor_request(uuid, uuid, jsonb, jsonb)
from public, anon;

grant execute on function public.submit_club_supervisor_request(uuid, uuid, jsonb, jsonb)
to authenticated;

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
