-- Expose only active owner names for publicly active clubs.
-- This avoids making the profiles table publicly readable.

create or replace function public.get_public_club_owners(p_club_id uuid)
returns table (
  owner_name text
)
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(nullif(btrim(p.full_name), ''), 'Club owner') as owner_name
  from public.club_memberships as m
  join public.profiles as p
    on p.id = m.user_id
  where m.club_id = p_club_id
    and m.role = 'OWNER'
    and m.status = 'ACTIVE'
    and public.club_is_publicly_active(p_club_id)
  order by lower(coalesce(nullif(btrim(p.full_name), ''), 'Club owner'));
$$;

revoke all on function public.get_public_club_owners(uuid)
from public;

grant execute on function public.get_public_club_owners(uuid)
to anon, authenticated;
