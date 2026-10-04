-- =========================================================
-- Announcement scheduled posting dates + Toronto lifecycle
--
-- - required future America/Toronto posting date on submit
-- - approval schedules visibility for that Toronto calendar day
-- - unapproved requests auto-cancel when the posting date begins
-- - published announcements auto-archive after that day ends
-- - public board is time-aware (no client timer / no cron required)
-- =========================================================

-- ---------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------

create or replace function public.toronto_midnight(p_date date)
returns timestamptz
language sql
immutable
set search_path = ''
as $$
  -- Interprets p_date's midnight in America/Toronto as timestamptz.
  select (p_date::timestamp at time zone 'America/Toronto');
$$;

revoke all on function public.toronto_midnight(date) from public;
grant execute on function public.toronto_midnight(date) to anon, authenticated;

create or replace function public.assert_future_toronto_posting_date(
  p_date date
)
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if p_date is null then
    raise exception
      'Announcement posting date is required';
  end if;

  if p_date <= public.toronto_local_date() then
    raise exception
      'Announcement posting date must be after today (America/Toronto)';
  end if;
end;
$$;

revoke all on function public.assert_future_toronto_posting_date(date)
from public;
grant execute on function public.assert_future_toronto_posting_date(date)
to authenticated;


-- ---------------------------------------------------------
-- Schema
-- ---------------------------------------------------------

alter table public.announcements
  add column if not exists scheduled_posting_date date;

alter table public.announcements
  drop constraint if exists announcements_status_valid;

alter table public.announcements
  add constraint announcements_status_valid
  check (
    status in (
      'DRAFT',
      'SUBMITTED',
      'UNDER_REVIEW',
      'CHANGES_REQUESTED',
      'PUBLISHED',
      'REJECTED',
      'CANCELLED',
      'ARCHIVED'
    )
  );

create index if not exists announcements_scheduled_posting_date_idx
  on public.announcements (scheduled_posting_date);


-- ---------------------------------------------------------
-- Backfill from authoritative published_at only
-- ---------------------------------------------------------

update public.announcements
set scheduled_posting_date = public.toronto_local_date(published_at)
where scheduled_posting_date is null
  and published_at is not null;

-- Align visibility windows for rows that already have a posting date.
update public.announcements
set
  published_at = public.toronto_midnight(scheduled_posting_date),
  expires_at = public.toronto_midnight(scheduled_posting_date + 1)
where status = 'PUBLISHED'
  and scheduled_posting_date is not null
  and scheduled_posting_date >= public.toronto_local_date();

update public.announcements
set
  status = 'ARCHIVED',
  archived_at = coalesce(
    archived_at,
    expires_at,
    public.toronto_midnight(scheduled_posting_date + 1),
    now()
  ),
  published_at = coalesce(
    published_at,
    public.toronto_midnight(scheduled_posting_date)
  ),
  expires_at = coalesce(
    expires_at,
    public.toronto_midnight(scheduled_posting_date + 1)
  )
where status = 'PUBLISHED'
  and scheduled_posting_date is not null
  and scheduled_posting_date < public.toronto_local_date();

do $$
declare
  r record;
  v_count integer := 0;
begin
  for r in
    select id, status, title
    from public.announcements
    where scheduled_posting_date is null
      and status in ('SUBMITTED', 'UNDER_REVIEW', 'CHANGES_REQUESTED')
  loop
    v_count := v_count + 1;
    raise notice
      'UNMIGRATED pending announcement (needs future posting date before approval): id=%, status=%, title=%',
      r.id, r.status, r.title;
  end loop;

  for r in
    select id, status, title
    from public.announcements
    where scheduled_posting_date is null
      and status in ('PUBLISHED', 'ARCHIVED')
  loop
    v_count := v_count + 1;
    raise notice
      'UNMIGRATED published/archived announcement (no published_at to derive date): id=%, status=%, title=%',
      r.id, r.status, r.title;
  end loop;

  raise notice
    'Announcement posting-date backfill complete. Unresolved rows to review: %',
    v_count;
end;
$$;


-- ---------------------------------------------------------
-- Lifecycle refresh (idempotent; safe to call on reads/writes)
-- ---------------------------------------------------------

