-- Close new Club Promo Lunch sign-ups.
-- Existing rows stay. Review and public confirmation are unchanged.

create or replace function public.submit_club_promo_lunch_request(
  p_request_id uuid,
  p_club_id uuid,
  p_booth_days text,
  p_approval_email_received boolean,
  p_representatives text,
  p_school_year text default '2026-2027'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception 'Club Promo Lunch sign-ups are closed';
end;
$$;

revoke all on function public.submit_club_promo_lunch_request(
  uuid, uuid, text, boolean, text, text
) from public, anon;

grant execute on function public.submit_club_promo_lunch_request(
  uuid, uuid, text, boolean, text, text
) to authenticated;
