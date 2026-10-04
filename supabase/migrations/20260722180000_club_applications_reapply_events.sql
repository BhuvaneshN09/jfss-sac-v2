-- =========================================================
-- Club applications 2026–2027: extra fields, reapplications,
-- event requests, and private signed-form storage.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Extend club_registration_requests for new application form
-- ---------------------------------------------------------

alter table public.club_registration_requests
  add column if not exists school_year text,
  add column if not exists respondent_email text,
  add column if not exists student_benefit text,
  add column if not exists potential_event_ideas text,
  add column if not exists leader_details text,
  add column if not exists leader_contact_information text,
  add column if not exists club_contact_information text,
  add column if not exists teacher_supervisor_emails text[],
  add column if not exists teacher_supervisor_form_storage_path text;

update public.club_registration_requests
set school_year = coalesce(school_year, '2026-2027')
where school_year is null;

alter table public.club_registration_requests
  alter column school_year set default '2026-2027';

alter table public.club_registration_requests
  drop constraint if exists club_requests_school_year_not_blank;

alter table public.club_registration_requests
  add constraint club_requests_school_year_not_blank
  check (school_year is null or length(btrim(school_year)) > 0);


-- ---------------------------------------------------------
-- 2. Private storage bucket for signed teacher forms
-- ---------------------------------------------------------

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'club-application-documents',
  'club-application-documents',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "club_docs_select_own"
on storage.objects;
drop policy if exists "club_docs_insert_own"
on storage.objects;
drop policy if exists "club_docs_update_own"
on storage.objects;
drop policy if exists "club_docs_delete_own"
on storage.objects;
drop policy if exists "club_docs_select_sac_admin"
on storage.objects;

create policy "club_docs_select_own"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'club-application-documents'
  and (storage.foldername(name))[1] in (
    'new-club-applications',
    'club-reapplications'
  )
  and (storage.foldername(name))[2] = (select auth.uid())::text
);

create policy "club_docs_insert_own"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'club-application-documents'
  and (storage.foldername(name))[1] in (
    'new-club-applications',
    'club-reapplications'
  )
  and (storage.foldername(name))[2] = (select auth.uid())::text
);

create policy "club_docs_update_own"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'club-application-documents'
  and (storage.foldername(name))[1] in (
    'new-club-applications',
    'club-reapplications'
  )
  and (storage.foldername(name))[2] = (select auth.uid())::text
)
with check (
  bucket_id = 'club-application-documents'
  and (storage.foldername(name))[1] in (
    'new-club-applications',
    'club-reapplications'
  )
  and (storage.foldername(name))[2] = (select auth.uid())::text
);

create policy "club_docs_delete_own"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'club-application-documents'
  and (storage.foldername(name))[1] in (
    'new-club-applications',
    'club-reapplications'
  )
  and (storage.foldername(name))[2] = (select auth.uid())::text
);

create policy "club_docs_select_sac_admin"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'club-application-documents'
  and public.has_system_role('SAC_ADMIN')
);


-- ---------------------------------------------------------
-- 3. Club re-application requests
-- ---------------------------------------------------------

create table if not exists public.club_reapplication_requests (
  id uuid primary key default gen_random_uuid(),
  club_id uuid references public.clubs(id) on delete set null,
  submitted_by uuid not null references public.profiles(id) on delete cascade,
  respondent_email text not null,
  school_year text not null default '2026-2027',
  submitted_club_name text not null,
  club_purpose text not null,
  previous_year_leaders text not null,
  current_year_leaders text not null,
  new_leader_contact_information text not null,
  club_contact_information text not null,
  instagram_handle text not null,
  teacher_supervisor_emails text[] not null default '{}',
  is_seeking_teacher_supervisor boolean not null default false,
  teacher_supervisor_form_storage_path text not null,
  status text not null default 'SUBMITTED',
  review_notes text,
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  submitted_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint club_reapp_status_valid
    check (status in (
      'DRAFT',
      'SUBMITTED',
      'UNDER_REVIEW',
      'CHANGES_REQUESTED',
      'APPROVED',
      'REJECTED',
      'WITHDRAWN'
    )),

  constraint club_reapp_school_year_not_blank
    check (length(btrim(school_year)) > 0),

  constraint club_reapp_club_name_not_blank
    check (length(btrim(submitted_club_name)) > 0),

  constraint club_reapp_purpose_not_blank
    check (length(btrim(club_purpose)) > 0),

  constraint club_reapp_form_path_not_blank
    check (length(btrim(teacher_supervisor_form_storage_path)) > 0),

  constraint club_reapp_supervisor_rule
    check (
      (
        is_seeking_teacher_supervisor = true
        and coalesce(cardinality(teacher_supervisor_emails), 0) = 0
      )
      or (
        is_seeking_teacher_supervisor = false
        and cardinality(teacher_supervisor_emails) >= 1
      )
    )
);

