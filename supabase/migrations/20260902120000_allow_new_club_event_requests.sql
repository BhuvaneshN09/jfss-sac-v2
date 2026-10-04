-- Newly approved clubs (ACTIVE or still PENDING_SUPERVISOR) may submit events.

create or replace function public.submit_club_event_request(
  p_request_id uuid,
  p_club_id uuid,
  p_event_name text,
  p_event_description text,
  p_event_start_date date,
  p_event_end_date date,
  p_requested_materials text,
  p_photo_storage_path text default null,
  p_school_year text default '2026-2027'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_applicant_email text;
  v_annual_status text;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select lower(email)
  into v_applicant_email
  from public.profiles
  where id = v_user_id;

  if v_applicant_email is null then
    raise exception 'Profile email is required';
  end if;

  if not public.has_club_role(p_club_id, array['OWNER']) then
    raise exception
      'Only an active club owner may submit an event proposal'
      using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.clubs
    where id = p_club_id
      and status = 'APPROVED'
  ) then
    raise exception 'The selected club is not available';
  end if;

  v_annual_status := public.get_club_current_annual_status(p_club_id);
  if v_annual_status is distinct from 'ACTIVE'
     and v_annual_status is distinct from 'PENDING_SUPERVISOR' then
    raise exception 'Event proposals are available only for this year’s clubs';
  end if;

  if p_event_start_date < (timezone('America/Toronto', now()))::date then
    raise exception 'The event start date cannot be in the past';
  end if;

  if p_event_end_date < p_event_start_date then
    raise exception 'The event end date cannot be before the start date';
  end if;

  if p_photo_storage_path is not null
     and btrim(p_photo_storage_path) <> ''
     and btrim(p_photo_storage_path) not like (
       'event-photos/' || v_user_id::text || '/' || p_request_id::text || '/%'
     ) then
    raise exception 'Invalid event photo storage path' using errcode = '42501';
  end if;

  insert into public.club_event_requests (
    id,
    club_id,
    submitted_by,
    applicant_email,
    school_year,
    event_name,
    event_description,
    event_date,
    event_end_date,
    requested_materials,
    photo_storage_path,
    status,
    submitted_at
  )
  values (
    p_request_id,
    p_club_id,
    v_user_id,
    v_applicant_email,
    coalesce(nullif(btrim(p_school_year), ''), '2026-2027'),
    btrim(p_event_name),
    btrim(p_event_description),
    p_event_start_date,
    p_event_end_date,
    btrim(p_requested_materials),
    nullif(btrim(coalesce(p_photo_storage_path, '')), ''),
    'SUBMITTED',
    now()
  );

  return p_request_id;
end;
$$;
