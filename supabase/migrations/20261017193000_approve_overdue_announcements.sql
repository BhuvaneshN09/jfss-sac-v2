-- Overdue announcement requests stay in the queue.
-- Approving them publishes immediately and keeps them up through this Sunday.

create or replace function public.refresh_announcement_lifecycle()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Approved posts stay through Sunday, then archive Monday at midnight.
  update public.announcements
  set
    status = 'ARCHIVED',
    archived_at = coalesce(archived_at, expires_at, now()),
    published_at = coalesce(published_at, now())
  where status = 'PUBLISHED'
    and expires_at is not null
    and expires_at <= now();
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
  v_expire_date date;
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

    -- Today or overdue = publish now. Future dates go live at Toronto midnight.
    if v_announcement.scheduled_posting_date <= v_today then
      v_published_at := now();
    else
      v_published_at := public.toronto_midnight(
        v_announcement.scheduled_posting_date
      );
    end if;

    v_expire_date := public.announcement_week_refresh_date(
      greatest(v_announcement.scheduled_posting_date, v_today)
    );

    update public.announcements
    set
      status = 'PUBLISHED',
      review_notes = nullif(btrim(coalesce(p_review_notes, '')), ''),
      reviewed_by = v_admin_id,
      reviewed_at = now(),
      published_at = v_published_at,
      expires_at = public.toronto_midnight(v_expire_date),
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

-- Put auto-cancelled overdue requests back in the review queue.
update public.announcements
set
  status = 'SUBMITTED',
  review_notes = null,
  reviewed_at = null,
  reviewed_by = null
where status = 'CANCELLED'
  and review_notes =
    'Automatically cancelled: posting date ended without approval.';
