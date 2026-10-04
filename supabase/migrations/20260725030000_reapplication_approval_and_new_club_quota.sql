-- =========================================================
-- Re-application review + atomic approval
-- Update new-club submit to share daily quota
-- =========================================================

-- Minimal advisors table so approval can activate supervisors.
-- Full supervisor-request workflow is in a later migration.

create table if not exists public.club_advisors (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null
    references public.clubs(id)
    on delete cascade,
  school_year text not null,
  supervisor_name text not null,
  supervisor_email text not null,
  status text not null default 'ACTIVE',
  approved_from_request_id uuid,
  approved_by uuid
    references public.profiles(id)
    on delete set null,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint club_advisors_name_valid
    check (
      supervisor_name = btrim(supervisor_name)
      and char_length(supervisor_name) between 2 and 120
    ),

  constraint club_advisors_email_pdsb
    check (
      supervisor_email = lower(btrim(supervisor_email))
      and supervisor_email ~ '^[^[:space:]@]+@pdsb[.]net$'
    ),

  constraint club_advisors_status_valid
    check (status in ('ACTIVE', 'INACTIVE'))
);

create unique index if not exists club_advisors_active_email_uidx
  on public.club_advisors (club_id, school_year, supervisor_email)
  where status = 'ACTIVE';

create index if not exists club_advisors_club_year_idx
  on public.club_advisors (club_id, school_year);

drop trigger if exists set_club_advisors_updated_at on public.club_advisors;
create trigger set_club_advisors_updated_at
before update on public.club_advisors
for each row
execute function public.set_updated_at();

alter table public.club_advisors enable row level security;

revoke all on table public.club_advisors from public, anon;
grant select on table public.club_advisors to authenticated;

drop policy if exists "club_advisors_select_members" on public.club_advisors;
create policy "club_advisors_select_members"
on public.club_advisors
for select
to authenticated
using (
  public.has_club_role(club_id, array['OWNER', 'EXEC', 'MEMBER'])
  or public.has_system_role('SAC_ADMIN')
  or public.has_system_role('SAC_EXEC')
);


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
    v_logo_url := v_req.proposed_logo_storage_path;
  end if;

  v_schedule := case
    when cardinality(v_req.meeting_days) > 0 then
      v_req.meeting_frequency || ' · ' || array_to_string(v_req.meeting_days, ', ')
      || coalesce(' · ' || nullif(v_req.meeting_time_details, ''), '')
    else
      v_req.meeting_frequency
      || coalesce(' · ' || nullif(v_req.meeting_time_details, ''), '')
  end;

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
    approved_at = coalesce(approved_at, v_approved_at)
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


