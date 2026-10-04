-- Inspect Fraser Chefs related records
select
  'clubs' as src,
  c.id::text as club_id,
  c.name,
  c.slug,
  c.status,
  c.eligible_for_reapplication::text as eligible,
  c.is_imported_seed::text as seeded
from public.clubs c
where
  c.id = 'adbff931-c030-4ac5-9ed6-78b9105a3dbd'
  or lower(c.name) = lower('Fraser Chefs')
  or c.slug = 'fraser-chefs';

select
  csy.school_year,
  csy.status as annual_status,
  csy.supervisor_due_at,
  csy.activated_at
from public.club_school_years csy
where csy.club_id = 'adbff931-c030-4ac5-9ed6-78b9105a3dbd'
order by csy.school_year;

select
  m.user_id,
  m.role,
  m.status
from public.club_memberships m
where m.club_id = 'adbff931-c030-4ac5-9ed6-78b9105a3dbd'
order by m.role, m.status;

select
  r.id,
  r.school_year,
  r.status,
  r.submitted_at
from public.club_reapplication_requests r
where r.club_id = 'adbff931-c030-4ac5-9ed6-78b9105a3dbd'
order by r.submitted_at desc;
