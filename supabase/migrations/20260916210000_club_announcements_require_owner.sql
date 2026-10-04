-- Club-scoped announcements may only be created by that club's owner.
-- SAC admins and faculty advisors may still create general (no-club) announcements.

create or replace function public.create_announcement(
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

    if not exists (
      select 1
      from public.clubs
      where id = p_club_id
        and status = 'APPROVED'
    ) then
      raise exception 'The selected club is not available';
    end if;

    if not v_is_club_owner then
      raise exception
        'Only a club owner may create an announcement for this club'
        using errcode = '42501';
    end if;
  elsif not (v_is_admin or v_is_advisor) then
    raise exception
      'Only SAC administrators and faculty advisors may create a general announcement'
      using errcode = '42501';
  end if;

  if v_action = 'DRAFT' then
    v_status := 'DRAFT';
  elsif v_action = 'SUBMIT' then
    v_status := 'SUBMITTED';
  else
    raise exception 'Announcements must be saved as DRAFT or SUBMIT';
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