create unique index if not exists club_reapp_active_club_year_uidx
on public.club_reapplication_requests (club_id, school_year)
where
  club_id is not null
  and status in ('SUBMITTED', 'UNDER_REVIEW', 'CHANGES_REQUESTED', 'APPROVED');

create index if not exists club_reapp_submitted_by_idx
on public.club_reapplication_requests (submitted_by);

create index if not exists club_reapp_status_idx
on public.club_reapplication_requests (status, submitted_at desc);

drop trigger if exists set_club_reapplication_requests_updated_at
on public.club_reapplication_requests;

create trigger set_club_reapplication_requests_updated_at
before update on public.club_reapplication_requests
for each row
execute function public.set_updated_at();

alter table public.club_reapplication_requests enable row level security;

revoke all on table public.club_reapplication_requests from public, anon;
grant select, insert, update, delete
on table public.club_reapplication_requests
to authenticated;

drop policy if exists "club_reapp_select_own"
on public.club_reapplication_requests;
drop policy if exists "club_reapp_insert_own"
on public.club_reapplication_requests;
drop policy if exists "club_reapp_update_own"
on public.club_reapplication_requests;
drop policy if exists "club_reapp_select_sac_admin"
on public.club_reapplication_requests;

create policy "club_reapp_select_own"
on public.club_reapplication_requests
for select
to authenticated
using (submitted_by = (select auth.uid()));

create policy "club_reapp_insert_own"
on public.club_reapplication_requests
for insert
to authenticated
with check (
  submitted_by = (select auth.uid())
  and status in ('DRAFT', 'SUBMITTED')
);

create policy "club_reapp_update_own"
on public.club_reapplication_requests
for update
to authenticated
using (
  submitted_by = (select auth.uid())
  and status in ('DRAFT', 'CHANGES_REQUESTED')
)
with check (
  submitted_by = (select auth.uid())
  and status in ('DRAFT', 'SUBMITTED', 'WITHDRAWN')
);

create policy "club_reapp_select_sac_admin"
on public.club_reapplication_requests
for select
to authenticated
using (public.has_system_role('SAC_ADMIN'));


-- ---------------------------------------------------------
-- 4. Club event requests
-- ---------------------------------------------------------

create table if not exists public.club_event_requests (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  submitted_by uuid not null references public.profiles(id) on delete cascade,
  respondent_email text not null,
  school_year text not null default '2026-2027',
  club_email text not null,
  event_name text not null,
  event_details text not null,
  requested_materials text not null,
  status text not null default 'SUBMITTED',
  review_notes text,
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  submitted_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint club_event_status_valid
    check (status in (
      'DRAFT',
      'SUBMITTED',
      'UNDER_REVIEW',
      'CHANGES_REQUESTED',
      'APPROVED',
      'REJECTED',
      'WITHDRAWN'
    )),

  constraint club_event_name_not_blank
    check (length(btrim(event_name)) > 0),

  constraint club_event_details_not_blank
    check (length(btrim(event_details)) > 0),

  constraint club_event_materials_not_blank
    check (length(btrim(requested_materials)) > 0),

  constraint club_event_email_lowercase
    check (club_email = lower(club_email))
);

create index if not exists club_event_club_id_idx
on public.club_event_requests (club_id);

create index if not exists club_event_submitted_by_idx
on public.club_event_requests (submitted_by);

create index if not exists club_event_status_idx
on public.club_event_requests (status, submitted_at desc);

drop trigger if exists set_club_event_requests_updated_at
on public.club_event_requests;

create trigger set_club_event_requests_updated_at
before update on public.club_event_requests
for each row
execute function public.set_updated_at();

alter table public.club_event_requests enable row level security;

revoke all on table public.club_event_requests from public, anon;
grant select, insert
on table public.club_event_requests
to authenticated;

