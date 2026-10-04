-- Verification checks after Fraser Chefs restore

select
  c.id,
  c.name,
  c.slug,
  c.status,
  c.eligible_for_reapplication,
  left(c.description, 60) as description_preview,
  c.contact_email,
  c.archived_at
from public.clubs c
where
  c.id = 'adbff931-c030-4ac5-9ed6-78b9105a3dbd'
  or lower(c.name) = lower('Fraser Chefs')
  or c.slug = 'fraser-chefs';

select count(*)::int as club_row_count
from public.clubs
where lower(name) = lower('Fraser Chefs') or slug = 'fraser-chefs';

select school_year, status
from public.club_school_years
where club_id = 'adbff931-c030-4ac5-9ed6-78b9105a3dbd';

select role, status, count(*)::int as n
from public.club_memberships
where club_id = 'adbff931-c030-4ac5-9ed6-78b9105a3dbd'
group by role, status;

select count(*)::int as active_memberships
from public.club_memberships
where club_id = 'adbff931-c030-4ac5-9ed6-78b9105a3dbd'
  and status = 'ACTIVE';

select count(*)::int as in_public_active
from public.public_active_clubs
where id = 'adbff931-c030-4ac5-9ed6-78b9105a3dbd'
   or slug = 'fraser-chefs';

select id, school_year, status
from public.club_reapplication_requests
where club_id = 'adbff931-c030-4ac5-9ed6-78b9105a3dbd'
order by submitted_at desc;

-- Eligible selector logic (same filters as list_eligible_clubs_for_reapplication)
select
  c.id,
  c.name,
  c.eligible_for_reapplication,
  csy.status as annual_status,
  not exists (
    select 1
    from public.club_reapplication_requests r
    where r.club_id = c.id
      and r.school_year = '2026-2027'
      and r.status in (
        'SUBMITTED',
        'UNDER_REVIEW',
        'CHANGES_REQUESTED',
        'APPROVED'
      )
  ) as reapply_selector_eligible
from public.clubs c
join public.club_school_years csy
  on csy.club_id = c.id
 and csy.school_year = '2026-2027'
where c.id = 'adbff931-c030-4ac5-9ed6-78b9105a3dbd';
