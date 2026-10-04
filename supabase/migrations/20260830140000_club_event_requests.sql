-- Club event proposal workflow.

insert into storage.buckets (id, name, public)
values ('club-event-photos', 'club-event-photos', true)
on conflict (id) do update
set public = true;

drop policy if exists "club_event_photos_insert_own" on storage.objects;
create policy "club_event_photos_insert_own"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'club-event-photos'
  and (storage.foldername(name))[1] = 'event-photos'
  and (storage.foldername(name))[2] = (select auth.uid())::text
);

drop policy if exists "club_event_photos_update_own" on storage.objects;
create policy "club_event_photos_update_own"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'club-event-photos'
  and (storage.foldername(name))[1] = 'event-photos'
  and (storage.foldername(name))[2] = (select auth.uid())::text
)
with check (
  bucket_id = 'club-event-photos'
  and (storage.foldername(name))[1] = 'event-photos'
  and (storage.foldername(name))[2] = (select auth.uid())::text
);

drop policy if exists "club_event_photos_delete_own" on storage.objects;
create policy "club_event_photos_delete_own"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'club-event-photos'
  and (storage.foldername(name))[1] = 'event-photos'
  and (storage.foldername(name))[2] = (select auth.uid())::text
);

create table public.club_event_requests (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  submitted_by uuid not null references public.profiles(id) on delete cascade,
  applicant_email text not null,
  school_year text not null default '2026-2027',
  club_email text not null,
  event_name text not null,
  event_description text not null,
  event_date date not null,
  requested_materials text not null,
  photo_storage_path text,
  status text not null default 'SUBMITTED',
  review_notes text,
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  submitted_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint club_event_status_valid
    check (status in ('SUBMITTED', 'APPROVED', 'REJECTED')),
  constraint club_event_name_valid
    check (char_length(btrim(event_name)) between 2 and 160),
  constraint club_event_description_valid
    check (char_length(btrim(event_description)) between 10 and 10000),
  constraint club_event_materials_valid
    check (char_length(btrim(requested_materials)) between 2 and 5000),
  constraint club_event_date_valid
    check (event_date >= date '2020-01-01'),
  constraint club_event_email_lowercase
    check (club_email = lower(btrim(club_email))),
  constraint club_event_photo_path_valid
    check (
      photo_storage_path is null
      or photo_storage_path like 'event-photos/%'
    )
);

create index club_event_requests_club_idx
  on public.club_event_requests (club_id, event_date);

create index club_event_requests_status_idx
  on public.club_event_requests (status, event_date);

create index club_event_requests_submitter_idx
  on public.club_event_requests (submitted_by);

create trigger set_club_event_requests_updated_at
before update on public.club_event_requests
for each row
execute function public.set_updated_at();

alter table public.club_event_requests enable row level security;

revoke all on table public.club_event_requests from public, anon;
grant select on table public.club_event_requests to anon, authenticated;

create policy "club_event_requests_select_own"
on public.club_event_requests
for select
to authenticated
using (submitted_by = (select auth.uid()));

create policy "club_event_requests_select_club_managers"
on public.club_event_requests
for select
to authenticated
using (
  public.has_club_role(club_id, array['OWNER', 'EXEC'])
);

create policy "club_event_requests_select_reviewers"
on public.club_event_requests
for select
to authenticated
using (
  public.can_read_review_queues()
);

create policy "club_event_requests_select_approved_public"
on public.club_event_requests
for select
to anon, authenticated
using (status = 'APPROVED');

create or replace function public.submit_club_event_request(
  p_request_id uuid,
  p_club_id uuid,
  p_club_email text,
  p_event_name text,
  p_event_description text,
  p_event_date date,
  p_requested_materials text,
  p_photo_storage_path text default null,
  p_school_year text default '2026-2027'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_applicant_email text;
  v_annual_status text;
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

  if not exists (
    select 1
    from public.clubs
    where id = p_club_id
      and status = 'APPROVED'
  ) then
    raise exception 'The selected club is not available';
  end if;

  v_annual_status := public.get_club_current_annual_status(p_club_id);
  if v_annual_status is distinct from 'ACTIVE' then
    raise exception 'Event proposals are available only for active clubs';
  end if;

  if nullif(btrim(p_club_email), '') is null
     or lower(btrim(p_club_email))
        !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$' then
    raise exception 'A valid club email is required';
  end if;

  if p_event_date < (timezone('America/Toronto', now()))::date then
    raise exception 'The event date cannot be in the past';
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
    club_email,
    event_name,
    event_description,
    event_date,
    requested_materials,
    photo_storage_path,
    status,
    submitted_at
  )
  values (
    p_request_id,
    p_club_id,
    v_user_id,
    v_applicant_email,
    coalesce(nullif(btrim(p_school_year), ''), '2026-2027'),
    lower(btrim(p_club_email)),
    btrim(p_event_name),
    btrim(p_event_description),
    p_event_date,
    btrim(p_requested_materials),
    nullif(btrim(coalesce(p_photo_storage_path, '')), ''),
    'SUBMITTED',
    now()
  );

  return p_request_id;
end;
$$;

revoke all on function public.submit_club_event_request(
  uuid, uuid, text, text, text, date, text, text, text
) from public, anon;

grant execute on function public.submit_club_event_request(
  uuid, uuid, text, text, text, date, text, text, text
) to authenticated;

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
  v_user_id uuid;
  v_action text;
  v_notes text;
  v_request public.club_event_requests%rowtype;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not public.can_mutate_reviews() then
    raise exception 'Only authorized reviewers may review event proposals'
      using errcode = '42501';
  end if;

  v_action := upper(btrim(p_action));
  v_notes := nullif(btrim(coalesce(p_review_notes, '')), '');

  if v_action not in ('APPROVED', 'REJECTED') then
    raise exception 'Event proposals can only be approved or rejected';
  end if;

  if v_action = 'REJECTED' and v_notes is null then
    raise exception 'Review notes are required when rejecting an event proposal';
  end if;

  select *
  into v_request
  from public.club_event_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Event proposal not found';
  end if;

  if v_request.status <> 'SUBMITTED' then
    raise exception 'This event proposal has already been reviewed';
  end if;

  update public.club_event_requests
  set
    status = v_action,
    review_notes = v_notes,
    reviewed_by = v_user_id,
    reviewed_at = now()
  where id = p_request_id;

  return p_request_id;
end;
$$;

revoke all on function public.review_club_event_request(
  uuid, text, text
) from public, anon;

grant execute on function public.review_club_event_request(
  uuid, text, text
) to authenticated;