create or replace function public.refresh_announcement_lifecycle()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_today date := public.toronto_local_date();
begin
  -- Unapproved requests whose posting day has begun → CANCELLED
  update public.announcements
  set
    status = 'CANCELLED',
    review_notes = coalesce(
      nullif(btrim(coalesce(review_notes, '')), ''),
      'Automatically cancelled: posting date began without approval.'
    ),
    reviewed_at = coalesce(reviewed_at, now())
  where status in ('SUBMITTED', 'UNDER_REVIEW', 'CHANGES_REQUESTED')
    and scheduled_posting_date is not null
    and scheduled_posting_date <= v_today;

  -- Approved posts whose Toronto posting day has ended → ARCHIVED
  update public.announcements
  set
    status = 'ARCHIVED',
    archived_at = coalesce(
      archived_at,
      public.toronto_midnight(scheduled_posting_date + 1)
    ),
    published_at = coalesce(
      published_at,
      public.toronto_midnight(scheduled_posting_date)
    ),
    expires_at = coalesce(
      expires_at,
      public.toronto_midnight(scheduled_posting_date + 1)
    )
  where status = 'PUBLISHED'
    and scheduled_posting_date is not null
    and scheduled_posting_date < v_today;
end;
$$;

revoke all on function public.refresh_announcement_lifecycle()
from public;
grant execute on function public.refresh_announcement_lifecycle()
to anon, authenticated;


-- ---------------------------------------------------------
-- Public RLS: live only during the scheduled Toronto day
-- ---------------------------------------------------------

drop policy if exists "announcements_public_select_published"
on public.announcements;

create policy "announcements_public_select_published"
on public.announcements
for select
to anon, authenticated
using (
  status = 'PUBLISHED'
  and scheduled_posting_date is not null
  and published_at is not null
  and published_at <= now()
  and (
    expires_at is not null
    and expires_at > now()
  )
);


-- ---------------------------------------------------------
-- Create / edit / review / archive RPCs
-- ---------------------------------------------------------

drop function if exists public.create_announcement(
  text, text, text, text, uuid, text, timestamptz
);

create or replace function public.create_announcement(
  p_title text,
  p_body text,
  p_summary text default null,
  p_image_url text default null,
  p_club_id uuid default null,
  p_action text default 'DRAFT',
  p_scheduled_posting_date date default null
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
  v_posting_date date;
begin
  perform public.refresh_announcement_lifecycle();

  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  v_action := upper(btrim(p_action));
  v_posting_date := p_scheduled_posting_date;

  v_is_admin := public.has_system_role('SAC_ADMIN');
  v_is_advisor := public.has_system_role('FACULTY_ADVISOR');
  v_is_club_owner :=
    p_club_id is not null
    and public.has_club_role(p_club_id, array['OWNER']);

  if p_club_id is not null then
    perform public.assert_club_operations_allowed(p_club_id);
  end if;

  if p_club_id is not null
     and not exists (
       select 1
       from public.clubs
       where id = p_club_id
         and status = 'APPROVED'
     ) then
    raise exception 'The selected club is not available';
  end if;

  if v_is_admin or v_is_advisor then
    if v_action = 'DRAFT' then
      v_status := 'DRAFT';
    elsif v_action = 'SUBMIT' then
      v_status := 'SUBMITTED';
    else
      raise exception
        'Staff announcements must be saved as DRAFT or SUBMIT';
    end if;
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

  if v_status = 'SUBMITTED' then
    perform public.assert_future_toronto_posting_date(v_posting_date);
  elsif v_posting_date is not null then
    perform public.assert_future_toronto_posting_date(v_posting_date);
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
    scheduled_posting_date
  )
  values (
    p_club_id,
    btrim(p_title),
    nullif(btrim(coalesce(p_summary, '')), ''),
    btrim(p_body),
    nullif(btrim(coalesce(p_image_url, '')), ''),
    v_status,
    v_user_id,
    case when v_status = 'SUBMITTED' then now() else null end,
    v_posting_date
  )
  returning id into v_announcement_id;

  return v_announcement_id;
end;
$$;

revoke all on function public.create_announcement(
  text, text, text, text, uuid, text, date
) from public, anon;
grant execute on function public.create_announcement(
  text, text, text, text, uuid, text, date
) to authenticated;


drop function if exists public.edit_announcement(
  uuid, text, text, text, text, text, timestamptz
);

