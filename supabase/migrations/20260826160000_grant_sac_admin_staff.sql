-- Grant SAC_ADMIN to additional SAC staff emails
-- (same system role held by 778130@pdsb.net).
-- Profiles must already exist (user has signed in at least once).

insert into public.user_system_roles (user_id, role_id)
select
  p.id,
  r.id
from public.profiles as p
cross join public.system_roles as r
where r.code = 'SAC_ADMIN'
  and p.email in (
    '778345@pdsb.net',
    '1099702@pdsb.net',
    '781284@pdsb.net',
    '931108@pdsb.net',
    '782630@pdsb.net'
  )
on conflict (user_id, role_id) do nothing;
