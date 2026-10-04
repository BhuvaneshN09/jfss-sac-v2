-- Manage the public Athlete of the Month cards.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'athlete-photos',
  'athlete-photos',
  true,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set
  public = true,
  file_size_limit = 10485760,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];

drop policy if exists "athlete_photos_insert_site_admin" on storage.objects;
create policy "athlete_photos_insert_site_admin"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'athlete-photos'
  and (storage.foldername(name))[1] = 'athlete-photos'
  and (storage.foldername(name))[2] = (select auth.uid())::text
  and public.has_system_role('SITE_ADMIN')
);

drop policy if exists "athlete_photos_update_site_admin" on storage.objects;
create policy "athlete_photos_update_site_admin"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'athlete-photos'
  and (storage.foldername(name))[1] = 'athlete-photos'
  and (storage.foldername(name))[2] = (select auth.uid())::text
  and public.has_system_role('SITE_ADMIN')
)
with check (
  bucket_id = 'athlete-photos'
  and (storage.foldername(name))[1] = 'athlete-photos'
  and (storage.foldername(name))[2] = (select auth.uid())::text
  and public.has_system_role('SITE_ADMIN')
);

drop policy if exists "athlete_photos_delete_site_admin" on storage.objects;
create policy "athlete_photos_delete_site_admin"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'athlete-photos'
  and (storage.foldername(name))[1] = 'athlete-photos'
  and (storage.foldername(name))[2] = (select auth.uid())::text
  and public.has_system_role('SITE_ADMIN')
);

create table if not exists public.athletes_of_the_month (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  sport text not null,
  photo_storage_path text,
  display_order integer not null default 0,
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint athlete_name_valid
    check (char_length(btrim(name)) between 1 and 120),
  constraint athlete_sport_valid
    check (char_length(btrim(sport)) between 1 and 80),
  constraint athlete_photo_path_valid
    check (
      photo_storage_path is null
      or photo_storage_path like 'athlete-photos/%'
    )
);

create index if not exists athletes_of_the_month_order_idx
on public.athletes_of_the_month (display_order, created_at);

drop trigger if exists athletes_of_the_month_set_updated_at
on public.athletes_of_the_month;
create trigger athletes_of_the_month_set_updated_at
before update on public.athletes_of_the_month
for each row execute function public.set_updated_at();

alter table public.athletes_of_the_month enable row level security;

drop policy if exists "athletes_select_public" on public.athletes_of_the_month;
create policy "athletes_select_public"
on public.athletes_of_the_month
for select
to anon, authenticated
using (true);

drop policy if exists "athletes_insert_site_admin" on public.athletes_of_the_month;
create policy "athletes_insert_site_admin"
on public.athletes_of_the_month
for insert
to authenticated
with check (
  created_by = (select auth.uid())
  and public.has_system_role('SITE_ADMIN')
);

drop policy if exists "athletes_update_site_admin" on public.athletes_of_the_month;
create policy "athletes_update_site_admin"
on public.athletes_of_the_month
for update
to authenticated
using (public.has_system_role('SITE_ADMIN'))
with check (public.has_system_role('SITE_ADMIN'));

drop policy if exists "athletes_delete_site_admin" on public.athletes_of_the_month;
create policy "athletes_delete_site_admin"
on public.athletes_of_the_month
for delete
to authenticated
using (public.has_system_role('SITE_ADMIN'));

grant select on public.athletes_of_the_month to anon, authenticated;
grant insert, update, delete on public.athletes_of_the_month to authenticated;
