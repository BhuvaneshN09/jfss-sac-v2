-- Allow users to submit multiple applications and requests on the same day.

-- The ledger is retained as historical data, but it no longer enforces a
-- one-submission-per-user-per-day rule.
alter table public.club_application_submission_days
  drop constraint if exists club_app_submission_days_user_date_unique;

-- Remove the daily quota check from the current new-club submission RPC.
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
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_request_id is null then
    raise exception 'Request ID is required';
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

  return p_request_id;
end;
$$;

revoke all on function public.submit_club_registration_application(
  uuid, text, text, text, text, text[], text, text, text, text, text[], text
) from public, anon;

grant execute on function public.submit_club_registration_application(
  uuid, text, text, text, text, text[], text, text, text, text, text[], text
) to authenticated;

-- Remove the daily quota check from re-application submissions. The existing
-- club/year conflict remains intentional: one active re-application per club
-- and school year is still required for consistent review state.
create or replace function public.submit_club_reapplication(
  p_request_id uuid,
  p_club_id uuid,
  p_short_description text,
  p_description text,
  p_public_email text,
  p_instagram_handle text,
  p_meeting_frequency text,
  p_meeting_days text[],
  p_meeting_time_details text,
  p_meeting_location text,
  p_proposed_logo_storage_path text,
  p_is_seeking_teacher_supervisor boolean,
  p_declaration_accepted boolean,
  p_supervisors jsonb default '[]'::jsonb,
  p_attachments jsonb default '[]'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_email text;
  v_year text;
  v_request_id uuid;
  v_club public.clubs%rowtype;
  v_annual public.club_school_years%rowtype;
  v_days text[];
  v_sup jsonb;
  v_att jsonb;
  v_sup_count int;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_request_id is null then
    raise exception 'Request ID is required';
  end if;

  v_request_id := p_request_id;

  if coalesce(p_declaration_accepted, false) is not true then
    raise exception 'Declaration must be accepted';
  end if;

  select lower(btrim(email)) into v_email
  from public.profiles
  where id = v_user_id;

  if v_email is null then
    raise exception 'Profile email is required';
  end if;

  v_year := public.get_current_club_school_year();

  select * into v_club
  from public.clubs
  where id = p_club_id
  for update;

  if not found then
    raise exception 'Club not found';
  end if;

  if v_club.eligible_for_reapplication is not true then
    raise exception 'This club is not eligible for re-application';
  end if;

  select * into v_annual
  from public.club_school_years
  where club_id = p_club_id
    and school_year = v_year
  for update;

  if not found or v_annual.status <> 'INACTIVE' then
    raise exception
      'This club is not currently available for re-application';
  end if;

  if exists (
    select 1
    from public.club_reapplication_requests r
    where r.club_id = p_club_id
      and r.school_year = v_year
      and r.status in (
        'SUBMITTED',
        'UNDER_REVIEW',
        'CHANGES_REQUESTED',
        'APPROVED'
      )
  ) then
    raise exception
      'A re-application for this club is already in progress'
      using errcode = '23505';
  end if;

  v_days := coalesce(
    (
      select array_agg(distinct d order by d)
      from unnest(coalesce(p_meeting_days, '{}'::text[])) as d
      where d in ('Monday','Tuesday','Wednesday','Thursday','Friday')
    ),
    '{}'::text[]
  );

  if p_meeting_frequency in ('Weekly', 'Biweekly')
     and cardinality(v_days) < 1 then
    raise exception 'At least one meeting day is required for Weekly/Biweekly';
  end if;

  if nullif(lower(btrim(p_public_email)), '') is null
     or lower(btrim(p_public_email)) !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
    raise exception 'A valid public club email is required';
  end if;

  if p_proposed_logo_storage_path is not null
     and btrim(p_proposed_logo_storage_path) <> ''
     and btrim(p_proposed_logo_storage_path)
         not like ('reapplication-logos/' || v_user_id::text || '/%') then
    raise exception 'Invalid logo storage path' using errcode = '42501';
  end if;

  v_sup := coalesce(p_supervisors, '[]'::jsonb);
  if jsonb_typeof(v_sup) <> 'array' then
    raise exception 'Supervisors must be an array';
  end if;
  v_sup_count := jsonb_array_length(v_sup);

  if coalesce(p_is_seeking_teacher_supervisor, false) then
    if v_sup_count > 3 then
      raise exception 'At most three supervisors are allowed';
    end if;
  else
    if v_sup_count < 1 or v_sup_count > 3 then
      raise exception
        'Provide one to three teacher supervisors, or mark that you are still searching';
    end if;
  end if;

  insert into public.club_reapplication_requests (
    id,
    club_id,
    school_year,
    requested_by,
    applicant_email,
    short_description,
    description,
    public_email,
    instagram_handle,
    meeting_frequency,
    meeting_days,
    meeting_time_details,
    meeting_location,
    proposed_logo_storage_path,
    is_seeking_teacher_supervisor,
    declaration_accepted,
    status,
    submitted_at
  )
  values (
    v_request_id,
    p_club_id,
    v_year,
    v_user_id,
    v_email,
    btrim(p_short_description),
    btrim(p_description),
    lower(btrim(p_public_email)),
    nullif(btrim(coalesce(p_instagram_handle, '')), ''),
    p_meeting_frequency,
    v_days,
    nullif(btrim(coalesce(p_meeting_time_details, '')), ''),
    nullif(btrim(coalesce(p_meeting_location, '')), ''),
    nullif(btrim(coalesce(p_proposed_logo_storage_path, '')), ''),
    coalesce(p_is_seeking_teacher_supervisor, false),
    true,
    'SUBMITTED',
    now()
  );

  insert into public.club_reapplication_supervisors (
    request_id, supervisor_name, supervisor_email
  )
  select
    v_request_id,
    btrim(s->>'name'),
    lower(btrim(s->>'email'))
  from jsonb_array_elements(v_sup) as s
  where nullif(btrim(coalesce(s->>'name', '')), '') is not null
    and nullif(btrim(coalesce(s->>'email', '')), '') is not null;

  if not coalesce(p_is_seeking_teacher_supervisor, false)
     and not exists (
       select 1 from public.club_reapplication_supervisors
       where request_id = v_request_id
     ) then
    raise exception 'At least one complete supervisor entry is required';
  end if;

  v_att := coalesce(p_attachments, '[]'::jsonb);
  if jsonb_typeof(v_att) = 'array' and jsonb_array_length(v_att) > 0 then
    insert into public.club_reapplication_attachments (
      request_id,
      storage_path,
      original_filename,
      mime_type,
      size_bytes,
      uploaded_by
    )
    select
      v_request_id,
      btrim(a->>'storage_path'),
      btrim(a->>'original_filename'),
      btrim(a->>'mime_type'),
      (a->>'size_bytes')::bigint,
      v_user_id
    from jsonb_array_elements(v_att) as a
    where btrim(coalesce(a->>'storage_path', ''))
          like ('reapplications/' || v_user_id::text || '/' || v_request_id::text || '/%')
       or btrim(coalesce(a->>'storage_path', ''))
          like ('reapplications/' || v_user_id::text || '/%');
  end if;

  return v_request_id;
end;
$$;

revoke all on function public.submit_club_reapplication(
  uuid, uuid, text, text, text, text, text, text[], text, text, text,
  boolean, boolean, jsonb, jsonb
) from public, anon;

grant execute on function public.submit_club_reapplication(
  uuid, uuid, text, text, text, text, text, text[], text, text, text,
  boolean, boolean, jsonb, jsonb
) to authenticated;
