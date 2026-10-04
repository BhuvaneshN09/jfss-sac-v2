-- =========================================================
-- Announcement schema and approval workflow
-- =========================================================


-- =========================================================
-- 1. ANNOUNCEMENTS
-- =========================================================

create table public.announcements (
  id uuid primary key default gen_random_uuid(),

  -- Null means a general SAC/faculty announcement.
  -- A value means the announcement belongs to a club.
  club_id uuid
    references public.clubs(id)
    on delete cascade,

  title text not null,
  summary text,
  body text not null,
  image_url text,

  status text not null default 'DRAFT',

  created_by uuid not null
    references public.profiles(id)
    on delete restrict,

  submitted_at timestamptz,

  reviewed_by uuid
    references public.profiles(id)
    on delete set null,

  reviewed_at timestamptz,
  review_notes text,

  published_at timestamptz,
  expires_at timestamptz,
  archived_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint announcements_title_valid
    check (
      title = btrim(title)
      and char_length(title) between 3 and 160
    ),

  constraint announcements_summary_valid
    check (
      summary is null
      or char_length(summary) between 1 and 500
    ),

  constraint announcements_body_valid
    check (
      char_length(body) between 10 and 30000
    ),

  constraint announcements_status_valid
    check (
      status in (
        'DRAFT',
        'SUBMITTED',
        'UNDER_REVIEW',
        'CHANGES_REQUESTED',
        'PUBLISHED',
        'REJECTED',
        'ARCHIVED'
      )
    ),

  constraint announcements_published_at_required
    check (
      status <> 'PUBLISHED'
      or published_at is not null
    ),

  constraint announcements_expiry_valid
    check (
      expires_at is null
      or expires_at > created_at
    )
);


-- =========================================================
-- 2. INDEXES
-- =========================================================

-- Homepage query:
-- published announcements ordered by publication time.

create index announcements_public_feed_idx
  on public.announcements (
    status,
    published_at desc
  );


-- Club announcement lookups.

create index announcements_club_id_idx
  on public.announcements(club_id);


-- "My announcements" page.

create index announcements_created_by_idx
  on public.announcements(
    created_by,
    created_at desc
  );


-- Admin moderation queue.

create index announcements_review_queue_idx
  on public.announcements(
    status,
    submitted_at
  )
  where status in (
    'SUBMITTED',
    'UNDER_REVIEW',
    'CHANGES_REQUESTED'
  );


-- =========================================================
-- 3. UPDATED_AT TRIGGER
--
-- Reuses public.set_updated_at() from the first migration.
-- =========================================================

create trigger set_announcements_updated_at
before update
on public.announcements
for each row
execute function public.set_updated_at();


-- =========================================================
-- 4. ENABLE RLS
-- =========================================================

alter table public.announcements
  enable row level security;


-- =========================================================
-- 5. TABLE PRIVILEGES
--
-- Users read through the table.
-- All writes go through protected database functions below.
-- =========================================================

grant usage on schema public
to anon, authenticated;

revoke all
on table public.announcements
from anon, authenticated;

grant select
on table public.announcements
to anon, authenticated;


-- =========================================================
-- 6. SELECT POLICIES
-- =========================================================

-- Public homepage feed.
-- Expired announcements disappear automatically.

create policy "announcements_public_select_published"
on public.announcements
for select
to anon, authenticated
using (
  status = 'PUBLISHED'
  and published_at <= now()
  and (
    expires_at is null
    or expires_at > now()
  )
);


-- Creators may see their own drafts, requests and rejected posts.

create policy "announcements_creator_select_own"
on public.announcements
for select
to authenticated
using (
  created_by = (select auth.uid())
);


-- SAC and site administrators may see the full moderation queue.

create policy "announcements_admin_select_all"
on public.announcements
for select
to authenticated
using (
  public.has_system_role('SAC_ADMIN')
  or public.has_system_role('SITE_ADMIN')
);


-- =========================================================
-- 7. CREATE ANNOUNCEMENT FUNCTION
--
-- p_action:
--
-- Club owner:
--   DRAFT
--   SUBMIT
--
-- Faculty advisor/admin:
--   DRAFT
--   PUBLISH
-- =========================================================

