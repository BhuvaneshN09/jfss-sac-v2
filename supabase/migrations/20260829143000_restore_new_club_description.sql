-- Preserve the new-club form's separate Description and Student benefit
-- answers. Both are shown in the executive review view in that order.

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
