-- =========================================================
-- Exec Dashboard review authorization
--
-- READ review queues: SAC_ADMIN, FACULTY_ADVISOR, SAC_EXEC
-- MUTATE reviews:     SAC_ADMIN, FACULTY_ADVISOR only
-- SAC_EXEC is read-only.
-- Removes remaining SITE_ADMIN checks from review paths.
-- =========================================================

-- ---------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------

create or replace function public.can_read_review_queues()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    public.has_system_role('SAC_ADMIN')
    or public.has_system_role('FACULTY_ADVISOR')
    or public.has_system_role('SAC_EXEC');
$$;

create or replace function public.can_mutate_reviews()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    public.has_system_role('SAC_ADMIN')
    or public.has_system_role('FACULTY_ADVISOR');
$$;

revoke all
on function public.can_read_review_queues()
from public, anon, authenticated;

revoke all
on function public.can_mutate_reviews()
from public, anon, authenticated;

grant execute
on function public.can_read_review_queues()
to authenticated;

grant execute
on function public.can_mutate_reviews()
to authenticated;


-- ---------------------------------------------------------
-- Club registration request RLS
-- ---------------------------------------------------------

drop policy if exists "club_requests_admin_select_all"
on public.club_registration_requests;

create policy "club_requests_admin_select_all"
on public.club_registration_requests
for select
to authenticated
using (public.can_read_review_queues());

drop policy if exists "club_requests_admin_insert"
on public.club_registration_requests;

create policy "club_requests_admin_insert"
on public.club_registration_requests
for insert
to authenticated
with check (public.can_mutate_reviews());

drop policy if exists "club_requests_admin_update"
on public.club_registration_requests;

create policy "club_requests_admin_update"
on public.club_registration_requests
for update
to authenticated
using (public.can_mutate_reviews())
with check (public.can_mutate_reviews());

drop policy if exists "club_requests_admin_delete"
on public.club_registration_requests;

create policy "club_requests_admin_delete"
on public.club_registration_requests
for delete
to authenticated
using (public.can_mutate_reviews());


-- ---------------------------------------------------------
-- Announcement review-queue SELECT
-- ---------------------------------------------------------

drop policy if exists "announcements_admin_select_all"
on public.announcements;

create policy "announcements_admin_select_all"
on public.announcements
for select
to authenticated
using (public.can_read_review_queues());


-- ---------------------------------------------------------
-- Guard: treat FACULTY_ADVISOR as review mutator (not SAC_EXEC)
-- ---------------------------------------------------------

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

  -- Review mutators may set administrative review fields.
  -- SAC_EXEC is intentionally excluded (read-only).
  is_application_admin :=
    current_user_id is null
    or public.can_mutate_reviews();

  if tg_op = 'INSERT' then
    if not is_application_admin then
      if new.requested_by is distinct from current_user_id then
        raise exception
          'requested_by must be the authenticated user';
      end if;

      if new.status not in ('DRAFT', 'SUBMITTED') then
        raise exception
          'New requests must be DRAFT or SUBMITTED';
      end if;

      if new.review_notes is not null
         or new.reviewed_by is not null
         or new.reviewed_at is not null
         or new.created_club_id is not null then
        raise exception
          'Students cannot set administrative review fields';
      end if;
    end if;

    if new.status = 'SUBMITTED' then
      new.submitted_at := coalesce(new.submitted_at, now());
    else
      new.submitted_at := null;
    end if;

    return new;
  end if;

  if not is_application_admin then
    if new.id is distinct from old.id
       or new.requested_by is distinct from old.requested_by
       or new.created_at is distinct from old.created_at then
      raise exception
        'Request identity fields cannot be changed';
    end if;

    if new.review_notes is distinct from old.review_notes
       or new.reviewed_by is distinct from old.reviewed_by
       or new.reviewed_at is distinct from old.reviewed_at
       or new.created_club_id is distinct from old.created_club_id then
      raise exception
        'Students cannot change administrative review fields';
    end if;

    if old.status not in ('DRAFT', 'CHANGES_REQUESTED') then
      raise exception
        'This request can no longer be edited';
    end if;

    if new.status not in (
      'DRAFT',
      'SUBMITTED',
      'WITHDRAWN'
    ) then
      raise exception
        'Invalid student request status change';
    end if;

    if new.submitted_at is distinct from old.submitted_at then
      raise exception
        'submitted_at is managed automatically';
    end if;
  end if;

  if new.status = 'SUBMITTED'
     and old.status is distinct from 'SUBMITTED' then
    new.submitted_at := now();
  end if;

  if is_application_admin
     and new.status in (
       'CHANGES_REQUESTED',
       'APPROVED',
       'REJECTED'
     )
     and new.status is distinct from old.status then
    new.reviewed_at := coalesce(new.reviewed_at, now());
  end if;

  return new;
