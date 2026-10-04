-- =========================================================
-- Allow same-day announcement posting ("publish now")
--
-- Selecting America/Toronto today as the posting date means:
-- - submit is allowed
-- - request is NOT auto-cancelled that day
-- - approval publishes immediately (published_at = now())
-- - visibility still expires at next Toronto midnight
-- =========================================================

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

  -- Today is allowed (publish-now on approve). Past dates are not.
  if p_date < public.toronto_local_date() then
    raise exception
      'Announcement posting date cannot be in the past (America/Toronto)';
  end if;
end;
$$;

revoke all on function public.assert_future_toronto_posting_date(date)
from public;
grant execute on function public.assert_future_toronto_posting_date(date)
to authenticated;


create or replace function public.refresh_announcement_lifecycle()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_today date := public.toronto_local_date();
begin
  -- Unapproved requests whose posting day has already passed → CANCELLED
  -- Same-day requests stay open so staff can approve (publish now).
  update public.announcements
  set
    status = 'CANCELLED',
    review_notes = coalesce(
      nullif(btrim(coalesce(review_notes, '')), ''),
      'Automatically cancelled: posting date ended without approval.'
    ),
    reviewed_at = coalesce(reviewed_at, now())
  where status in ('SUBMITTED', 'UNDER_REVIEW', 'CHANGES_REQUESTED')
    and scheduled_posting_date is not null
    and scheduled_posting_date < v_today;

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
  v_published_at timestamptz;
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

    if v_announcement.scheduled_posting_date < v_today then
      raise exception
        'Announcements cannot be approved after their scheduled posting date (America/Toronto)';
    end if;

    -- Today = publish now; future dates go live at Toronto midnight that day.
    if v_announcement.scheduled_posting_date = v_today then
      v_published_at := now();
    else
      v_published_at := public.toronto_midnight(
        v_announcement.scheduled_posting_date
      );
    end if;

    update public.announcements
    set
      status = 'PUBLISHED',
      review_notes = nullif(btrim(coalesce(p_review_notes, '')), ''),
      reviewed_by = v_admin_id,
      reviewed_at = now(),
      published_at = v_published_at,
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