create or replace function public.edit_announcement(
  p_announcement_id uuid,
  p_title text,
  p_body text,
  p_summary text default null,
  p_image_url text default null,
  p_action text default 'SAVE',
  p_scheduled_posting_date date default null
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
  v_submitted_at timestamptz;
  v_posting_date date;
begin
  perform public.refresh_announcement_lifecycle();

  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
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

  v_is_admin := public.has_system_role('SAC_ADMIN');
  v_is_advisor :=
    public.has_system_role('FACULTY_ADVISOR')
    and v_announcement.created_by = v_user_id;
  v_is_club_owner :=
    v_announcement.created_by = v_user_id
    and v_announcement.club_id is not null
    and public.has_club_role(v_announcement.club_id, array['OWNER']);

  v_new_status := v_announcement.status;
  v_submitted_at := v_announcement.submitted_at;
  v_posting_date := coalesce(
    p_scheduled_posting_date,
    v_announcement.scheduled_posting_date
  );

  if v_is_admin then
    if v_announcement.status = 'ARCHIVED' then
      raise exception 'Archived announcements cannot be edited';
    end if;

    if v_action = 'SUBMIT'
       and v_announcement.status in ('DRAFT', 'CHANGES_REQUESTED') then
      v_new_status := 'SUBMITTED';
      v_submitted_at := now();
    elsif v_action <> 'SAVE' then
      raise exception 'Invalid administrator action';
    end if;

  elsif v_is_advisor then
    if v_announcement.status not in ('DRAFT', 'CHANGES_REQUESTED') then
      raise exception
        'This faculty announcement can no longer be edited';
    end if;

    if v_action = 'SUBMIT' then
      v_new_status := 'SUBMITTED';
      v_submitted_at := now();
    elsif v_action <> 'SAVE' then
      raise exception 'Invalid faculty-advisor action';
    end if;

  elsif v_is_club_owner then
    if v_announcement.status not in ('DRAFT', 'CHANGES_REQUESTED') then
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

  if v_new_status = 'SUBMITTED'
     or (v_action = 'SUBMIT') then
    perform public.assert_future_toronto_posting_date(v_posting_date);
  elsif v_posting_date is not null
     and v_new_status in ('DRAFT', 'CHANGES_REQUESTED') then
    perform public.assert_future_toronto_posting_date(v_posting_date);
  end if;

  update public.announcements
  set
    title = btrim(p_title),
    summary = nullif(btrim(coalesce(p_summary, '')), ''),
    body = btrim(p_body),
    image_url = nullif(btrim(coalesce(p_image_url, '')), ''),
    status = v_new_status,
    submitted_at = v_submitted_at,
    scheduled_posting_date = v_posting_date,
    -- Clear prior publish window while unapproved
    published_at = case
      when v_new_status in ('DRAFT', 'SUBMITTED', 'CHANGES_REQUESTED')
        then null
      else published_at
    end,
    expires_at = case
      when v_new_status in ('DRAFT', 'SUBMITTED', 'CHANGES_REQUESTED')
        then null
      else expires_at
    end
  where id = p_announcement_id;

  return p_announcement_id;
end;
$$;

revoke all on function public.edit_announcement(
  uuid, text, text, text, text, text, date
) from public, anon;
grant execute on function public.edit_announcement(
  uuid, text, text, text, text, text, date
) to authenticated;


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
  v_today date := public.toronto_local_date();
begin
  perform public.refresh_announcement_lifecycle();

  v_admin_id := (select auth.uid());
  if v_admin_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not public.can_mutate_reviews() then
    raise exception
      'Only SAC administrators and faculty advisors may review announcements'
      using errcode = '42501';
  end if;

  v_action := upper(btrim(p_action));
  if v_action = 'APPROVE' then
    v_action := 'PUBLISH';
  end if;

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
    if v_announcement.status not in ('SUBMITTED', 'UNDER_REVIEW') then
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
    if v_announcement.status not in ('SUBMITTED', 'UNDER_REVIEW') then
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
    if v_announcement.status not in ('SUBMITTED', 'UNDER_REVIEW') then
      raise exception
        'Only submitted or under-review announcements may be approved';
    end if;

    if v_announcement.scheduled_posting_date is null then
      raise exception
        'Announcement posting date is required before approval';
    end if;

    if v_announcement.scheduled_posting_date <= v_today then
      raise exception
        'Announcements cannot be approved on or after their scheduled posting date (America/Toronto)';
    end if;

    update public.announcements
    set
      status = 'PUBLISHED',
      review_notes = nullif(btrim(coalesce(p_review_notes, '')), ''),
      reviewed_by = v_admin_id,
      reviewed_at = now(),
      published_at = public.toronto_midnight(
        v_announcement.scheduled_posting_date
      ),
      expires_at = public.toronto_midnight(
        v_announcement.scheduled_posting_date + 1
      ),
      archived_at = null
    where id = p_announcement_id;

  else
    raise exception 'Invalid announcement review action';
  end if;

  return p_announcement_id;
end;
$$;

revoke all on function public.review_announcement(uuid, text, text)
from public, anon;
grant execute on function public.review_announcement(uuid, text, text)
to authenticated;


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
  perform public.refresh_announcement_lifecycle();

  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
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
  set
    status = 'ARCHIVED',
    archived_at = coalesce(archived_at, now())
  where id = p_announcement_id;

  return p_announcement_id;
end;
$$;

revoke all on function public.archive_announcement(uuid)
from public, anon;
grant execute on function public.archive_announcement(uuid)
to authenticated;
