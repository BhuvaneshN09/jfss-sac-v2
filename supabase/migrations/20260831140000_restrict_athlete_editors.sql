-- Restrict Athlete of the Month editing to the designated staff accounts.

create or replace function public.can_manage_athletes()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and lower(email) in (
        '778130@pdsb.net',
        '845945@pdsb.net',
        '783580@pdsb.net',
        '828897@pdsb.net',
        '814061@pdsb.net'
      )
  );
$$;

revoke all on function public.can_manage_athletes()
from public, anon;

grant execute on function public.can_manage_athletes()
to authenticated;

drop policy if exists "athlete_photos_insert_site_admin" on storage.objects;
create policy "athlete_photos_insert_designated_editors"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'athlete-photos'
  and (storage.foldername(name))[1] = 'athlete-photos'
  and (storage.foldername(name))[2] = (select auth.uid())::text
  and public.can_manage_athletes()
);

drop policy if exists "athlete_photos_update_site_admin" on storage.objects;
create policy "athlete_photos_update_designated_editors"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'athlete-photos'
  and (storage.foldername(name))[1] = 'athlete-photos'
  and (storage.foldername(name))[2] = (select auth.uid())::text
  and public.can_manage_athletes()
)
with check (
  bucket_id = 'athlete-photos'
  and (storage.foldername(name))[1] = 'athlete-photos'
  and (storage.foldername(name))[2] = (select auth.uid())::text
  and public.can_manage_athletes()
);

drop policy if exists "athlete_photos_delete_site_admin" on storage.objects;
create policy "athlete_photos_delete_designated_editors"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'athlete-photos'
  and (storage.foldername(name))[1] = 'athlete-photos'
  and (storage.foldername(name))[2] = (select auth.uid())::text
  and public.can_manage_athletes()
);

drop policy if exists "athletes_insert_site_admin"
on public.athletes_of_the_month;
create policy "athletes_insert_designated_editors"
on public.athletes_of_the_month
for insert
to authenticated
with check (
  created_by = (select auth.uid())
  and public.can_manage_athletes()
);

drop policy if exists "athletes_update_site_admin"
on public.athletes_of_the_month;
create policy "athletes_update_designated_editors"
on public.athletes_of_the_month
for update
to authenticated
using (public.can_manage_athletes())
with check (public.can_manage_athletes());

drop policy if exists "athletes_delete_site_admin"
on public.athletes_of_the_month;
create policy "athletes_delete_designated_editors"
on public.athletes_of_the_month
for delete
to authenticated
using (public.can_manage_athletes());
