-- Add optional meeting days to new-club applications.

alter table public.club_registration_requests
  add column if not exists meeting_days text[] not null default '{}'::text[];

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'club_requests_meeting_days_valid'
  ) then
    alter table public.club_registration_requests
      add constraint club_requests_meeting_days_valid
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
end;
$$;

drop function if exists public.submit_club_registration_application(
  uuid, text, text, text, text, text[], text, text, text, text, text
);

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
  p_instagram_handle text default null,
  p_meeting_days text[] default '{}'::text[],
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
  v_contact text;
  v_instagram text;
  v_days text[];
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

  v_contact := lower(nullif(btrim(p_club_contact_information), ''));
  if v_contact is null then
    raise exception 'Public club email is required';
  end if;

  if v_contact !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
    raise exception 'Enter a valid public club email';
  end if;

  v_instagram := regexp_replace(
    btrim(coalesce(p_instagram_handle, '')),
    '^@+',
    ''
  );
  if nullif(v_instagram, '') is null then
    raise exception 'Club Instagram handle is required';
  end if;

  v_days := coalesce(p_meeting_days, '{}'::text[]);
  if exists (
    select 1
    from unnest(v_days) as day_name
    where day_name not in (
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday'
    )
  ) then
    raise exception 'Meeting days contain an invalid day';
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
      from unnest(coalesce(p_teacher_supervisor_emails, '{}'::text[]))
        as email_value
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
    id,
    requested_by,
    respondent_email,
    school_year,
    proposed_name,
    description,
    purpose,
    student_benefit,
    leader_details,
    club_contact_information,
    instagram_handle,
    meeting_days,
    teacher_supervisor_emails,
    faculty_advisor_email,
    teacher_supervisor_form_storage_path,
    potential_event_ideas,
    status,
    submitted_at
  )
  values (
    p_request_id,
    v_user_id,
    v_email,
    coalesce(
      nullif(btrim(p_school_year), ''),
      public.get_current_club_school_year()
    ),
    btrim(p_proposed_name),
    btrim(p_description),
    btrim(p_student_benefit),
    btrim(p_student_benefit),
    btrim(p_leader_details),
    v_contact,
    v_instagram,
    v_days,
    v_emails,
    v_primary_email,
    v_path,
    nullif(btrim(p_potential_event_ideas), ''),
    'SUBMITTED',
    now()
  );

  insert into public.club_application_submission_days (
    user_id,
    local_submission_date,
    request_type,
    request_id
  )
  values (
    v_user_id,
    v_today,
    'NEW_CLUB',
    p_request_id
  );

  return p_request_id;
exception
  when unique_violation then
    raise exception
      'You may submit only one club application per calendar day (America/Toronto)'
      using errcode = '23505';
end;
$$;

revoke all on function public.submit_club_registration_application(
  uuid, text, text, text, text, text[], text, text, text, text, text[], text
) from public, anon;

grant execute on function public.submit_club_registration_application(
  uuid, text, text, text, text, text[], text, text, text, text, text[], text
) to authenticated;

-- Sync newly approved applications into the public club record, regardless of
-- which earlier approval-function revision is installed.
create or replace function public.sync_new_club_application_details()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.created_club_id is not null and new.status = 'APPROVED' then
    update public.clubs
    set
      contact_email = coalesce(
        nullif(lower(btrim(new.club_contact_information)), ''),
        contact_email
      ),
      instagram_handle = coalesce(
        nullif(btrim(new.instagram_handle), ''),
        instagram_handle
      ),
      meeting_frequency = case
        when cardinality(coalesce(new.meeting_days, '{}'::text[])) > 0
          then 'Weekly'
        else 'Other'
      end,
      meeting_days = coalesce(new.meeting_days, '{}'::text[]),
      meeting_schedule = nullif(
        array_to_string(coalesce(new.meeting_days, '{}'::text[]), ', '),
        ''
      ),
      updated_at = now()
    where id = new.created_club_id;
  end if;

  return new;
end;
$$;

drop trigger if exists sync_new_club_application_details_trigger
on public.club_registration_requests;

create trigger sync_new_club_application_details_trigger
after update of status, created_club_id
on public.club_registration_requests
for each row
when (new.status = 'APPROVED' and new.created_club_id is not null)
execute function public.sync_new_club_application_details();

revoke all on function public.sync_new_club_application_details()
from public, anon, authenticated;
