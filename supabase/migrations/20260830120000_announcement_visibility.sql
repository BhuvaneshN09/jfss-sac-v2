-- Add explicit announcement visibility and enforce club-member-only posts.

alter table public.announcements
  add column if not exists visibility text not null default 'PUBLIC';

alter table public.announcements
  drop constraint if exists announcements_visibility_valid;

alter table public.announcements
  add constraint announcements_visibility_valid
  check (
    visibility in ('PUBLIC', 'CLUB_MEMBERS')
    and (visibility = 'PUBLIC' or club_id is not null)
  );

drop policy if exists "announcements_public_select_published"
on public.announcements;

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
  and (
    visibility = 'PUBLIC'
    or (
      visibility = 'CLUB_MEMBERS'
      and not public.has_system_role('SAC_ADMIN')
      and not public.has_system_role('SAC_EXEC')
      and exists (
        select 1
        from public.club_memberships m
        where m.club_id = announcements.club_id
          and m.user_id = (select auth.uid())
          and m.status = 'ACTIVE'
      )
    )
  )
);

drop policy if exists "announcements_creator_select_own"
on public.announcements;

create policy "announcements_creator_select_own"
on public.announcements
for select
to authenticated
using (
  created_by = (select auth.uid())
  and (
    visibility = 'PUBLIC'
    or (
      visibility = 'CLUB_MEMBERS'
      and not public.has_system_role('SAC_ADMIN')
      and not public.has_system_role('SAC_EXEC')
      and exists (
        select 1
        from public.club_memberships m
        where m.club_id = announcements.club_id
          and m.user_id = (select auth.uid())
          and m.status = 'ACTIVE'
      )
    )
  )
);

drop policy if exists "announcements_admin_select_all"
on public.announcements;

create policy "announcements_admin_select_all"
on public.announcements
for select
to authenticated
using (
  public.can_read_review_queues()
  and (
    status <> 'PUBLISHED'
    or visibility = 'PUBLIC'
    or club_id is null
    or (
      visibility = 'CLUB_MEMBERS'
      and not public.has_system_role('SAC_ADMIN')
      and not public.has_system_role('SAC_EXEC')
      and exists (
        select 1
        from public.club_memberships m
        where m.club_id = announcements.club_id
          and m.user_id = (select auth.uid())
          and m.status = 'ACTIVE'
      )
    )
  )
);

drop function if exists public.create_announcement(
  text, text, text, text, uuid, text, date
);

drop function if exists public.create_announcement(
  text, text, text, uuid, text, date
);

create function public.create_announcement(
  p_title text,
  p_body text,
  p_visibility text,
  p_summary text default null,
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
  v_visibility text;
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
  v_visibility := upper(btrim(coalesce(p_visibility, '')));
  v_posting_date := p_scheduled_posting_date;

  if v_visibility not in ('PUBLIC', 'CLUB_MEMBERS') then
    raise exception 'Choose who can see this announcement.';
  end if;

  if v_visibility = 'CLUB_MEMBERS' and p_club_id is null then
    raise exception 'Club-only announcements must belong to a club.';
  end if;

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
    visibility,
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
    v_visibility,
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
  uuid, text, text, text, text, date
);

create function public.edit_announcement(
  p_announcement_id uuid,
  p_title text,
  p_body text,
  p_visibility text,
  p_summary text default null,
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
  v_visibility text;
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
  v_visibility := upper(btrim(coalesce(p_visibility, '')));

  if v_visibility not in ('PUBLIC', 'CLUB_MEMBERS') then
    raise exception 'Choose who can see this announcement.';
  end if;

  select *
  into v_announcement
  from public.announcements
  where id = p_announcement_id
  for update;

  if not found then
    raise exception 'Announcement not found';
  end if;

  if v_visibility = 'CLUB_MEMBERS' and v_announcement.club_id is null then
    raise exception 'Club-only announcements must belong to a club.';
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
    visibility = v_visibility,
    status = v_new_status,
    submitted_at = v_submitted_at,
    scheduled_posting_date = v_posting_date,
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
