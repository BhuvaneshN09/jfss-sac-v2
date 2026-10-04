-- Remove database helpers with no current application callers.
--
-- Historical migration files remain unchanged. This migration only removes
-- redundant live functions. Stored submission history and compatibility
-- aliases are preserved.

drop function if exists public.get_public_club_owners(uuid);

drop function if exists public.list_clubs_by_annual_status(text);

drop function if exists public.list_unclassified_club_origins();

drop function if exists public.count_active_club_advisors(uuid, text);

drop function if exists public.count_pending_supervisor_emails(uuid, text);

drop function if exists public.leave_club_as_owner(uuid);

drop function if exists public.admin_remove_club_owner(uuid, uuid);

drop function if exists public.default_school_period_slots();

drop function if exists public.assert_school_period_slots(jsonb);
