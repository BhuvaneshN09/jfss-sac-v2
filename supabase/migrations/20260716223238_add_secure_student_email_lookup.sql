-- =========================================================
-- Privacy-preserving exact-email student lookup
-- =========================================================

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

  -- Make sure the club exists and is currently approved.
  if not exists (
    select 1
    from public.clubs as club
    where club.id = p_club_id
      and club.status = 'APPROVED'
  ) then
    raise exception 'Club not found or unavailable';
  end if;

  v_normalized_email := lower(btrim(p_email));

  -- Requires one complete, exact PDSB address.
  -- No partial names, wildcards or autocomplete queries.
  if v_normalized_email is null
     or v_normalized_email !~
       '^[^[:space:]@]+@pdsb[.]net$' then
    raise exception 'A complete @pdsb.net email is required';
  end if;

  -- Club owners and executives may perform exact lookup.
  -- SAC admins may also perform lookup.
  v_can_manage_club :=
    exists (
      select 1
      from public.club_memberships as membership
      where membership.club_id = p_club_id
        and membership.user_id = v_caller_id
        and membership.status = 'ACTIVE'
        and membership.role in ('OWNER', 'EXEC')
    )
    or public.has_system_role('SAC_ADMIN');

  if not v_can_manage_club then
    raise exception 'You do not have permission to search for this club'
      using errcode = '42501';
  end if;

  -- Return zero or one registered, active student.
  -- The left join also tells the UI whether the student
  -- already belongs to this particular club.
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

-- PostgreSQL functions are executable by PUBLIC by default unless
-- privileges are restricted explicitly.

revoke all
on function public.find_student_by_email(uuid, text)
from public, anon, authenticated;

grant execute
on function public.find_student_by_email(uuid, text)
to authenticated;