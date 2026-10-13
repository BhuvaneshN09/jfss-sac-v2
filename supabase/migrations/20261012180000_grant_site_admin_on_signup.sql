-- Preapproved staff become SITE_ADMIN (SAC admin) as soon as they sign in.
-- Anyone who already has a profile is granted immediately.

create table if not exists public.site_admin_allowlist (
  email text primary key,
  created_at timestamptz not null default now(),

  constraint site_admin_allowlist_email_lowercase
    check (email = lower(email)),

  constraint site_admin_allowlist_pdsb_email
    check (split_part(email, '@', 2) = 'pdsb.net')
);

alter table public.site_admin_allowlist enable row level security;

revoke all on table public.site_admin_allowlist
from public, anon, authenticated;

insert into public.site_admin_allowlist (email)
values
  ('bonifacio.curutan@pdsb.net'),
  ('p0039342@pdsb.net'),
  ('p0039715@pdsb.net'),
  ('p0039995@pdsb.net'),
  ('p0042314@pdsb.net'),
  ('p0051870@pdsb.net'),
  ('p0053538@pdsb.net'),
  ('p0061342@pdsb.net'),
  ('p0061942@pdsb.net'),
  ('p0065877@pdsb.net'),
  ('p0066487@pdsb.net'),
  ('p0067833@pdsb.net'),
  ('p0068145@pdsb.net'),
  ('p0068182@pdsb.net'),
  ('p0069566@pdsb.net'),
  ('p0070148@pdsb.net'),
  ('p0071148@pdsb.net'),
  ('p0073142@pdsb.net'),
  ('p0073801@pdsb.net'),
  ('p0074123@pdsb.net'),
  ('p0074842@pdsb.net'),
  ('p0075359@pdsb.net'),
  ('p0076202@pdsb.net'),
  ('p0076664@pdsb.net'),
  ('p0077665@pdsb.net'),
  ('p0078066@pdsb.net'),
  ('p0078634@pdsb.net'),
  ('p0080494@pdsb.net'),
  ('p0084121@pdsb.net'),
  ('p0110785@pdsb.net'),
  ('p0135337@pdsb.net'),
  ('p0159367@pdsb.net'),
  ('p0161177@pdsb.net'),
  ('p0188579@pdsb.net'),
  ('p0188871@pdsb.net'),
  ('p0195134@pdsb.net'),
  ('p0195440@pdsb.net'),
  ('p0196030@pdsb.net'),
  ('p0196543@pdsb.net'),
  ('p0201473@pdsb.net'),
  ('p0203608@pdsb.net'),
  ('p0209245@pdsb.net'),
  ('p0211733@pdsb.net')
on conflict (email) do nothing;

insert into public.user_system_roles (user_id, role_id)
select
  p.id,
  r.id
from public.site_admin_allowlist as allowed
join public.profiles as p
  on p.email = allowed.email
cross join public.system_roles as r
where r.code = 'SITE_ADMIN'
on conflict (user_id, role_id) do nothing;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.email is null
     or split_part(lower(btrim(new.email)), '@', 2) <> 'pdsb.net' then
    raise exception 'Only @pdsb.net accounts may access this application'
      using errcode = '42501';
  end if;

  insert into public.profiles (
    id,
    email,
    full_name,
    avatar_url
  )
  values (
    new.id,
    lower(new.email),
    coalesce(
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name'
    ),
    coalesce(
      new.raw_user_meta_data ->> 'avatar_url',
      new.raw_user_meta_data ->> 'picture'
    )
  );

  insert into public.user_system_roles (user_id, role_id)
  select new.id, role.id
  from public.system_roles as role
  where role.code = 'SITE_ADMIN'
    and exists (
      select 1
      from public.site_admin_allowlist as allowed
      where allowed.email = lower(btrim(new.email))
    )
  on conflict (user_id, role_id) do nothing;

  return new;
end;
$$;

revoke all on function public.handle_new_user()
from public, anon, authenticated;
