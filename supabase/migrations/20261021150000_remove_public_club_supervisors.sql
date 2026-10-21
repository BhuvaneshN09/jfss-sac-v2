-- Public club pages no longer expose teacher supervisor names.

drop function if exists public.get_public_club_supervisors(uuid);