drop policy if exists "club_event_select_own"
on public.club_event_requests;
drop policy if exists "club_event_select_club_leader"
on public.club_event_requests;
drop policy if exists "club_event_select_sac_admin"
on public.club_event_requests;
drop policy if exists "club_event_insert_blocked"
on public.club_event_requests;

-- Inserts go through SECURITY DEFINER RPC only.
create policy "club_event_select_own"
on public.club_event_requests
for select
to authenticated
using (submitted_by = (select auth.uid()));

create policy "club_event_select_club_leader"
on public.club_event_requests
for select
to authenticated
using (
  public.has_club_role(club_id, array['OWNER', 'EXEC'])
);

create policy "club_event_select_sac_admin"
on public.club_event_requests
for select
to authenticated
using (public.has_system_role('SAC_ADMIN'));


-- ---------------------------------------------------------
-- 5. Submit new club application (server-side identity)
-- ---------------------------------------------------------

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
    id,
    requested_by,
    respondent_email,
    school_year,
    proposed_name,
    description,
    purpose,
    student_benefit,
    leader_details,
    leader_contact_information,
    club_contact_information,
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
    coalesce(nullif(btrim(p_school_year), ''), '2026-2027'),
    btrim(p_proposed_name),
    btrim(p_description),
    btrim(p_student_benefit),
    btrim(p_student_benefit),
    btrim(p_leader_details),
    nullif(btrim(p_leader_contact_information), ''),
    btrim(p_club_contact_information),
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

revoke all
on function public.submit_club_registration_application(
  uuid, text, text, text, text, text[], text, text, text, text, text
)
from public, anon, authenticated;

grant execute
on function public.submit_club_registration_application(
  uuid, text, text, text, text, text[], text, text, text, text, text
)
to authenticated;


-- ---------------------------------------------------------
-- 6. Submit / review club re-application (SAC_ADMIN only review)
-- ---------------------------------------------------------

