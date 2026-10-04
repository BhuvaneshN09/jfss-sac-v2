-- Require a signed Event Approval Form upload on new event proposals.

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'club-event-signatures',
  'club-event-signatures',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "event_signatures_insert_own" on storage.objects;
create policy "event_signatures_insert_own"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'club-event-signatures'
  and (storage.foldername(name))[1] = 'event-signatures'
  and (storage.foldername(name))[2] = (select auth.uid())::text
);

drop policy if exists "event_signatures_select_allowed" on storage.objects;
create policy "event_signatures_select_allowed"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'club-event-signatures'
  and (
    (storage.foldername(name))[2] = (select auth.uid())::text
    or public.can_read_review_queues()
  )
);

drop policy if exists "event_signatures_delete_allowed" on storage.objects;
create policy "event_signatures_delete_allowed"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'club-event-signatures'
  and (
    (storage.foldername(name))[2] = (select auth.uid())::text
    or public.has_system_role('SAC_ADMIN')
  )
);

alter table public.club_event_requests
  add column if not exists signed_form_storage_path text;

alter table public.club_event_requests
  drop constraint if exists club_event_signed_form_path_valid;

alter table public.club_event_requests
  add constraint club_event_signed_form_path_valid
  check (
    signed_form_storage_path is null
    or (
      length(btrim(signed_form_storage_path)) > 0
      and signed_form_storage_path like 'event-signatures/%'
    )
  );

revoke all on function public.submit_club_event_request(
  uuid, uuid, text, text, date, date, text, text, text, boolean
) from public, anon, authenticated;

drop function if exists public.submit_club_event_request(
  uuid, uuid, text, text, date, date, text, text, text, boolean
);

create or replace function public.submit_club_event_request(
  p_request_id uuid,
  p_club_id uuid,
  p_event_name text,
  p_event_description text,
  p_event_start_date date,
  p_event_end_date date,
  p_requested_materials text,
  p_signed_form_storage_path text,
  p_photo_storage_path text default null,
  p_school_year text default '2026-2027',
  p_is_charitable_event boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_applicant_email text;
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

  perform public.assert_club_operations_allowed(p_club_id);

  if p_event_start_date < (timezone('America/Toronto', now()))::date then
    raise exception 'The event start date cannot be in the past';
  end if;

  if p_event_end_date < p_event_start_date then
    raise exception 'The event end date cannot be before the start date';
  end if;

  if nullif(btrim(p_signed_form_storage_path), '') is null
     or p_signed_form_storage_path not like (
       'event-signatures/' || v_user_id::text || '/' || p_request_id::text || '/%'
     ) then
    raise exception 'Invalid event signature storage path' using errcode = '42501';
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
    signed_form_storage_path,
    is_charitable_event,
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
    btrim(p_signed_form_storage_path),
    coalesce(p_is_charitable_event, false),
    'SUBMITTED',
    now()
  );

  return p_request_id;
end;
$$;

revoke all on function public.submit_club_event_request(
  uuid, uuid, text, text, date, date, text, text, text, text, boolean
) from public, anon;

grant execute on function public.submit_club_event_request(
  uuid, uuid, text, text, date, date, text, text, text, text, boolean
) to authenticated;
