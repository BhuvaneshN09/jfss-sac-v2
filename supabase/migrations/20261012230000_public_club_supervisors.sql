-- Current-year approved teacher supervisors for the public club details page.
-- Names only. Limited to clubs that are already publicly visible.

create or replace function public.get_public_club_supervisors(
  p_club_id uuid
)
returns table (
  id uuid,
  supervisor_name text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    advisor.id,
    advisor.supervisor_name
  from public.club_advisors as advisor
  join public.clubs as club
    on club.id = advisor.club_id
  where advisor.club_id = p_club_id
    and advisor.status = 'ACTIVE'
    and advisor.school_year = public.get_current_club_school_year()
    and club.deleted_at is null
    and club.status = 'APPROVED'
    and public.club_is_publicly_active(club.id)
  order by advisor.supervisor_name;
$$;

comment on function public.get_public_club_supervisors(uuid) is
  'Public club page: current-year active teacher supervisor names.';

revoke all on function public.get_public_club_supervisors(uuid)
from public;

grant execute on function public.get_public_club_supervisors(uuid)
to anon, authenticated;
