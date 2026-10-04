-- Archiving a club closes its current-year re-application so the club can be
-- selected for a new re-application later.

create or replace function public.reject_reapplications_when_club_archived()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'ARCHIVED'
     and old.status is distinct from 'ARCHIVED' then
    update public.club_reapplication_requests
    set
      status = 'REJECTED',
      review_notes = coalesce(
        nullif(btrim(coalesce(review_notes, '')), ''),
        'Closed because the club was archived.'
      ),
      reviewed_by = coalesce(new.archived_by, (select auth.uid())),
      reviewed_at = coalesce(reviewed_at, now())
    where club_id = new.id
      and school_year = public.get_current_club_school_year()
      and status in (
        'SUBMITTED',
        'UNDER_REVIEW',
        'CHANGES_REQUESTED',
        'APPROVED'
      );
  end if;

  return new;
end;
$$;

revoke all on function public.reject_reapplications_when_club_archived()
from public, anon, authenticated;

drop trigger if exists reject_reapplications_when_club_archived_trigger
on public.clubs;

create trigger reject_reapplications_when_club_archived_trigger
after update of status
on public.clubs
for each row
execute function public.reject_reapplications_when_club_archived();

-- Repair archived clubs that were archived before this rule existed.
update public.club_reapplication_requests as request
set
  status = 'REJECTED',
  review_notes = coalesce(
    nullif(btrim(coalesce(request.review_notes, '')), ''),
    'Closed because the club was archived.'
  ),
  reviewed_by = coalesce(club.archived_by, request.reviewed_by),
  reviewed_at = coalesce(request.reviewed_at, now())
from public.clubs as club
where request.club_id = club.id
  and club.status = 'ARCHIVED'
  and request.school_year = public.get_current_club_school_year()
  and request.status in (
    'SUBMITTED',
    'UNDER_REVIEW',
    'CHANGES_REQUESTED',
    'APPROVED'
  );
