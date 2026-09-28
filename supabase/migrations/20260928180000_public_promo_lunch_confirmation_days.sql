-- Return the approved booth days so public club pages can show them.
-- Return type changes from boolean to text, so the function must be replaced.

drop function if exists public.get_public_club_promo_lunch_confirmation(uuid);

create function public.get_public_club_promo_lunch_confirmation(
  p_club_id uuid
)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select request.booth_days
  from public.club_promo_lunch_requests as request
  join public.clubs as club
    on club.id = request.club_id
  where request.club_id = p_club_id
    and request.status = 'APPROVED'
    and request.school_year = public.get_current_club_school_year()
    and club.status = 'APPROVED'
  limit 1;
$$;

revoke all on function public.get_public_club_promo_lunch_confirmation(uuid)
from public;
grant execute on function public.get_public_club_promo_lunch_confirmation(uuid)
to anon, authenticated;
