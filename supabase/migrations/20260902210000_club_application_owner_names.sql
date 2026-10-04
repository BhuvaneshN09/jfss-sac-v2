-- Owner names on new-club and reapplication requests, and on the club record
-- so owners can update them after approval. Existing rows stay NULL.

alter table public.club_registration_requests
  add column if not exists owner_names text;

alter table public.club_reapplication_requests
  add column if not exists owner_names text;

alter table public.clubs
  add column if not exists owner_names text;

create or replace function public.normalize_club_owner_names(
  p_owner_names text,
  p_required boolean default true
)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_names text;
begin
  v_names := nullif(btrim(coalesce(p_owner_names, '')), '');
  if v_names is null then
    if p_required then
      raise exception 'List the full name of every club owner.';
    end if;
    return null;
  end if;
  if char_length(v_names) < 2 then
    raise exception 'List the full name of every club owner.';
  end if;
  if char_length(v_names) > 1000 then
    raise exception 'Keep owner names to 1,000 characters or fewer.';
  end if;
  return v_names;
end;
$$;

revoke all on function public.normalize_club_owner_names(text, boolean)
from public;
grant execute on function public.normalize_club_owner_names(text, boolean)
to authenticated;

create or replace function public.submit_club_registration_application_with_owner_names(
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
  p_member_application_url text,
  p_exec_application_url text,
  p_owner_names text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_request_id uuid;
  v_names text;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  v_names := public.normalize_club_owner_names(p_owner_names, true);

  v_request_id := public.submit_club_registration_application_with_application_urls(
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
    p_faculty_advisor_name,
    p_member_application_url,
    p_exec_application_url
  );

  update public.club_registration_requests
  set owner_names = v_names
  where id = v_request_id
    and requested_by = v_user_id;

  return v_request_id;
end;
$$;

revoke all on function public.submit_club_registration_application_with_owner_names(
  uuid, text, text, text, text, text[], text, text, text, text, text[],
  text, text, text, text, text, text, text, text
) from public, anon;

grant execute on function public.submit_club_registration_application_with_owner_names(
  uuid, text, text, text, text, text[], text, text, text, text, text[],
  text, text, text, text, text, text, text, text
) to authenticated;

create or replace function public.submit_club_reapplication_with_owner_names(
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
  p_member_application_url text,
  p_exec_application_url text,
  p_owner_names text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request_id uuid;
  v_names text;
begin
  v_names := public.normalize_club_owner_names(p_owner_names, true);

  v_request_id := public.submit_club_reapplication_with_application_urls(
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
    p_attachments,
    p_member_application_url,
    p_exec_application_url
  );

  update public.club_reapplication_requests
  set owner_names = v_names
  where id = v_request_id;

  return v_request_id;
end;
$$;

revoke all on function public.submit_club_reapplication_with_owner_names(
  uuid, uuid, text, text, text, text, text, text[], text, text, text,
  boolean, boolean, jsonb, jsonb, text, text, text
) from public, anon;

grant execute on function public.submit_club_reapplication_with_owner_names(
  uuid, uuid, text, text, text, text, text, text[], text, text, text,
  boolean, boolean, jsonb, jsonb, text, text, text
) to authenticated;

create or replace function public.update_club_reapplication_with_owner_names(
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
  p_member_application_url text,
  p_exec_application_url text,
  p_owner_names text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request_id uuid;
  v_names text;
begin
  v_names := public.normalize_club_owner_names(p_owner_names, true);

  v_request_id := public.update_club_reapplication_with_application_urls(
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
    p_attachments,
    p_member_application_url,
    p_exec_application_url
  );

  update public.club_reapplication_requests
  set owner_names = v_names
  where id = v_request_id;

  return v_request_id;
end;
$$;

revoke all on function public.update_club_reapplication_with_owner_names(
  uuid, text, text, text, text, text, text[], text, text, text, boolean,
  boolean, jsonb, jsonb, text, text, text
) from public, anon;

grant execute on function public.update_club_reapplication_with_owner_names(
  uuid, text, text, text, text, text, text[], text, text, text, boolean,
  boolean, jsonb, jsonb, text, text, text
) to authenticated;

create or replace function public.update_owned_club_profile_with_owner_names(
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
  p_member_application_url text,
  p_exec_application_url text,
  p_owner_names text
)
returns public.clubs
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.clubs;
  v_names text;
begin
  v_names := public.normalize_club_owner_names(p_owner_names, false);

  v_row := public.update_owned_club_profile_with_application_urls(
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
    p_meeting_location,
    p_member_application_url,
    p_exec_application_url
  );

  update public.clubs
  set owner_names = v_names,
      updated_at = now()
  where id = p_club_id
  returning * into v_row;

  return v_row;
end;
$$;

revoke all on function public.update_owned_club_profile_with_owner_names(
  uuid, text, text, text, text, text, text, text, text[], text, text, text,
  text, text
) from public, anon;

grant execute on function public.update_owned_club_profile_with_owner_names(
  uuid, text, text, text, text, text, text, text, text[], text, text, text,
  text, text
) to authenticated;

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
        exec_application_url = new.exec_application_url,
        owner_names = coalesce(new.owner_names, owner_names),
        updated_at = now()
    where id = new.club_id;
  end if;

  return new;
end;
$$;

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
      exec_application_url = new.exec_application_url,
      owner_names = coalesce(new.owner_names, owner_names),
      updated_at = now()
    where id = new.created_club_id;
  end if;

  return new;
end;
$$;
