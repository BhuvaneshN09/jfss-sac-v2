-- Persist the new-club form's optional meeting details and logo.

alter table public.club_registration_requests
  add column if not exists meeting_days text[] not null default '{}'::text[],
  add column if not exists meeting_time_details text,
  add column if not exists meeting_location text,
  add column if not exists logo_storage_path text;

drop policy if exists "club_logos_insert_new_application" on storage.objects;
drop policy if exists "club_logos_delete_new_application" on storage.objects;

create policy "club_logos_insert_new_application"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'club-logos'
  and (storage.foldername(name))[1] = 'new-club-logos'
  and (storage.foldername(name))[2] = (select auth.uid())::text
);

create policy "club_logos_delete_new_application"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'club-logos'
  and (storage.foldername(name))[1] = 'new-club-logos'
  and (storage.foldername(name))[2] = (select auth.uid())::text
);

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
  p_school_year text default '2026-2027'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_days text[];
  v_logo text;
  v_request_id uuid;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
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

  v_logo := nullif(btrim(coalesce(p_logo_storage_path, '')), '');
  if v_logo is not null
     and v_logo not like (
       'new-club-logos/' || v_user_id::text || '/' || p_request_id::text || '/%'
     ) then
    raise exception 'Invalid club logo storage path'
      using errcode = '42501';
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

  update public.club_registration_requests
  set
    meeting_days = v_days,
    meeting_time_details = nullif(btrim(coalesce(p_meeting_time_details, '')), ''),
    meeting_location = nullif(btrim(coalesce(p_meeting_location, '')), ''),
    logo_storage_path = v_logo
  where id = v_request_id
    and requested_by = v_user_id;

  return v_request_id;
end;
$$;

revoke all on function public.submit_club_registration_application_with_details(
  uuid, text, text, text, text, text[], text, text, text, text, text[],
  text, text, text, text
) from public, anon;

grant execute on function public.submit_club_registration_application_with_details(
  uuid, text, text, text, text, text[], text, text, text, text, text[],
  text, text, text, text
) to authenticated;

-- Include optional meeting details and logo when an application is approved.
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
      updated_at = now()
    where id = new.created_club_id;
  end if;

  return new;
end;
$$;
