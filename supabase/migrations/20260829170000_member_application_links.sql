-- Add optional member-application links to club applications and club profiles.

alter table public.clubs
  add column if not exists member_application_url text;

alter table public.club_registration_requests
  add column if not exists member_application_url text;

alter table public.club_reapplication_requests
  add column if not exists member_application_url text;

-- New-club submission wrapper with the optional member-application link.
create or replace function public.submit_club_registration_application_with_member_url(
  p_request_id uuid,
  p_proposed_name text,
  p_description text,
  p_student_benefit text,
  p_leader_details text,
  p_teacher_supervisor_emails text[],
  p_club_contact_information text,
  p_teacher_supervisor_form_storage_path text,
  p_potential_event_ideas text,
  p_instagram_handle text,
  p_meeting_days text[],
  p_meeting_time_details text,
  p_meeting_location text,
  p_logo_storage_path text,
  p_school_year text,
  p_faculty_advisor_name text,
  p_member_application_url text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_request_id uuid;
  v_url text;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  v_url := nullif(btrim(coalesce(p_member_application_url, '')), '');
  if v_url is not null
     and v_url !~ '^https?://[^[:space:]]+$' then
    raise exception 'Enter a valid member application link.';
  end if;

  v_request_id := public.submit_club_registration_application_with_details(
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
    p_meeting_time_details,
    p_meeting_location,
    p_logo_storage_path,
    p_school_year,
    p_faculty_advisor_name
  );

  perform set_config(
    'app.allow_registration_request_details_update',
    'on',
    true
  );

  update public.club_registration_requests
  set member_application_url = v_url
  where id = v_request_id
    and requested_by = v_user_id;

  return v_request_id;
end;
$$;

revoke all on function public.submit_club_registration_application_with_member_url(
  uuid, text, text, text, text, text[], text, text, text, text, text[],
  text, text, text, text, text, text
) from public, anon;

grant execute on function public.submit_club_registration_application_with_member_url(
  uuid, text, text, text, text, text[], text, text, text, text, text[],
  text, text, text, text, text, text
) to authenticated;

-- Re-application submission with the optional member-application link.
create or replace function public.submit_club_reapplication_with_member_url(
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
  p_supervisors jsonb,
  p_attachments jsonb,
  p_member_application_url text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request_id uuid;
  v_url text;
begin
  v_url := nullif(btrim(coalesce(p_member_application_url, '')), '');
  if v_url is not null
     and v_url !~ '^https?://[^[:space:]]+$' then
    raise exception 'Enter a valid member application link.';
  end if;

  v_request_id := public.submit_club_reapplication(
    p_request_id,
    p_club_id,
    p_short_description,
    p_description,
    p_public_email,
    p_instagram_handle,
    p_meeting_frequency,
    p_meeting_days,
    p_meeting_time_details,
    p_meeting_location,
    p_proposed_logo_storage_path,
    p_is_seeking_teacher_supervisor,
    p_declaration_accepted,
    p_supervisors,
    p_attachments
  );

  update public.club_reapplication_requests
  set member_application_url = v_url
  where id = v_request_id;

  return v_request_id;
end;
$$;

revoke all on function public.submit_club_reapplication_with_member_url(
  uuid, uuid, text, text, text, text, text, text[], text, text, text,
  boolean, boolean, jsonb, jsonb, text
) from public, anon;

grant execute on function public.submit_club_reapplication_with_member_url(
  uuid, uuid, text, text, text, text, text, text[], text, text, text,
  boolean, boolean, jsonb, jsonb, text
) to authenticated;

-- Re-application edits with the optional member-application link.
create or replace function public.update_club_reapplication_with_member_url(
  p_request_id uuid,
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
  p_supervisors jsonb,
  p_attachments jsonb,
  p_member_application_url text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request_id uuid;
  v_url text;
begin
  v_url := nullif(btrim(coalesce(p_member_application_url, '')), '');
  if v_url is not null
     and v_url !~ '^https?://[^[:space:]]+$' then
    raise exception 'Enter a valid member application link.';
  end if;

  v_request_id := public.update_club_reapplication(
    p_request_id,
    p_short_description,
    p_description,
    p_public_email,
    p_instagram_handle,
    p_meeting_frequency,
    p_meeting_days,
    p_meeting_time_details,
    p_meeting_location,
    p_proposed_logo_storage_path,
    p_is_seeking_teacher_supervisor,
    p_declaration_accepted,
    p_supervisors,
    p_attachments
  );

  update public.club_reapplication_requests
  set member_application_url = v_url
  where id = v_request_id;

  return v_request_id;
end;
$$;

revoke all on function public.update_club_reapplication_with_member_url(
  uuid, text, text, text, text, text, text[], text, text, text, boolean,
  boolean, jsonb, jsonb, text
) from public, anon;

grant execute on function public.update_club_reapplication_with_member_url(
  uuid, text, text, text, text, text, text[], text, text, text, boolean,
  boolean, jsonb, jsonb, text
) to authenticated;

-- Manage Club update with the same optional link.
create or replace function public.update_owned_club_profile_with_member_url(
  p_club_id uuid,
  p_name text,
  p_description text,
  p_contact_email text,
  p_leader_contact_information text,
  p_short_description text,
  p_logo_url text,
  p_instagram_handle text,
  p_meeting_days text[],
  p_meeting_time_details text,
  p_meeting_location text,
  p_member_application_url text
)
returns public.clubs
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.clubs;
  v_url text;
begin
  v_url := nullif(btrim(coalesce(p_member_application_url, '')), '');
  if v_url is not null
     and v_url !~ '^https?://[^[:space:]]+$' then
    raise exception 'Enter a valid member application link.';
  end if;

  v_row := public.update_owned_club_profile(
    p_club_id,
    p_name,
    p_description,
    p_contact_email,
    p_leader_contact_information,
    p_short_description,
    p_logo_url,
    p_instagram_handle,
    p_meeting_days,
    p_meeting_time_details,
    p_meeting_location
  );

  update public.clubs
  set member_application_url = v_url
  where id = p_club_id
  returning * into v_row;

  return v_row;
end;
$$;

revoke all on function public.update_owned_club_profile_with_member_url(
  uuid, text, text, text, text, text, text, text, text[], text, text, text
) from public, anon;

grant execute on function public.update_owned_club_profile_with_member_url(
  uuid, text, text, text, text, text, text, text, text[], text, text, text
) to authenticated;

-- Copy the link from an approved re-application to the existing club profile.
create or replace function public.sync_reapplication_member_application_url()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'APPROVED' and new.club_id is not null then
    update public.clubs
    set member_application_url = new.member_application_url,
        updated_at = now()
    where id = new.club_id;
  end if;

  return new;
end;
$$;

drop trigger if exists sync_reapplication_member_application_url_trigger
on public.club_reapplication_requests;

create trigger sync_reapplication_member_application_url_trigger
after update of status on public.club_reapplication_requests
for each row
when (new.status = 'APPROVED')
execute function public.sync_reapplication_member_application_url();

revoke all on function public.sync_reapplication_member_application_url()
from public, anon, authenticated;

-- Copy the link from an approved new-club request to its public club profile.
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
      meeting_time_details = new.meeting_time_details,
      meeting_location = new.meeting_location,
      meeting_schedule = nullif(
        concat_ws(
          ' · ',
          nullif(array_to_string(coalesce(new.meeting_days, '{}'::text[]), ', '), ''),
          nullif(new.meeting_time_details, ''),
          nullif(new.meeting_location, '')
        ),
        ''
      ),
      logo_url = coalesce(new.logo_storage_path, logo_url),
      member_application_url = new.member_application_url,
        updated_at = now()
    where id = new.created_club_id;
  end if;

  return new;
end;
$$;
