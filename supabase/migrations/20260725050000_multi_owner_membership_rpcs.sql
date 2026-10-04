-- =========================================================
-- Multiple OWNER enforcement (min 1 / max 3) + membership RPCs
-- =========================================================

create or replace function public.count_active_club_owners(p_club_id uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer
  from public.club_memberships
  where club_id = p_club_id
    and role = 'OWNER'
    and status = 'ACTIVE';
$$;

revoke all on function public.count_active_club_owners(uuid) from public;
grant execute on function public.count_active_club_owners(uuid) to authenticated;


create or replace function public.enforce_club_owner_limits()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_club_id uuid;
  v_owner_count integer;
  v_annual text;
begin
  v_club_id := coalesce(new.club_id, old.club_id);

  v_owner_count := public.count_active_club_owners(v_club_id);

  if v_owner_count > 3 then
    raise exception 'A club may have at most three active OWNERs';
  end if;

  v_annual := public.get_club_current_annual_status(v_club_id);

  if v_annual in ('PENDING_SUPERVISOR', 'ACTIVE') and v_owner_count < 1 then
    raise exception
      'A PENDING_SUPERVISOR or ACTIVE club must retain at least one active OWNER';
  end if;

  return coalesce(new, old);
end;
$$;

drop trigger if exists enforce_club_owner_limits_trigger on public.club_memberships;
create constraint trigger enforce_club_owner_limits_trigger
after insert or update or delete
on public.club_memberships
deferrable initially deferred
for each row
execute function public.enforce_club_owner_limits();


-- OWNERs may add OWNER/EXEC/MEMBER; EXECs may add MEMBER only.
drop policy if exists "club_memberships_club_leader_insert"
on public.club_memberships;

create policy "club_memberships_club_leader_insert"
on public.club_memberships
for insert
to authenticated
with check (
  added_by = (select auth.uid())
  and status = 'ACTIVE'
  and (
    (
      role in ('OWNER', 'EXEC', 'MEMBER')
      and public.has_club_role(club_id, array['OWNER'])
      and (
        role <> 'OWNER'
        or public.count_active_club_owners(club_id) < 3
      )
    )
    or
    (
      role = 'MEMBER'
      and public.has_club_role(club_id, array['EXEC'])
    )
  )
);


create or replace function public.add_club_membership(
  p_club_id uuid,
  p_target_user_id uuid,
  p_role text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_role text;
  v_existing public.club_memberships%rowtype;
  v_owner_count integer;
  v_is_admin boolean;
  v_is_owner boolean;
  v_is_exec boolean;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  v_role := upper(btrim(p_role));
  if v_role not in ('OWNER', 'EXEC', 'MEMBER') then
    raise exception 'Invalid membership role';
  end if;

  if p_club_id is null or p_target_user_id is null then
    raise exception 'Club and target user are required';
  end if;

  v_is_admin := public.has_system_role('SAC_ADMIN');
  v_is_owner := public.has_club_role(p_club_id, array['OWNER']);
  v_is_exec := public.has_club_role(p_club_id, array['EXEC']);

  if not (v_is_admin or v_is_owner or v_is_exec) then
    raise exception 'Not authorized to manage memberships' using errcode = '42501';
  end if;

  if v_role = 'OWNER' and not (v_is_admin or v_is_owner) then
    raise exception 'Only OWNERs or SAC_ADMIN may add another OWNER'
      using errcode = '42501';
  end if;

  if v_role = 'EXEC' and not (v_is_admin or v_is_owner) then
    raise exception 'Only OWNERs or SAC_ADMIN may add an EXEC'
      using errcode = '42501';
  end if;

  if v_role = 'MEMBER' and not (v_is_admin or v_is_owner or v_is_exec) then
    raise exception 'Not authorized to add members' using errcode = '42501';
  end if;

  perform 1
  from public.club_memberships
  where club_id = p_club_id
  for update;

  select * into v_existing
  from public.club_memberships
  where club_id = p_club_id
    and user_id = p_target_user_id
  for update;

  v_owner_count := public.count_active_club_owners(p_club_id);

  if v_role = 'OWNER'
     and (
       v_existing is null
       or v_existing.role is distinct from 'OWNER'
       or v_existing.status is distinct from 'ACTIVE'
     )
     and v_owner_count >= 3 then
    raise exception 'A club may have at most three active OWNERs';
  end if;

  if found then
    if v_existing.status = 'ACTIVE' and v_existing.role = v_role then
      raise exception 'This student already has that active role in this club';
    end if;

    update public.club_memberships
    set role = v_role,
        status = 'ACTIVE',
        added_by = v_user_id,
        updated_at = now()
    where club_id = p_club_id
      and user_id = p_target_user_id;
  else
    insert into public.club_memberships (
      club_id, user_id, role, status, added_by
    )
    values (
      p_club_id, p_target_user_id, v_role, 'ACTIVE', v_user_id
    );
  end if;
end;
$$;

revoke all on function public.add_club_membership(uuid, uuid, text)
from public, anon;
grant execute on function public.add_club_membership(uuid, uuid, text)
to authenticated;


create or replace function public.leave_club_as_owner(
  p_club_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_owner_count integer;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not public.has_club_role(p_club_id, array['OWNER']) then
    raise exception 'Only an active OWNER can leave as owner'
      using errcode = '42501';
  end if;

  perform 1
  from public.club_memberships
  where club_id = p_club_id
  for update;

  v_owner_count := public.count_active_club_owners(p_club_id);
  if v_owner_count <= 1 then
    raise exception
      'You cannot leave as OWNER while you are the only active OWNER';
  end if;

  delete from public.club_memberships
  where club_id = p_club_id
    and user_id = v_user_id
    and role = 'OWNER';
end;
$$;

revoke all on function public.leave_club_as_owner(uuid)
from public, anon;
grant execute on function public.leave_club_as_owner(uuid)
to authenticated;


create or replace function public.admin_remove_club_owner(
  p_club_id uuid,
  p_target_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_owner_count integer;
  v_annual text;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not public.has_system_role('SAC_ADMIN') then
    raise exception 'SAC_ADMIN role required' using errcode = '42501';
  end if;

  perform 1
  from public.club_memberships
  where club_id = p_club_id
  for update;

  if not exists (
    select 1
    from public.club_memberships
    where club_id = p_club_id
      and user_id = p_target_user_id
      and role = 'OWNER'
      and status = 'ACTIVE'
  ) then
    raise exception 'Target user is not an active OWNER of this club';
  end if;

  v_owner_count := public.count_active_club_owners(p_club_id);
  v_annual := public.get_club_current_annual_status(p_club_id);

  if v_annual in ('PENDING_SUPERVISOR', 'ACTIVE') and v_owner_count <= 1 then
    raise exception
      'Cannot remove the final OWNER of a PENDING_SUPERVISOR or ACTIVE club';
  end if;

  delete from public.club_memberships
  where club_id = p_club_id
    and user_id = p_target_user_id
    and role = 'OWNER';
end;
$$;

revoke all on function public.admin_remove_club_owner(uuid, uuid)
from public, anon;
grant execute on function public.admin_remove_club_owner(uuid, uuid)
to authenticated;
