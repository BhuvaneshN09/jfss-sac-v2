select
  p.id,
  p.email,
  p.full_name,
  p.is_active,
  r.code as role_code,
  usr.assigned_at,
  usr.expires_at
from public.profiles as p
left join public.user_system_roles as usr
  on usr.user_id = p.id
left join public.system_roles as r
  on r.id = usr.role_id
where lower(p.email) = '778345@pdsb.net';
