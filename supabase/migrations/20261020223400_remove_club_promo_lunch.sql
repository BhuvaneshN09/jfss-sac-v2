-- Remove Club Promo Lunch sign-ups, reviews, and public confirmation.

drop function if exists public.submit_club_promo_lunch_request(
  uuid, uuid, text, boolean, text, text
);
drop function if exists public.review_club_promo_lunch_request(uuid, text, text);
drop function if exists public.get_public_club_promo_lunch_confirmation(uuid);
drop function if exists public.get_public_confirmed_promo_lunch_club_ids();

drop table if exists public.club_promo_lunch_requests;
