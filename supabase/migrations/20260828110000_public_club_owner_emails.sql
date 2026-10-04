-- Dedicated email RPC so the public club page cannot receive the older
-- owner-name response shape.

create or replace function public.get_public_club_owner_emails(p_club_id uuid)
returns table (
  owner_email text
)
language sql
stable
security definer
set search_path = ''
as $$
  select lower(p.email) as owner_email
  from public.club_memberships as m
  join public.profiles as p
    on p.id = m.user_id
  where m.club_id = p_club_id
    and m.role = 'OWNER'
    and m.status = 'ACTIVE'
    and public.club_is_publicly_active(p_club_id)
  order by lower(p.email);
$$;

revoke all on function public.get_public_club_owner_emails(uuid)
from public;

grant execute on function public.get_public_club_owner_emails(uuid)
to anon, authenticated;
