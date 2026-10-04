-- Ensure archive clears active club roles for everyone, and allow SAC_ADMIN.
-- Also backfill ARCHIVED / current-year INACTIVE clubs that still have ACTIVE members.

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
  v_is_owner boolean;
  v_is_admin boolean;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  if p_club_id is null then
    raise exception 'Club ID is required';
  end if;

  v_is_owner := public.has_club_role(p_club_id, array['OWNER']);
  v_is_admin := public.has_system_role('SAC_ADMIN');

  if not (v_is_owner or v_is_admin) then
    raise exception 'Only an active club OWNER may archive this club'
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

  if v_club.status = 'ARCHIVED' then
    raise exception 'This club is already archived';
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

  if v_annual.status = 'INACTIVE' then
    raise exception 'This club is already inactive for the current school year';
  end if;

  if v_annual.status not in ('ACTIVE', 'PENDING_SUPERVISOR', 'SUSPENDED') then
    raise exception
      'Club annual status % cannot be archived',
      v_annual.status;
  end if;

  -- Annual INACTIVE first so owner-limit trigger allows zero active OWNERs.
  update public.club_school_years
  set
    status = 'INACTIVE',
    supervisor_due_at = null,
    activated_at = null
  where club_id = p_club_id
    and school_year = v_year;

  -- Clear all active club-scoped roles (OWNER / EXEC / MEMBER).
  update public.club_memberships
  set status = 'INACTIVE'
  where club_id = p_club_id
    and status = 'ACTIVE';

  update public.club_supervisor_requests
  set
    status = 'CANCELLED',
    review_notes = coalesce(
      nullif(btrim(coalesce(review_notes, '')), ''),
      'Cancelled because the club was archived by an owner.'
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

  update public.clubs
  set
    status = 'ARCHIVED',
    eligible_for_reapplication = true
  where id = p_club_id;

  return p_club_id;
end;
$$;

revoke all on function public.archive_owned_club(uuid)
from public, anon;
grant execute on function public.archive_owned_club(uuid)
to authenticated;


-- Backfill: archived or current-year inactive clubs should not keep ACTIVE roles.
update public.club_memberships m
set status = 'INACTIVE'
from public.clubs c
where m.club_id = c.id
  and m.status = 'ACTIVE'
  and (
    c.status = 'ARCHIVED'
    or exists (
      select 1
      from public.club_school_years csy
      where csy.club_id = c.id
        and csy.school_year = public.get_current_club_school_year()
        and csy.status = 'INACTIVE'
    )
  );