create or replace function public.create_announcement(
  p_title text,
  p_body text,
  p_summary text default null,
  p_image_url text default null,
  p_club_id uuid default null,
  p_action text default 'DRAFT',
  p_expires_at timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_action text;
  v_status text;
  v_announcement_id uuid;

  v_is_admin boolean;
  v_is_advisor boolean;
  v_is_club_owner boolean;
begin
  v_user_id := (select auth.uid());

  if v_user_id is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  v_action := upper(btrim(p_action));

  v_is_admin :=
    public.has_system_role('SAC_ADMIN')
    or public.has_system_role('SITE_ADMIN');

  v_is_advisor :=
    public.has_system_role('FACULTY_ADVISOR');

  v_is_club_owner :=
    p_club_id is not null
    and public.has_club_role(
      p_club_id,
      array['OWNER']
    );

  if p_club_id is not null
     and not exists (
       select 1
       from public.clubs
       where id = p_club_id
         and status = 'APPROVED'
     ) then
    raise exception 'The selected club is not available';
  end if;

  -- SAC admins and faculty advisors may publish directly.

  if v_is_admin or v_is_advisor then
    if v_action = 'DRAFT' then
      v_status := 'DRAFT';
    elsif v_action = 'PUBLISH' then
      v_status := 'PUBLISHED';
    else
      raise exception
        'Staff announcements must be saved as DRAFT or PUBLISH';
    end if;

  -- Club owners must submit for SAC approval.

  else
    if not v_is_club_owner then
      raise exception
        'Only a club owner may create an announcement for this club'
        using errcode = '42501';
    end if;

    if v_action = 'DRAFT' then
      v_status := 'DRAFT';
    elsif v_action = 'SUBMIT' then
      v_status := 'SUBMITTED';
    else
      raise exception
        'Club-owner announcements must be DRAFT or SUBMIT';
    end if;
  end if;

  insert into public.announcements (
    club_id,
    title,
    summary,
    body,
    image_url,
    status,
    created_by,
    submitted_at,
    published_at,
    expires_at
  )
  values (
    p_club_id,
    btrim(p_title),
    nullif(btrim(p_summary), ''),
    btrim(p_body),
    nullif(btrim(p_image_url), ''),
    v_status,
    v_user_id,

    case
      when v_status = 'SUBMITTED' then now()
      else null
    end,

    case
      when v_status = 'PUBLISHED' then now()
      else null
    end,

    p_expires_at
  )
  returning id into v_announcement_id;

  return v_announcement_id;
end;
$$;

revoke all
on function public.create_announcement(
  text,
  text,
  text,
  text,
  uuid,
  text,
  timestamptz
)
from public, anon, authenticated;

grant execute
on function public.create_announcement(
  text,
  text,
  text,
  text,
  uuid,
  text,
  timestamptz
)
to authenticated;


-- =========================================================
-- 8. EDIT AND RESUBMIT FUNCTION
-- =========================================================

create or replace function public.edit_announcement(
  p_announcement_id uuid,
  p_title text,
  p_body text,
  p_summary text default null,
  p_image_url text default null,
  p_action text default 'SAVE',
  p_expires_at timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_action text;
  v_announcement public.announcements%rowtype;

  v_is_admin boolean;
  v_is_advisor boolean;
  v_is_club_owner boolean;

  v_new_status text;
  v_published_at timestamptz;
  v_submitted_at timestamptz;
begin
  v_user_id := (select auth.uid());

  if v_user_id is null then
    raise exception 'Authentication required'
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

  v_is_admin :=
    public.has_system_role('SAC_ADMIN')
    or public.has_system_role('SITE_ADMIN');

  v_is_advisor :=
    public.has_system_role('FACULTY_ADVISOR')
    and v_announcement.created_by = v_user_id;

  v_is_club_owner :=
    v_announcement.created_by = v_user_id
    and v_announcement.club_id is not null
    and public.has_club_role(
      v_announcement.club_id,
      array['OWNER']
    );

  v_new_status := v_announcement.status;
  v_published_at := v_announcement.published_at;
  v_submitted_at := v_announcement.submitted_at;

  -- Administrators may edit any announcement.

  if v_is_admin then
    if v_action = 'PUBLISH' then
      v_new_status := 'PUBLISHED';
      v_published_at := coalesce(
        v_announcement.published_at,
        now()
      );
    elsif v_action <> 'SAVE' then
      raise exception 'Invalid administrator action';
    end if;

  -- Faculty advisors may edit their own posts and publish directly.

  elsif v_is_advisor then
    if v_announcement.status not in (
      'DRAFT',
      'PUBLISHED'
    ) then
      raise exception
        'This faculty announcement can no longer be edited';
    end if;

    if v_action = 'PUBLISH' then
      v_new_status := 'PUBLISHED';
      v_published_at := coalesce(
        v_announcement.published_at,
        now()
      );
    elsif v_action <> 'SAVE' then
      raise exception 'Invalid faculty-advisor action';
    end if;

  -- Club owners may edit drafts or requested changes,
  -- then submit or resubmit for approval.

  elsif v_is_club_owner then
    if v_announcement.status not in (
      'DRAFT',
      'CHANGES_REQUESTED'
    ) then
      raise exception
        'Only drafts or change-requested announcements may be edited';
    end if;

    if v_action = 'SUBMIT' then
      v_new_status := 'SUBMITTED';
      v_submitted_at := now();
    elsif v_action <> 'SAVE' then
      raise exception 'Invalid club-owner action';
    end if;

  else
    raise exception
      'You do not have permission to edit this announcement'
      using errcode = '42501';
  end if;

  update public.announcements
  set
    title = btrim(p_title),
    summary = nullif(btrim(p_summary), ''),
    body = btrim(p_body),
    image_url = nullif(btrim(p_image_url), ''),
    status = v_new_status,
    submitted_at = v_submitted_at,
    published_at = v_published_at,
    expires_at = p_expires_at
  where id = p_announcement_id;

  return p_announcement_id;
end;
$$;

revoke all
on function public.edit_announcement(
  uuid,
  text,
  text,
  text,
  text,
  text,
  timestamptz
)
from public, anon, authenticated;

grant execute
on function public.edit_announcement(
  uuid,
  text,
  text,
  text,
  text,
  text,
  timestamptz
)
to authenticated;


-- =========================================================
-- 9. SAC REVIEW FUNCTION
--
-- Valid actions:
-- UNDER_REVIEW
-- CHANGES_REQUESTED
-- REJECTED
-- PUBLISH
-- =========================================================

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

  if not (
    public.has_system_role('SAC_ADMIN')
    or public.has_system_role('SITE_ADMIN')
  ) then
    raise exception
      'Only SAC or site administrators may review announcements'
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
on function public.review_announcement(
  uuid,
  text,
  text
)
from public, anon, authenticated;

grant execute
on function public.review_announcement(
  uuid,
  text,
  text
)
to authenticated;


-- =========================================================
-- 10. ARCHIVE FUNCTION
--
-- Admins may archive any published announcement.
-- Faculty advisors may archive their own published posts.
-- =========================================================

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
    or public.has_system_role('SITE_ADMIN')
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
  set
    status = 'ARCHIVED',
    archived_at = now()
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