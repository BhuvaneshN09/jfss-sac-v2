-- New-club applications use the same contact fields as re-registration:
-- required public email and required Instagram handle.

alter table public.club_registration_requests
  add column if not exists instagram_handle text;

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
  uuid, text, text, text, text, text[], text, text, text, text, text
) from public, anon;

grant execute on function public.submit_club_registration_application(
  uuid, text, text, text, text, text[], text, text, text, text, text
) to authenticated;

-- Ensure approved new clubs receive the submitted public email and Instagram.
create or replace function public.approve_club_registration_request(
  p_request_id uuid,
  p_slug text,
  p_review_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin_id uuid;
  v_request public.club_registration_requests%rowtype;
  v_club_id uuid;
  v_year text;
  v_approved_at timestamptz;
  v_emails text[];
  v_email text;
  v_supervisor_name text;
begin
  v_admin_id := (select auth.uid());

  if v_admin_id is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  if not public.can_mutate_reviews() then
    raise exception
      'Only SAC administrators and faculty advisors may approve clubs'
      using errcode = '42501';
  end if;

  select *
  into v_request
  from public.club_registration_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Club registration request not found';
  end if;

  if v_request.status not in ('SUBMITTED', 'UNDER_REVIEW') then
    raise exception
      'Only submitted or under-review requests may be approved';
  end if;

  v_year := public.get_current_club_school_year();
  v_approved_at := now();

  insert into public.clubs (
    name,
    slug,
    short_description,
    description,
    contact_email,
    instagram_handle,
    meeting_schedule,
    status,
    created_by,
    approved_by,
    approved_at,
    creation_origin,
    is_imported_seed,
    eligible_for_reapplication
  )
  values (
    v_request.proposed_name,
    lower(trim(p_slug)),
    v_request.short_description,
    v_request.description,
    v_request.club_contact_information,
    v_request.instagram_handle,
    null,
    'APPROVED',
    v_request.requested_by,
    v_admin_id,
    v_approved_at,
    'NEW_APPLICATION',
    false,
    false
  )
  returning id into v_club_id;

  insert into public.club_memberships (
    club_id,
    user_id,
    role,
    status,
    added_by
  )
  values (
    v_club_id,
    v_request.requested_by,
    'OWNER',
    'ACTIVE',
    v_admin_id
  );

  insert into public.club_school_years (
    club_id,
    school_year,
    status,
    activated_at
  )
  values (
    v_club_id,
    v_year,
    'ACTIVE',
    v_approved_at
  )
  on conflict (club_id, school_year) do update
  set
    status = 'ACTIVE',
    supervisor_due_at = null,
    activated_at = excluded.activated_at;

  v_emails := coalesce(
    (
      select array_agg(distinct lower(btrim(email_value)))
      from unnest(coalesce(v_request.teacher_supervisor_emails, '{}'::text[]))
        as email_value
      where nullif(btrim(email_value), '') is not null
        and lower(btrim(email_value)) ~ '^[^[:space:]@]+@pdsb[.]net$'
    ),
    '{}'::text[]
  );

  if cardinality(v_emails) = 0
     and nullif(lower(btrim(coalesce(v_request.faculty_advisor_email, ''))), '')
         is not null
     and lower(btrim(v_request.faculty_advisor_email))
         ~ '^[^[:space:]@]+@pdsb[.]net$' then
    v_emails := array[lower(btrim(v_request.faculty_advisor_email))];
  end if;

  foreach v_email in array v_emails
  loop
    v_supervisor_name := initcap(
      replace(split_part(v_email, '@', 1), '.', ' ')
    );
    if char_length(btrim(v_supervisor_name)) < 2 then
      v_supervisor_name := 'Teacher Supervisor';
    end if;

    insert into public.club_advisors (
      club_id,
      school_year,
      supervisor_name,
      supervisor_email,
      status,
      approved_by,
      approved_at
    )
    values (
      v_club_id,
      v_year,
      left(btrim(v_supervisor_name), 120),
      v_email,
      'ACTIVE',
      v_admin_id,
      v_approved_at
    )
    on conflict (club_id, school_year, supervisor_email)
      where (status = 'ACTIVE')
      do nothing;
  end loop;

  update public.club_registration_requests
  set
    status = 'APPROVED',
    review_notes = p_review_notes,
    reviewed_by = v_admin_id,
    reviewed_at = v_approved_at,
    created_club_id = v_club_id
  where id = p_request_id;

  return v_club_id;
end;
$$;
