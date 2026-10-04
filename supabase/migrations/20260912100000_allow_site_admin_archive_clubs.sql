-- Allow SITE_ADMIN (legacy SAC_ADMIN) to archive clubs. Owners keep the
-- same archive path. Pending invitations are cancelled with the archive.

create or replace function public.archive_owned_club(p_club_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_club public.clubs%rowtype;
  v_year text;
  v_annual public.club_school_years%rowtype;
  v_now timestamptz := now();
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  if p_club_id is null then
    raise exception 'Club ID is required';
  end if;

  if not (
    public.has_club_role(p_club_id, array['OWNER'])
    or public.has_system_role('SAC_ADMIN')
  ) then
    raise exception
      'Only an active club OWNER or site administrator may archive this club'
      using errcode = '42501';
  end if;

  v_year := public.get_current_club_school_year();

  select *
  into v_club
  from public.clubs
  where id = p_club_id
  for update;

  if not found then
    raise exception 'Club not found';
  end if;

  if v_club.deleted_at is not null then
    raise exception 'This club was permanently removed and cannot be archived';
  end if;

  if v_club.status = 'ARCHIVED' then
    return p_club_id;
  end if;

  insert into public.club_school_years (club_id, school_year, status)
  values (p_club_id, v_year, 'INACTIVE')
  on conflict (club_id, school_year) do nothing;

  select *
  into v_annual
  from public.club_school_years
  where club_id = p_club_id
    and school_year = v_year
  for update;

  if not found then
    raise exception 'Could not load the current club school year record';
  end if;

  if v_annual.status = 'INACTIVE' and v_club.status <> 'ARCHIVED' then
    null;
  elsif v_annual.status not in ('ACTIVE', 'PENDING_SUPERVISOR', 'INACTIVE') then
    raise exception
      'Club annual status % cannot be archived',
      v_annual.status;
  end if;

  if v_annual.status in ('ACTIVE', 'PENDING_SUPERVISOR') then
    update public.club_school_years
    set
      status = 'INACTIVE',
      supervisor_due_at = null,
      activated_at = null
    where club_id = p_club_id
      and school_year = v_year;
  end if;

  update public.club_memberships
  set status = 'INACTIVE'
  where club_id = p_club_id
    and status = 'ACTIVE';

  update public.club_supervisor_requests
  set
    status = 'CANCELLED',
    review_notes = coalesce(
      nullif(btrim(coalesce(review_notes, '')), ''),
      'Cancelled because the club was archived.'
    ),
    reviewed_by = v_user_id,
    reviewed_at = v_now
  where club_id = p_club_id
    and school_year = v_year
    and status in ('SUBMITTED', 'UNDER_REVIEW', 'CHANGES_REQUESTED');

  update public.club_advisors
  set status = 'INACTIVE'
  where club_id = p_club_id
    and school_year = v_year
    and status = 'ACTIVE';

  perform public.cancel_pending_club_membership_invitations(
    p_club_id,
    v_user_id,
    'Club archived'
  );

  update public.clubs
  set
    status = 'ARCHIVED',
    eligible_for_reapplication = true,
    deleted_at = null,
    archived_at = v_now,
    archived_by = v_user_id,
    last_active_school_year = v_year
  where id = p_club_id;

  return p_club_id;
end;
$$;

revoke all on function public.archive_owned_club(uuid)
from public, anon;

grant execute on function public.archive_owned_club(uuid)
to authenticated;
