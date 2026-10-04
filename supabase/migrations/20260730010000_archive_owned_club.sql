-- =========================================================
-- Owner-controlled club archive (soft archive, not delete)
-- =========================================================

-- Allow cancelling incomplete supervisor requests on archive.
alter table public.club_supervisor_requests
  drop constraint if exists club_sup_req_status_valid;

alter table public.club_supervisor_requests
  add constraint club_sup_req_status_valid
  check (
    status in (
      'SUBMITTED',
      'UNDER_REVIEW',
      'CHANGES_REQUESTED',
      'APPROVED',
      'REJECTED',
      'CANCELLED'
    )
  );

-- Past members (including inactive) may still read the club row for My Clubs.
drop policy if exists "clubs_select_past_members" on public.clubs;
create policy "clubs_select_past_members"
on public.clubs
for select
to authenticated
using (
  exists (
    select 1
    from public.club_memberships m
    where m.club_id = clubs.id
      and m.user_id = (select auth.uid())
  )
);


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

  -- Active OWNER or SAC_ADMIN may archive.
  if not (
    public.has_club_role(p_club_id, array['OWNER'])
    or public.has_system_role('SAC_ADMIN')
  ) then
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

  -- 1. Annual state → INACTIVE (must happen before memberships so owner-limit
  --    trigger allows zero active OWNERs at transaction end).
  update public.club_school_years
  set
    status = 'INACTIVE',
    supervisor_due_at = null,
    activated_at = null
  where club_id = p_club_id
    and school_year = v_year;

  -- 2. Soft-deactivate memberships (preserve history; no deletes).
  update public.club_memberships
  set status = 'INACTIVE'
  where club_id = p_club_id
    and status = 'ACTIVE';

  -- 3. Cancel incomplete supervisor requests.
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

  -- Deactivate current-year advisors so operations stay consistent.
  update public.club_advisors
  set status = 'INACTIVE'
  where club_id = p_club_id
    and school_year = v_year
    and status = 'ACTIVE';

  -- 4–6. Remove public visibility, preserve identity, enable re-application.
  update public.clubs
  set
    status = 'ARCHIVED',
    eligible_for_reapplication = true
  where id = p_club_id;

  -- 7. No audit logging table exists in this schema.

  return p_club_id;
end;
$$;

revoke all on function public.archive_owned_club(uuid)
from public, anon;

grant execute on function public.archive_owned_club(uuid)
to authenticated;
