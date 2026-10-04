-- Preserve the target club name for re-applications whose inactive club row
-- is not visible through the applicant's normal RLS relation.

alter table public.club_reapplication_requests
  add column if not exists club_name text;

update public.club_reapplication_requests as request
set club_name = club.name
from public.clubs as club
where request.club_id = club.id
  and request.club_name is null;

create or replace function public.snapshot_reapplication_club_name()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  select name
  into new.club_name
  from public.clubs
  where id = new.club_id;

  return new;
end;
$$;

drop trigger if exists snapshot_reapplication_club_name_trigger
on public.club_reapplication_requests;

create trigger snapshot_reapplication_club_name_trigger
before insert or update of club_id
on public.club_reapplication_requests
for each row
execute function public.snapshot_reapplication_club_name();

