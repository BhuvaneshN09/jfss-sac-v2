-- Club owners and executives may see member email addresses in Manage Club.
-- This replaces the UUID fallback that was shown when profile RLS hid the
-- member's profile row.

drop policy if exists "Club managers can read member profiles"
on public.profiles;

create policy "Club managers can read member profiles"
on public.profiles
for select
to authenticated
using (
  exists (
    select 1
    from public.club_memberships as member
    where member.user_id = profiles.id
      and member.status = 'ACTIVE'
      and public.has_club_role(
        member.club_id,
        array['OWNER', 'EXEC']
      )
  )
);
