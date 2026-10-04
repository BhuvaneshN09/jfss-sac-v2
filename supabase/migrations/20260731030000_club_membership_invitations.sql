-- =========================================================
-- Club membership invitations (pending until accept/reject)
-- =========================================================

create table if not exists public.club_membership_invitations (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null
    references public.clubs(id)
    on delete restrict,
  invitee_user_id uuid not null
    references public.profiles(id)
    on delete cascade,
  invitee_email text not null,
  invited_by uuid not null
    references public.profiles(id)
    on delete restrict,
  offered_role text not null,
  status text not null default 'PENDING',
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  cancelled_at timestamptz,
  cancelled_by uuid
    references public.profiles(id)
    on delete set null,

  constraint club_membership_invitations_role_valid
    check (offered_role in ('OWNER', 'EXEC', 'MEMBER')),

  constraint club_membership_invitations_status_valid
    check (status in ('PENDING', 'ACCEPTED', 'REJECTED', 'CANCELLED')),

  constraint club_membership_invitations_email_lower
    check (invitee_email = lower(btrim(invitee_email))),

  constraint club_membership_invitations_email_pdsb
    check (invitee_email ~ '^[^[:space:]@]+@pdsb[.]net$'),

  constraint club_membership_invitations_no_self
    check (invitee_user_id <> invited_by),

  constraint club_membership_invitations_responded_shape
    check (
      (
        status = 'PENDING'
        and responded_at is null
        and cancelled_at is null
      )
      or (
        status in ('ACCEPTED', 'REJECTED')
        and responded_at is not null
        and cancelled_at is null
      )
      or (
        status = 'CANCELLED'
        and cancelled_at is not null
      )
    )
);

create unique index if not exists club_membership_invitations_pending_uidx
  on public.club_membership_invitations (club_id, invitee_user_id)
  where status = 'PENDING';

create index if not exists club_membership_invitations_invitee_pending_idx
  on public.club_membership_invitations (invitee_user_id, created_at desc)
  where status = 'PENDING';

create index if not exists club_membership_invitations_club_pending_idx
  on public.club_membership_invitations (club_id, created_at desc)
  where status = 'PENDING';

create index if not exists club_membership_invitations_club_owner_pending_idx
  on public.club_membership_invitations (club_id)
  where status = 'PENDING' and offered_role = 'OWNER';

alter table public.club_membership_invitations enable row level security;

revoke all on table public.club_membership_invitations
from public, anon;
grant select on table public.club_membership_invitations to authenticated;