create or replace function public.submit_club_reapplication_request(
  p_request_id uuid,
  p_club_id uuid,
  p_submitted_club_name text,
  p_club_purpose text,
  p_previous_year_leaders text,
  p_current_year_leaders text,
  p_new_leader_contact_information text,
  p_club_contact_information text,
  p_instagram_handle text,
  p_teacher_supervisor_emails text[],
  p_is_seeking_teacher_supervisor boolean,
  p_teacher_supervisor_form_storage_path text,
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
  v_seeking boolean;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select lower(btrim(email))
  into v_email
  from public.profiles
  where id = v_user_id;

  if v_email is null then
    raise exception 'Profile email is required';
  end if;

  v_seeking := coalesce(p_is_seeking_teacher_supervisor, false);
  v_path := btrim(p_teacher_supervisor_form_storage_path);

  if v_path is null or v_path = '' then
    raise exception 'Signed teacher supervisor form is required';
  end if;

  if v_path not like ('club-reapplications/' || v_user_id::text || '/%') then
    raise exception 'Invalid signed-form storage path'
      using errcode = '42501';
  end if;

  if p_club_id is not null
     and not exists (
       select 1 from public.clubs where id = p_club_id and status = 'APPROVED'
     ) then
    raise exception 'Selected club was not found or is unavailable';
  end if;

  v_emails := coalesce(
    (
      select array_agg(distinct lower(btrim(email_value)))
      from unnest(coalesce(p_teacher_supervisor_emails, '{}'::text[])) as email_value
      where nullif(btrim(email_value), '') is not null
    ),
    '{}'::text[]
  );

  if v_seeking then
    v_emails := '{}'::text[];
  else
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
  end if;

  insert into public.club_reapplication_requests (
    id,
    club_id,
    submitted_by,
    respondent_email,
    school_year,
    submitted_club_name,
    club_purpose,
    previous_year_leaders,
    current_year_leaders,
    new_leader_contact_information,
    club_contact_information,
    instagram_handle,
    teacher_supervisor_emails,
    is_seeking_teacher_supervisor,
    teacher_supervisor_form_storage_path,
    status,
    submitted_at
  )
  values (
    coalesce(p_request_id, gen_random_uuid()),
    p_club_id,
    v_user_id,
    v_email,
    coalesce(nullif(btrim(p_school_year), ''), '2026-2027'),
    btrim(p_submitted_club_name),
    btrim(p_club_purpose),
    btrim(p_previous_year_leaders),
    btrim(p_current_year_leaders),
    btrim(p_new_leader_contact_information),
    btrim(p_club_contact_information),
    btrim(p_instagram_handle),
    v_emails,
    v_seeking,
    v_path,
    'SUBMITTED',
    now()
  )
  returning id into p_request_id;

  return p_request_id;
end;
$$;

revoke all
on function public.submit_club_reapplication_request(
  uuid, uuid, text, text, text, text, text, text, text, text[], boolean, text, text
)
from public, anon, authenticated;

grant execute
on function public.submit_club_reapplication_request(
  uuid, uuid, text, text, text, text, text, text, text, text[], boolean, text, text
)
to authenticated;


create or replace function public.review_club_reapplication_request(
  p_request_id uuid,
  p_action text,
  p_review_notes text default null,
  p_confirmed_club_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin_id uuid;
  v_action text;
  v_request public.club_reapplication_requests%rowtype;
begin
  v_admin_id := (select auth.uid());
  if v_admin_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not public.has_system_role('SAC_ADMIN') then
    raise exception
      'Only SAC administrators may review club re-applications'
      using errcode = '42501';
  end if;

  v_action := upper(btrim(p_action));

  select *
  into v_request
  from public.club_reapplication_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Club re-application not found';
  end if;

  if v_action = 'UNDER_REVIEW' then
    if v_request.status <> 'SUBMITTED' then
      raise exception 'Only submitted re-applications may be marked under review';
    end if;

    update public.club_reapplication_requests
    set
      status = 'UNDER_REVIEW',
      reviewed_by = v_admin_id,
      reviewed_at = now(),
      club_id = coalesce(p_confirmed_club_id, club_id)
    where id = p_request_id;

  elsif v_action = 'CHANGES_REQUESTED' then
    if v_request.status not in ('SUBMITTED', 'UNDER_REVIEW') then
      raise exception 'This re-application cannot be returned for changes';
    end if;

    if nullif(btrim(p_review_notes), '') is null then
      raise exception 'Review notes are required when requesting changes';
    end if;

    update public.club_reapplication_requests
    set
      status = 'CHANGES_REQUESTED',
      review_notes = btrim(p_review_notes),
      reviewed_by = v_admin_id,
      reviewed_at = now(),
      club_id = coalesce(p_confirmed_club_id, club_id)
    where id = p_request_id;

  elsif v_action = 'REJECTED' then
    if v_request.status not in ('SUBMITTED', 'UNDER_REVIEW') then
      raise exception 'This re-application cannot be rejected';
    end if;

    if nullif(btrim(p_review_notes), '') is null then
      raise exception 'Review notes are required when rejecting a re-application';
    end if;

    update public.club_reapplication_requests
    set
      status = 'REJECTED',
      review_notes = btrim(p_review_notes),
      reviewed_by = v_admin_id,
      reviewed_at = now(),
      club_id = coalesce(p_confirmed_club_id, club_id)
    where id = p_request_id;

  elsif v_action = 'APPROVED' then
    if v_request.status not in ('SUBMITTED', 'UNDER_REVIEW') then
      raise exception 'Only submitted or under-review re-applications may be approved';
    end if;

    -- Approval records the 2026–2027 cycle decision only.
    -- It does not reassign OWNER/EXEC memberships from free-text names.
    update public.club_reapplication_requests
    set
      status = 'APPROVED',
      review_notes = nullif(btrim(p_review_notes), ''),
      reviewed_by = v_admin_id,
      reviewed_at = now(),
      club_id = coalesce(p_confirmed_club_id, club_id)
    where id = p_request_id;

  else
    raise exception 'Invalid club re-application review action';
  end if;

  return p_request_id;
end;
$$;

revoke all
on function public.review_club_reapplication_request(uuid, text, text, uuid)
from public, anon, authenticated;

grant execute
on function public.review_club_reapplication_request(uuid, text, text, uuid)
to authenticated;


-- ---------------------------------------------------------
-- 7. Submit / review club event requests (SAC_ADMIN review)
-- ---------------------------------------------------------

create or replace function public.submit_club_event_request(
  p_club_id uuid,
  p_club_email text,
  p_event_name text,
  p_event_details text,
  p_requested_materials text,
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
  v_request_id uuid;
  v_club_email text;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_club_id is null then
    raise exception 'Club ID is required';
  end if;

  if not public.has_club_role(p_club_id, array['OWNER', 'EXEC']) then
    raise exception
      'Only active club owners and executives may submit event requests'
      using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.clubs
    where id = p_club_id
      and status = 'APPROVED'
  ) then
    raise exception 'Club not found or unavailable';
  end if;

  select lower(btrim(email))
  into v_email
  from public.profiles
  where id = v_user_id;

  if v_email is null then
    raise exception 'Profile email is required';
  end if;

  v_club_email := lower(btrim(p_club_email));
  if v_club_email is null or v_club_email = '' then
    raise exception 'Club email is required';
  end if;

  if nullif(btrim(p_event_name), '') is null then
    raise exception 'Event name is required';
  end if;

  if nullif(btrim(p_event_details), '') is null then
    raise exception 'Event details are required';
  end if;

  if nullif(btrim(p_requested_materials), '') is null then
    raise exception 'Requested materials are required';
  end if;

  insert into public.club_event_requests (
    club_id,
    submitted_by,
    respondent_email,
    school_year,
    club_email,
    event_name,
    event_details,
    requested_materials,
    status,
    submitted_at
  )
  values (
    p_club_id,
    v_user_id,
    v_email,
    coalesce(nullif(btrim(p_school_year), ''), '2026-2027'),
    v_club_email,
    btrim(p_event_name),
    btrim(p_event_details),
    btrim(p_requested_materials),
    'SUBMITTED',
    now()
  )
  returning id into v_request_id;

  return v_request_id;
end;
$$;

revoke all
on function public.submit_club_event_request(uuid, text, text, text, text, text)
from public, anon, authenticated;

grant execute
on function public.submit_club_event_request(uuid, text, text, text, text, text)
to authenticated;


create or replace function public.review_club_event_request(
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
  v_admin_id uuid;
  v_action text;
  v_request public.club_event_requests%rowtype;
begin
  v_admin_id := (select auth.uid());
  if v_admin_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not public.has_system_role('SAC_ADMIN') then
    raise exception
      'Only SAC administrators may review club event requests'
      using errcode = '42501';
  end if;

  v_action := upper(btrim(p_action));

  select *
  into v_request
  from public.club_event_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Club event request not found';
  end if;

  if v_action = 'UNDER_REVIEW' then
    if v_request.status <> 'SUBMITTED' then
      raise exception 'Only submitted event requests may be marked under review';
    end if;

    update public.club_event_requests
    set
      status = 'UNDER_REVIEW',
      reviewed_by = v_admin_id,
      reviewed_at = now()
    where id = p_request_id;

  elsif v_action = 'CHANGES_REQUESTED' then
    if v_request.status not in ('SUBMITTED', 'UNDER_REVIEW') then
      raise exception 'This event request cannot be returned for changes';
    end if;

    if nullif(btrim(p_review_notes), '') is null then
      raise exception 'Review notes are required when requesting changes';
    end if;

    update public.club_event_requests
    set
      status = 'CHANGES_REQUESTED',
      review_notes = btrim(p_review_notes),
      reviewed_by = v_admin_id,
      reviewed_at = now()
    where id = p_request_id;

  elsif v_action = 'REJECTED' then
    if v_request.status not in ('SUBMITTED', 'UNDER_REVIEW') then
      raise exception 'This event request cannot be rejected';
    end if;

    if nullif(btrim(p_review_notes), '') is null then
      raise exception 'Review notes are required when rejecting an event request';
    end if;

    update public.club_event_requests
    set
      status = 'REJECTED',
      review_notes = btrim(p_review_notes),
      reviewed_by = v_admin_id,
      reviewed_at = now()
    where id = p_request_id;

  elsif v_action = 'APPROVED' then
    if v_request.status not in ('SUBMITTED', 'UNDER_REVIEW') then
      raise exception 'Only submitted or under-review event requests may be approved';
    end if;

    update public.club_event_requests
    set
      status = 'APPROVED',
      review_notes = nullif(btrim(p_review_notes), ''),
      reviewed_by = v_admin_id,
      reviewed_at = now()
    where id = p_request_id;

  else
    raise exception 'Invalid club event review action';
  end if;

  return p_request_id;
end;
$$;

revoke all
on function public.review_club_event_request(uuid, text, text)
from public, anon, authenticated;

grant execute
on function public.review_club_event_request(uuid, text, text)
to authenticated;
