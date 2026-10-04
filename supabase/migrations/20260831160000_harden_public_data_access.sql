-- Limit public request reads to intentionally public fields and approved assets.

revoke select on table public.club_event_requests from anon;
drop policy if exists "club_event_requests_select_approved_public"
on public.club_event_requests;

revoke select on table public.club_promo_lunch_requests from anon;
drop policy if exists "club_promo_lunch_select_approved_public"
on public.club_promo_lunch_requests;

create or replace function public.get_public_club_events()
returns table (
  id uuid,
  club_id uuid,
  event_name text,
  event_description text,
  event_date date,
  event_end_date date,
  photo_storage_path text,
  club_name text,
  club_slug text
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
    club.slug
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

create or replace function public.get_public_club_promo_lunch_confirmation(
  p_club_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.club_promo_lunch_requests as request
    join public.clubs as club
      on club.id = request.club_id
    where request.club_id = p_club_id
      and request.status = 'APPROVED'
      and request.school_year = public.get_current_club_school_year()
      and club.status = 'APPROVED'
  );
$$;

revoke all on function public.get_public_club_promo_lunch_confirmation(uuid)
from public;
grant execute on function public.get_public_club_promo_lunch_confirmation(uuid)
to anon, authenticated;

create or replace function public.get_public_confirmed_promo_lunch_club_ids()
returns table (club_id uuid)
language sql
stable
security definer
set search_path = ''
as $$
  select request.club_id
  from public.club_promo_lunch_requests as request
  join public.clubs as club
    on club.id = request.club_id
  where request.status = 'APPROVED'
    and request.school_year = public.get_current_club_school_year()
    and club.status = 'APPROVED';
$$;

revoke all on function public.get_public_confirmed_promo_lunch_club_ids()
from public;
grant execute on function public.get_public_confirmed_promo_lunch_club_ids()
to anon, authenticated;

revoke all on function public.get_public_club_owner_emails(uuid)
from public, anon, authenticated;

revoke all on function public.refresh_announcement_lifecycle()
from public, anon, authenticated;

drop view if exists public.public_active_clubs;

create view public.public_active_clubs
with (security_invoker = true)
as
select
  club.id,
  club.name,
  club.slug,
  club.short_description,
  club.description,
  club.logo_url,
  club.banner_url,
  club.contact_email,
  club.instagram_handle,
  club.meeting_location,
  club.meeting_schedule,
  club.meeting_frequency,
  club.meeting_days,
  club.meeting_time_details,
  club.status as club_record_status,
  club_school_year.school_year,
  club_school_year.status as annual_status,
  club_school_year.activated_at,
  club.created_at,
  club.updated_at
from public.clubs as club
join public.club_school_years as club_school_year
  on club_school_year.club_id = club.id
where club_school_year.school_year = public.get_current_club_school_year()
  and club_school_year.status = 'ACTIVE'
  and club.status = 'APPROVED';

grant select on public.public_active_clubs
to anon, authenticated;

update storage.buckets
set public = false
where id in ('club-logos', 'club-event-photos');

create or replace function public.is_public_club_logo(p_path text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.clubs as club
    where club.logo_url = p_path
      and club.status = 'APPROVED'
      and public.club_is_publicly_active(club.id)
  );
$$;

create or replace function public.is_public_event_photo(p_path text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.club_event_requests as event_request
    where event_request.photo_storage_path = p_path
      and event_request.status = 'APPROVED'
      and public.club_is_publicly_active(event_request.club_id)
  );
$$;

revoke all on function public.is_public_club_logo(text)
from public;
grant execute on function public.is_public_club_logo(text)
to anon, authenticated;

revoke all on function public.is_public_event_photo(text)
from public;
grant execute on function public.is_public_event_photo(text)
to anon, authenticated;

drop policy if exists "club_logos_select_public" on storage.objects;
drop policy if exists "club_logos_select_sac" on storage.objects;
drop policy if exists "club_event_photos_select_public" on storage.objects;

create policy "club_logos_select_approved_public"
on storage.objects
for select
to anon, authenticated
using (
  bucket_id = 'club-logos'
  and public.is_public_club_logo(storage.objects.name)
);

create policy "club_logos_select_reviewers"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'club-logos'
  and public.can_read_review_queues()
);

create policy "club_logos_select_own"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'club-logos'
  and (storage.foldername(name))[2] = (select auth.uid())::text
);

create policy "club_event_photos_select_approved_public"
on storage.objects
for select
to anon, authenticated
using (
  bucket_id = 'club-event-photos'
  and public.is_public_event_photo(storage.objects.name)
);

create policy "club_event_photos_select_reviewers"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'club-event-photos'
  and public.can_read_review_queues()
);

create policy "club_event_photos_select_own"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'club-event-photos'
  and (storage.foldername(name))[2] = (select auth.uid())::text
);