create or replace function public.count_pending_owner_invitations(p_club_id uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer
  from public.club_membership_invitations
  where club_id = p_club_id
    and status = 'PENDING'
    and offered_role = 'OWNER';
$$;

revoke all on function public.count_pending_owner_invitations(uuid)
from public;
grant execute on function public.count_pending_owner_invitations(uuid)
to authenticated;


create or replace function public.club_allows_membership_changes(p_club_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.clubs c
    join public.club_school_years csy
      on csy.club_id = c.id
     and csy.school_year = public.get_current_club_school_year()
    where c.id = p_club_id
      and c.deleted_at is null
      and c.status = 'APPROVED'
      and csy.status in ('ACTIVE', 'PENDING_SUPERVISOR')
  );
$$;

revoke all on function public.club_allows_membership_changes(uuid)
from public;
grant execute on function public.club_allows_membership_changes(uuid)
to authenticated;


-- RLS: recipients see own; owners see outgoing for clubs they own.
drop policy if exists "club_invites_select_own" on public.club_membership_invitations;
create policy "club_invites_select_own"
on public.club_membership_invitations
for select
to authenticated
using (invitee_user_id = (select auth.uid()));

drop policy if exists "club_invites_select_owner" on public.club_membership_invitations;
create policy "club_invites_select_owner"
on public.club_membership_invitations
for select
to authenticated
using (
  public.has_club_role(club_id, array['OWNER'])
  or public.has_system_role('SAC_ADMIN')
);

-- No direct client inserts/updates/deletes — RPCs only.
revoke insert, update, delete on table public.club_membership_invitations
from authenticated, anon, public;


create or replace function public.create_club_membership_invitation(
  p_club_id uuid,
  p_email text,
  p_offered_role text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_role text;
  v_email text;
  v_invitee public.profiles%rowtype;
  v_existing public.club_memberships%rowtype;
  v_invitation_id uuid;
  v_owner_slots integer;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_club_id is null then
    raise exception 'Club is required';
  end if;

  if not public.has_club_role(p_club_id, array['OWNER']) then
    raise exception 'Only an active club OWNER may send invitations'
      using errcode = '42501';
  end if;

  if not public.club_allows_membership_changes(p_club_id) then
    raise exception
      'This club is not currently eligible for membership invitations';
  end if;

  v_role := upper(btrim(coalesce(p_offered_role, '')));
  if v_role not in ('OWNER', 'EXEC', 'MEMBER') then
    raise exception 'Invalid membership role';
  end if;

  v_email := lower(btrim(coalesce(p_email, '')));
  if v_email is null or v_email !~ '^[^[:space:]@]+@pdsb[.]net$' then
    raise exception 'Enter a complete @pdsb.net email address';
  end if;

  select * into v_invitee
  from public.profiles
  where email = v_email
    and is_active = true;

  if not found then
    raise exception
      'No eligible registered student was found with that email';
  end if;

  if v_invitee.id = v_user_id then
    raise exception 'You cannot invite yourself';
  end if;

  perform 1
  from public.club_memberships
  where club_id = p_club_id
  for update;

  select * into v_existing
  from public.club_memberships
  where club_id = p_club_id
    and user_id = v_invitee.id
  for update;

  if found and v_existing.status = 'ACTIVE' then
    raise exception 'This student is already an active member of this club';
  end if;

  if exists (
    select 1
    from public.club_membership_invitations i
    where i.club_id = p_club_id
      and i.invitee_user_id = v_invitee.id
      and i.status = 'PENDING'
  ) then
    raise exception
      'A pending invitation already exists for this student';
  end if;

  if v_role = 'OWNER' then
    v_owner_slots :=
      public.count_active_club_owners(p_club_id)
      + public.count_pending_owner_invitations(p_club_id);
    if v_owner_slots >= 3 then
      raise exception
        'A club may have at most three active owners, including pending owner invitations';
    end if;
  end if;

  insert into public.club_membership_invitations (
    club_id,
    invitee_user_id,
    invitee_email,
    invited_by,
    offered_role,
    status
  )
  values (
    p_club_id,
    v_invitee.id,
    v_email,
    v_user_id,
    v_role,
    'PENDING'
  )
  returning id into v_invitation_id;

  return v_invitation_id;
end;
$$;

revoke all on function public.create_club_membership_invitation(uuid, text, text)
from public, anon;
grant execute on function public.create_club_membership_invitation(uuid, text, text)
to authenticated;


create or replace function public.accept_club_membership_invitation(
  p_invitation_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_inv public.club_membership_invitations%rowtype;
  v_existing public.club_memberships%rowtype;
  v_now timestamptz := now();
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_invitation_id is null then
    raise exception 'Invitation is required';
  end if;

  select * into v_inv
  from public.club_membership_invitations
  where id = p_invitation_id
  for update;

  if not found then
    raise exception 'Invitation not found';
  end if;

  if v_inv.invitee_user_id <> v_user_id then
    raise exception 'Only the invited student may accept this invitation'
      using errcode = '42501';
  end if;

  if v_inv.status <> 'PENDING' then
    raise exception 'This invitation is no longer pending';
  end if;

  if not public.club_allows_membership_changes(v_inv.club_id) then
    raise exception
      'This club is no longer eligible for membership changes';
  end if;

  perform 1
  from public.club_memberships
  where club_id = v_inv.club_id
  for update;

  perform 1
  from public.club_membership_invitations
  where club_id = v_inv.club_id
    and status = 'PENDING'
    and offered_role = 'OWNER'
  for update;

  if v_inv.offered_role = 'OWNER'
     and public.count_active_club_owners(v_inv.club_id) >= 3 then
    raise exception 'A club may have at most three active owners';
  end if;

  select * into v_existing
  from public.club_memberships
  where club_id = v_inv.club_id
    and user_id = v_user_id
  for update;

  if found and v_existing.status = 'ACTIVE' then
    update public.club_membership_invitations
    set
      status = 'CANCELLED',
      cancelled_at = v_now,
      cancelled_by = v_user_id
    where id = p_invitation_id;

    raise exception 'You are already an active member of this club';
  end if;

  if found then
    update public.club_memberships
    set
      role = v_inv.offered_role,
      status = 'ACTIVE',
      added_by = v_inv.invited_by,
      updated_at = v_now
    where club_id = v_inv.club_id
      and user_id = v_user_id;
  else
    insert into public.club_memberships (
      club_id, user_id, role, status, added_by, joined_at
    )
    values (
      v_inv.club_id,
      v_user_id,
      v_inv.offered_role,
      'ACTIVE',
      v_inv.invited_by,
      v_now
    );
  end if;

  update public.club_membership_invitations
  set
    status = 'ACCEPTED',
    responded_at = v_now
  where id = p_invitation_id;

  return v_inv.club_id;
end;
$$;

revoke all on function public.accept_club_membership_invitation(uuid)
from public, anon;
grant execute on function public.accept_club_membership_invitation(uuid)
to authenticated;


create or replace function public.reject_club_membership_invitation(
  p_invitation_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_inv public.club_membership_invitations%rowtype;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select * into v_inv
  from public.club_membership_invitations
  where id = p_invitation_id
  for update;

  if not found then
    raise exception 'Invitation not found';
  end if;

  if v_inv.invitee_user_id <> v_user_id then
    raise exception 'Only the invited student may reject this invitation'
      using errcode = '42501';
  end if;

  if v_inv.status <> 'PENDING' then
    raise exception 'This invitation is no longer pending';
  end if;

  update public.club_membership_invitations
  set
    status = 'REJECTED',
    responded_at = now()
  where id = p_invitation_id;

  return p_invitation_id;
end;
$$;

revoke all on function public.reject_club_membership_invitation(uuid)
from public, anon;
grant execute on function public.reject_club_membership_invitation(uuid)
to authenticated;


create or replace function public.cancel_club_membership_invitation(
  p_invitation_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_inv public.club_membership_invitations%rowtype;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select * into v_inv
  from public.club_membership_invitations
  where id = p_invitation_id
  for update;

  if not found then
    raise exception 'Invitation not found';
  end if;

  if not (
    public.has_club_role(v_inv.club_id, array['OWNER'])
    or public.has_system_role('SAC_ADMIN')
  ) then
    raise exception 'Only an active club OWNER may cancel invitations'
      using errcode = '42501';
  end if;

  if v_inv.status <> 'PENDING' then
    raise exception 'This invitation is no longer pending';
  end if;

  update public.club_membership_invitations
  set
    status = 'CANCELLED',
    cancelled_at = now(),
    cancelled_by = v_user_id
  where id = p_invitation_id;

  return p_invitation_id;
end;
$$;

revoke all on function public.cancel_club_membership_invitation(uuid)
from public, anon;
grant execute on function public.cancel_club_membership_invitation(uuid)
to authenticated;


create or replace function public.cancel_pending_club_membership_invitations(
  p_club_id uuid,
  p_actor uuid default null,
  p_reason text default null
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  update public.club_membership_invitations
  set
    status = 'CANCELLED',
    cancelled_at = now(),
    cancelled_by = p_actor
  where club_id = p_club_id
    and status = 'PENDING';

  get diagnostics v_count = row_count;
  return coalesce(v_count, 0);
end;
$$;

revoke all on function public.cancel_pending_club_membership_invitations(uuid, uuid, text)
from public, anon;


-- Patch archive to cancel pending invitations.
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
  v_terminal boolean := false;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  if p_club_id is null then
    raise exception 'Club ID is required';
  end if;

  if not public.has_club_role(p_club_id, array['OWNER']) then
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

  if v_club.deleted_at is not null then
    perform public.cancel_pending_club_membership_invitations(
      p_club_id, v_user_id, 'Club already removed'
    );
    return p_club_id;
  end if;

  if v_club.status = 'ARCHIVED'
     and v_club.creation_origin is distinct from 'NEW_APPLICATION' then
    perform public.cancel_pending_club_membership_invitations(
      p_club_id, v_user_id, 'Club already archived'
    );
    return p_club_id;
  end if;

  v_terminal := (v_club.creation_origin = 'NEW_APPLICATION');

  if v_club.status = 'ARCHIVED' and v_terminal then
    update public.clubs
    set
      deleted_at = coalesce(archived_at, v_now),
      eligible_for_reapplication = false,
      archived_by = coalesce(archived_by, v_user_id),
      archived_at = coalesce(archived_at, v_now),
      last_active_school_year = coalesce(last_active_school_year, v_year)
    where id = p_club_id;

    perform public.cancel_pending_club_membership_invitations(
      p_club_id, v_user_id, 'Club permanently removed'
    );
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
      case
        when v_terminal then
          'Cancelled because the club was permanently archived by an owner.'
        else
          'Cancelled because the club was archived by an owner.'
      end
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
    case
      when v_terminal then 'Club permanently archived'
      else 'Club archived'
    end
  );

  if v_terminal then
    update public.clubs
    set
      status = 'ARCHIVED',
      eligible_for_reapplication = false,
      deleted_at = v_now,
      archived_at = v_now,
      archived_by = v_user_id,
      last_active_school_year = v_year
    where id = p_club_id;
  else
    update public.clubs
    set
      status = 'ARCHIVED',
      eligible_for_reapplication = true,
      deleted_at = null,
      archived_at = v_now,
      archived_by = v_user_id,
      last_active_school_year = v_year
    where id = p_club_id;
  end if;

  return p_club_id;
end;
$$;

revoke all on function public.archive_owned_club(uuid)
from public, anon;
grant execute on function public.archive_owned_club(uuid)
to authenticated;


-- Owner lookup for invitations (exact email only).
create or replace function public.find_student_by_email(
  p_club_id uuid,
  p_email text
)
returns table (
  id uuid,
  full_name text,
  email text,
  avatar_url text,
  existing_role text,
  existing_status text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_caller_id uuid;
  v_normalized_email text;
  v_can_manage_club boolean;
begin
  v_caller_id := (select auth.uid());

  if v_caller_id is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  if p_club_id is null then
    raise exception 'Club ID is required';
  end if;

  if not exists (
    select 1
    from public.clubs as club
    where club.id = p_club_id
      and club.status = 'APPROVED'
      and club.deleted_at is null
  ) then
    raise exception 'Club not found or unavailable';
  end if;

  v_normalized_email := lower(btrim(p_email));

  if v_normalized_email is null
     or v_normalized_email !~
       '^[^[:space:]@]+@pdsb[.]net$' then
    raise exception 'A complete @pdsb.net email is required';
  end if;

  v_can_manage_club :=
    public.has_club_role(p_club_id, array['OWNER'])
    or public.has_system_role('SAC_ADMIN');

  if not v_can_manage_club then
    raise exception 'You do not have permission to search for this club'
      using errcode = '42501';
  end if;

  return query
  select
    profile.id,
    profile.full_name,
    profile.email,
    profile.avatar_url,
    membership.role as existing_role,
    membership.status as existing_status
  from public.profiles as profile
  left join public.club_memberships as membership
    on membership.club_id = p_club_id
   and membership.user_id = profile.id
  where profile.email = v_normalized_email
    and profile.is_active = true
  limit 1;
end;
$$;

revoke all
on function public.find_student_by_email(uuid, text)
from public, anon, authenticated;

grant execute
on function public.find_student_by_email(uuid, text)
to authenticated;
