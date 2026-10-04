-- Club Promo Lunch booth days are October 6 and 7.

alter table public.club_promo_lunch_requests
  drop constraint if exists promo_lunch_booth_days_valid;

update public.club_promo_lunch_requests
set booth_days = case booth_days
  when 'OCTOBER_1' then 'OCTOBER_6'
  when 'OCTOBER_2' then 'OCTOBER_7'
  else booth_days
end
where booth_days in ('OCTOBER_1', 'OCTOBER_2');

alter table public.club_promo_lunch_requests
  add constraint promo_lunch_booth_days_valid
    check (booth_days in ('OCTOBER_6', 'OCTOBER_7', 'BOTH'));
