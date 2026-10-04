-- Remove club event request feature (announcements cover club news/events).

revoke all on function public.submit_club_event_request(uuid, text, text, text, text, text)
from public, anon, authenticated;

revoke all on function public.review_club_event_request(uuid, text, text)
from public, anon, authenticated;

drop function if exists public.submit_club_event_request(uuid, text, text, text, text, text);
drop function if exists public.review_club_event_request(uuid, text, text);

drop trigger if exists set_club_event_requests_updated_at
on public.club_event_requests;

drop table if exists public.club_event_requests;
