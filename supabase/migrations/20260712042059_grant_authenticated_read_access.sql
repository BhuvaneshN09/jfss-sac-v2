-- Allow signed-in users to reach these tables through the Data API.
-- RLS policies still determine which individual rows they can read.

grant usage on schema public to authenticated;

grant select
on table public.profiles
to authenticated;

grant select
on table public.system_roles
to authenticated;

grant select
on table public.user_system_roles
to authenticated;