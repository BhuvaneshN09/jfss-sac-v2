-- The secured new-club RPC inserts the request as SUBMITTED, then persists
-- optional details. Allow only that trusted internal update to pass the
-- student edit-state trigger.

create or replace function public.guard_club_registration_request()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  current_user_id uuid;
  is_application_admin boolean;
begin
  current_user_id := (select auth.uid());

  is_application_admin :=
    current_user_id is null
    or public.has_system_role('SAC_ADMIN')
    or public.has_system_role('SITE_ADMIN');

  if tg_op = 'INSERT' then
    if not is_application_admin then
      if new.requested_by is distinct from current_user_id then
        raise exception 'requested_by must be the authenticated user';
      end if;

      if new.status not in ('DRAFT', 'SUBMITTED') then
        raise exception 'New requests must be DRAFT or SUBMITTED';
      end if;

      if new.review_notes is not null
         or new.reviewed_by is not null
         or new.reviewed_at is not null
         or new.created_club_id is not null then
        raise exception 'Students cannot set administrative review fields';
      end if;
    end if;

    if new.status = 'SUBMITTED' then
      new.submitted_at := coalesce(new.submitted_at, now());
    else
      new.submitted_at := null;
    end if;

    return new;
  end if;

  -- This setting is enabled only by the SECURITY DEFINER submission RPC
  -- while it saves the optional fields supplied by the same form submission.
  if current_setting('app.allow_registration_request_details_update', true)
       = 'on' then
    return new;
  end if;

  if not is_application_admin then
    if new.id is distinct from old.id
       or new.requested_by is distinct from old.requested_by
       or new.created_at is distinct from old.created_at then
      raise exception 'Request identity fields cannot be changed';
    end if;

    if new.review_notes is distinct from old.review_notes
       or new.reviewed_by is distinct from old.reviewed_by
       or new.reviewed_at is distinct from old.reviewed_at
       or new.created_club_id is distinct from old.created_club_id then
      raise exception 'Students cannot change administrative review fields';
    end if;

    if old.status not in ('DRAFT', 'CHANGES_REQUESTED') then
      raise exception 'This request can no longer be edited';
    end if;

    if new.status not in ('DRAFT', 'SUBMITTED', 'WITHDRAWN') then
      raise exception 'Invalid student request status change';
    end if;

    if new.submitted_at is distinct from old.submitted_at then
      raise exception 'submitted_at is managed automatically';
    end if;
  end if;

  if new.status = 'SUBMITTED'
     and old.status is distinct from 'SUBMITTED' then
    new.submitted_at := now();
  end if;

  if is_application_admin
     and new.status in ('CHANGES_REQUESTED', 'APPROVED', 'REJECTED')
     and new.status is distinct from old.status then
    new.reviewed_at := coalesce(new.reviewed_at, now());
  end if;

  return new;
end;
$$;

-- Update the current RPC so the trigger bypass is scoped to the optional
-- details update and cannot affect regular student edits.
create or replace function public.submit_club_registration_application_with_details(
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
  p_meeting_time_details text default null,
  p_meeting_location text default null,
  p_logo_storage_path text default null,
  p_school_year text default '2026-2027',
  p_faculty_advisor_name text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_request_id uuid;
  v_faculty_advisor_name text;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  v_faculty_advisor_name := nullif(
    btrim(coalesce(p_faculty_advisor_name, '')),
    ''
  );
  if v_faculty_advisor_name is null then
    raise exception 'Teacher supervisor name is required';
  end if;

  v_request_id := public.submit_club_registration_application(
    p_request_id,
    p_proposed_name,
    p_description,
    p_student_benefit,
    p_leader_details,
    p_teacher_supervisor_emails,
    p_club_contact_information,
    p_teacher_supervisor_form_storage_path,
    p_potential_event_ideas,
    p_instagram_handle,
    p_meeting_days,
    p_school_year
  );

  perform set_config(
    'app.allow_registration_request_details_update',
    'on',
    true
  );

  update public.club_registration_requests
  set
    meeting_days = coalesce(p_meeting_days, '{}'::text[]),
    meeting_time_details = nullif(btrim(coalesce(p_meeting_time_details, '')), ''),
    meeting_location = nullif(btrim(coalesce(p_meeting_location, '')), ''),
    logo_storage_path = nullif(btrim(coalesce(p_logo_storage_path, '')), ''),
    faculty_advisor_name = v_faculty_advisor_name
  where id = v_request_id
    and requested_by = v_user_id;

  return v_request_id;
end;
$$;

revoke all on function public.submit_club_registration_application_with_details(
  uuid, text, text, text, text, text[], text, text, text, text, text[],
  text, text, text, text, text
) from public, anon;

grant execute on function public.submit_club_registration_application_with_details(
  uuid, text, text, text, text, text[], text, text, text, text, text[],
  text, text, text, text, text
) to authenticated;
