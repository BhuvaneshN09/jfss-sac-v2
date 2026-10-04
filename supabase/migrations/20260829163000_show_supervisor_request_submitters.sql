-- SAC reviewers need the request owner's display name/email for the
-- supervisor-request queue. Users can still only see other profile fields
-- through the existing scoped profile policies.

drop policy if exists "SAC reviewers can read submitter profiles"
on public.profiles;

create policy "SAC reviewers can read submitter profiles"
on public.profiles
for select
to authenticated
using (
  public.has_system_role('SAC_ADMIN')
  or public.has_system_role('SAC_EXEC')
);
