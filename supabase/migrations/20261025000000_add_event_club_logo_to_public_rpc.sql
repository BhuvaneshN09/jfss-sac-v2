-- Include the approved hosting club's public logo with each public event.

drop function if exists public.get_public_club_events();

create function public.get_public_club_events()
returns table (
  id uuid,
  club_id uuid,
  event_name text,
  event_description text,
  event_date date,
  event_end_date date,
  photo_storage_path text,
  club_name text,
  club_slug text,
  club_logo_url text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    event_request.id,
    event_request.club_id,
    event_request.event_name,
    event_request.event_description,
    event_request.event_date,
    event_request.event_end_date,
    event_request.photo_storage_path,
    club.name,
    club.slug,
    club.logo_url
  from public.club_event_requests as event_request
  join public.clubs as club
    on club.id = event_request.club_id
  where event_request.status = 'APPROVED'
    and club.status = 'APPROVED'
    and public.club_is_publicly_active(event_request.club_id)
  order by event_request.event_date asc, event_request.submitted_at asc;
$$;

revoke all on function public.get_public_club_events()
from public;
grant execute on function public.get_public_club_events()
to anon, authenticated;