create or replace function public.review_club_reapplication(
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
  v_req public.club_reapplication_requests%rowtype;
  v_action text;
  v_notes text;
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

  select * into v_req
  from public.club_reapplication_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Request not found';
  end if;

  if v_action = 'UNDER_REVIEW' then
    if v_req.status not in ('SUBMITTED', 'UNDER_REVIEW') then
      raise exception 'Request cannot be marked under review from %', v_req.status;
    end if;
    update public.club_reapplication_requests
    set status = 'UNDER_REVIEW',
        reviewed_by = v_user_id,
        reviewed_at = now(),
        review_notes = coalesce(v_notes, review_notes)
    where id = p_request_id;

  elsif v_action = 'CHANGES_REQUESTED' then
    if v_notes is null then
      raise exception 'Review notes are required when requesting changes';
    end if;
    if v_req.status not in ('SUBMITTED', 'UNDER_REVIEW', 'CHANGES_REQUESTED') then
      raise exception 'Cannot request changes from status %', v_req.status;
    end if;
    update public.club_reapplication_requests
    set status = 'CHANGES_REQUESTED',
        review_notes = v_notes,
        reviewed_by = v_user_id,
        reviewed_at = now()
    where id = p_request_id;

  elsif v_action = 'REJECTED' then
    if v_notes is null then
      raise exception 'Review notes are required when rejecting';
    end if;
    if v_req.status not in ('SUBMITTED', 'UNDER_REVIEW', 'CHANGES_REQUESTED') then
      raise exception 'Cannot reject from status %', v_req.status;
    end if;
    update public.club_reapplication_requests
    set status = 'REJECTED',
        review_notes = v_notes,
        reviewed_by = v_user_id,
        reviewed_at = now()
    where id = p_request_id;

  elsif v_action = 'APPROVED' then
    return public.approve_club_reapplication(p_request_id, v_notes);

  else
    raise exception 'Unsupported review action: %', v_action;
  end if;

  return p_request_id;
end;
$$;

revoke all on function public.review_club_reapplication(uuid, text, text)
from public, anon;
grant execute on function public.review_club_reapplication(uuid, text, text)
to authenticated;


create or replace function public.submit_club_registration_application(
  p_request_id uuid,
  p_proposed_name text,
  p_description text,
  p_student_benefit text,
  p_leader_details text,
  p_teacher_supervisor_emails text[],
  p_club_contact_information text,
  p_teacher_supervisor_form_storage_path text,
  p_potential_event_ideas text default null,
  p_leader_contact_information text default null,
  p_school_year text default '2026-2027'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_email text;
  v_emails text[];
  v_path text;
  v_primary_email text;
  v_today date;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_request_id is null then
    raise exception 'Request ID is required';
  end if;

  v_today := public.toronto_local_date(now());

  if exists (
    select 1
    from public.club_application_submission_days d
    where d.user_id = v_user_id
      and d.local_submission_date = v_today
  ) then
    raise exception
      'You may submit only one club application per calendar day (America/Toronto)';
  end if;

  select lower(btrim(email))
  into v_email
  from public.profiles
  where id = v_user_id;

  if v_email is null then
    raise exception 'Profile email is required';
  end if;

  if nullif(btrim(p_proposed_name), '') is null then
    raise exception 'Club name is required';
  end if;

  if nullif(btrim(p_description), '') is null then
    raise exception 'Club description is required';
  end if;

  if nullif(btrim(p_student_benefit), '') is null then
    raise exception 'Student benefit description is required';
  end if;

  if nullif(btrim(p_leader_details), '') is null then
    raise exception 'Club leader details are required';
  end if;

  if nullif(btrim(p_club_contact_information), '') is null then
    raise exception 'Club contact information is required';
  end if;

  v_path := btrim(p_teacher_supervisor_form_storage_path);
  if v_path is null or v_path = '' then
    raise exception 'Signed teacher supervisor form is required';
  end if;

  if v_path not like ('new-club-applications/' || v_user_id::text || '/%') then
    raise exception 'Invalid signed-form storage path'
      using errcode = '42501';
  end if;

  v_emails := coalesce(
    (
      select array_agg(distinct lower(btrim(email_value)))
      from unnest(coalesce(p_teacher_supervisor_emails, '{}'::text[])) as email_value
      where nullif(btrim(email_value), '') is not null
    ),
    '{}'::text[]
  );

  if cardinality(v_emails) < 1 then
    raise exception 'At least one teacher supervisor @pdsb.net email is required';
  end if;

  if exists (
    select 1
    from unnest(v_emails) as email_value
    where email_value !~ '^[^[:space:]@]+@pdsb[.]net$'
  ) then
    raise exception 'Teacher supervisor emails must be exact @pdsb.net addresses';
  end if;

  v_primary_email := v_emails[1];

  insert into public.club_registration_requests (
    id, requested_by, respondent_email, school_year, proposed_name,
    description, purpose, student_benefit, leader_details,
    leader_contact_information, club_contact_information,
    teacher_supervisor_emails, faculty_advisor_email,
    teacher_supervisor_form_storage_path, potential_event_ideas,
    status, submitted_at
  )
  values (
    p_request_id, v_user_id, v_email,
    coalesce(nullif(btrim(p_school_year), ''), public.get_current_club_school_year()),
    btrim(p_proposed_name), btrim(p_description), btrim(p_student_benefit),
    btrim(p_student_benefit), btrim(p_leader_details),
    nullif(btrim(p_leader_contact_information), ''),
    btrim(p_club_contact_information), v_emails, v_primary_email, v_path,
    nullif(btrim(p_potential_event_ideas), ''), 'SUBMITTED', now()
  );

  insert into public.club_application_submission_days (
    user_id, local_submission_date, request_type, request_id
  )
  values (v_user_id, v_today, 'NEW_CLUB', p_request_id);

  return p_request_id;
exception
  when unique_violation then
    raise exception
      'You may submit only one club application per calendar day (America/Toronto)'
      using errcode = '23505';
end;
$$;
