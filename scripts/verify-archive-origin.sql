-- Verification checklist for archive origin branching.
-- Run in the Supabase SQL editor after migration
-- 20260731020000_archive_origin_terminal_delete.sql.
--
-- Expected:
-- 1) creation_origin populated; UNKNOWN rows listed for manual review
-- 2) NEW_APPLICATION + ARCHIVED rows have deleted_at and eligible=false
-- 3) list_eligible excludes deleted / NEW_APPLICATION clubs
-- 4) list_archived excludes deleted_at rows

select creation_origin, count(*) as clubs
from public.clubs
group by creation_origin
order by creation_origin;

select id, name, slug, status, is_imported_seed, created_by
from public.clubs
where creation_origin = 'UNKNOWN'
  and deleted_at is null
order by name;

select id, name, status, deleted_at, eligible_for_reapplication
from public.clubs
where creation_origin = 'NEW_APPLICATION'
  and status = 'ARCHIVED';

select count(*) as deleted_in_archived_list_should_be_zero
from public.clubs
where status = 'ARCHIVED'
  and deleted_at is not null
  and eligible_for_reapplication = true;