end;
$$;


-- ---------------------------------------------------------
-- Approve club registration (SAC_ADMIN | FACULTY_ADVISOR)
-- ---------------------------------------------------------

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

  insert into public.clubs (
    name,
    slug,
    short_description,
    description,
    contact_email,
    meeting_schedule,
    status,
    created_by,
    approved_by,
    approved_at
  )
  values (
    v_request.proposed_name,
    lower(trim(p_slug)),
    v_request.short_description,
    v_request.description,
    v_request.faculty_advisor_email,
    v_request.meeting_plan,
    'APPROVED',
    v_request.requested_by,
    v_admin_id,
    now()
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

  update public.club_registration_requests
  set
    status = 'APPROVED',
    review_notes = p_review_notes,
    reviewed_by = v_admin_id,
    reviewed_at = now(),
    created_club_id = v_club_id
  where id = p_request_id;

  return v_club_id;
end;
$$;

revoke all
on function public.approve_club_registration_request(uuid, text, text)
from public, anon, authenticated;

grant execute
on function public.approve_club_registration_request(uuid, text, text)
to authenticated;


-- ---------------------------------------------------------
-- Review club registration (non-approve actions via RPC)
-- ---------------------------------------------------------

create or replace function public.review_club_registration_request(
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
  v_request public.club_registration_requests%rowtype;
begin
  v_admin_id := (select auth.uid());

  if v_admin_id is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  if not public.can_mutate_reviews() then
    raise exception
      'Only SAC administrators and faculty advisors may review club requests'
      using errcode = '42501';
  end if;

  v_action := upper(btrim(p_action));

  select *
  into v_request
  from public.club_registration_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Club registration request not found';
  end if;

  if v_action = 'UNDER_REVIEW' then
    if v_request.status <> 'SUBMITTED' then
      raise exception
        'Only submitted requests may be marked under review';
    end if;

    update public.club_registration_requests
    set
      status = 'UNDER_REVIEW',
      reviewed_by = v_admin_id,
      reviewed_at = now(),
      review_notes = coalesce(nullif(btrim(p_review_notes), ''), review_notes)
    where id = p_request_id;

  elsif v_action = 'CHANGES_REQUESTED' then
    if v_request.status not in ('SUBMITTED', 'UNDER_REVIEW') then
      raise exception
        'This request cannot be returned for changes';
    end if;

    if nullif(btrim(p_review_notes), '') is null then
      raise exception
        'Review notes are required when requesting changes';
    end if;

    update public.club_registration_requests
    set
      status = 'CHANGES_REQUESTED',
      review_notes = btrim(p_review_notes),
      reviewed_by = v_admin_id,
      reviewed_at = now()
    where id = p_request_id;

  elsif v_action = 'REJECTED' then
    if v_request.status not in ('SUBMITTED', 'UNDER_REVIEW') then
      raise exception
        'This request cannot be rejected';
    end if;

    if nullif(btrim(p_review_notes), '') is null then
      raise exception
        'Review notes are required when rejecting a request';
    end if;

    update public.club_registration_requests
    set
      status = 'REJECTED',
      review_notes = btrim(p_review_notes),
      reviewed_by = v_admin_id,
      reviewed_at = now()
    where id = p_request_id;

  else
    raise exception
      'Invalid club request review action. Use UNDER_REVIEW, CHANGES_REQUESTED, or REJECTED';
  end if;

  return p_request_id;
end;
$$;

revoke all
on function public.review_club_registration_request(uuid, text, text)
from public, anon, authenticated;

grant execute
on function public.review_club_registration_request(uuid, text, text)
to authenticated;


-- ---------------------------------------------------------
-- Announcement review (SAC_ADMIN | FACULTY_ADVISOR)
-- ---------------------------------------------------------

create or replace function public.review_announcement(
  p_announcement_id uuid,
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
  v_announcement public.announcements%rowtype;
begin
  v_admin_id := (select auth.uid());

  if v_admin_id is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  if not public.can_mutate_reviews() then
    raise exception
      'Only SAC administrators and faculty advisors may review announcements'
      using errcode = '42501';
  end if;

  v_action := upper(btrim(p_action));

  select *
  into v_announcement
  from public.announcements
  where id = p_announcement_id
  for update;

  if not found then
    raise exception 'Announcement not found';
  end if;

  if v_action = 'UNDER_REVIEW' then
    if v_announcement.status <> 'SUBMITTED' then
      raise exception
        'Only submitted announcements may be marked under review';
    end if;

    update public.announcements
    set
      status = 'UNDER_REVIEW',
      reviewed_by = v_admin_id,
      reviewed_at = now()
    where id = p_announcement_id;

  elsif v_action = 'CHANGES_REQUESTED' then
    if v_announcement.status not in (
      'SUBMITTED',
      'UNDER_REVIEW'
    ) then
      raise exception
        'This announcement cannot be returned for changes';
    end if;

    if nullif(btrim(p_review_notes), '') is null then
      raise exception
        'Review notes are required when requesting changes';
    end if;

    update public.announcements
    set
      status = 'CHANGES_REQUESTED',
      review_notes = btrim(p_review_notes),
      reviewed_by = v_admin_id,
      reviewed_at = now()
    where id = p_announcement_id;

  elsif v_action = 'REJECTED' then
    if v_announcement.status not in (
      'SUBMITTED',
      'UNDER_REVIEW'
    ) then
      raise exception
        'This announcement cannot be rejected';
    end if;

    if nullif(btrim(p_review_notes), '') is null then
      raise exception
        'Review notes are required when rejecting an announcement';
    end if;

    update public.announcements
    set
      status = 'REJECTED',
      review_notes = btrim(p_review_notes),
      reviewed_by = v_admin_id,
      reviewed_at = now()
    where id = p_announcement_id;

  elsif v_action = 'PUBLISH' then
    if v_announcement.status not in (
      'SUBMITTED',
      'UNDER_REVIEW'
    ) then
      raise exception
        'Only submitted or under-review announcements may be published';
    end if;

    update public.announcements
    set
      status = 'PUBLISHED',
      review_notes = nullif(btrim(p_review_notes), ''),
      reviewed_by = v_admin_id,
      reviewed_at = now(),
      published_at = now()
    where id = p_announcement_id;

  else
    raise exception 'Invalid announcement review action';
  end if;

  return p_announcement_id;
end;
$$;

revoke all
on function public.review_announcement(uuid, text, text)
from public, anon, authenticated;

grant execute
on function public.review_announcement(uuid, text, text)
to authenticated;


-- ---------------------------------------------------------
-- Clean SITE_ADMIN from announcement create/edit/archive
-- (preserve existing FACULTY_ADVISOR and club-owner paths)
-- ---------------------------------------------------------

create or replace function public.archive_announcement(
  p_announcement_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_announcement public.announcements%rowtype;
  v_allowed boolean;
begin
  v_user_id := (select auth.uid());

  if v_user_id is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  select *
  into v_announcement
  from public.announcements
  where id = p_announcement_id
  for update;

  if not found then
    raise exception 'Announcement not found';
  end if;

  v_allowed :=
    public.has_system_role('SAC_ADMIN')
    or (
      public.has_system_role('FACULTY_ADVISOR')
      and v_announcement.created_by = v_user_id
    );

  if not v_allowed then
    raise exception
      'You do not have permission to archive this announcement'
      using errcode = '42501';
  end if;

  if v_announcement.status <> 'PUBLISHED' then
    raise exception
      'Only published announcements may be archived';
  end if;

  update public.announcements
  set status = 'ARCHIVED'
  where id = p_announcement_id;

  return p_announcement_id;
end;
$$;

revoke all
on function public.archive_announcement(uuid)
from public, anon, authenticated;

grant execute
on function public.archive_announcement(uuid)
to authenticated;
