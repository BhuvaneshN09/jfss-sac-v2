-- Consolidate school-wide permissions into SITE_ADMIN.
-- Club-level OWNER, EXEC, and MEMBER roles are unchanged.

insert into public.system_roles (code, name, description)
values (
  'SITE_ADMIN',
  'Site Administrator',
  'Full administration access to the SAC website'
)
on conflict (code) do update
set
  name = excluded.name,
  description = excluded.description;

do $$
declare
  v_site_admin_id uuid;
begin
  select id
  into v_site_admin_id
  from public.system_roles
  where code = 'SITE_ADMIN';

  insert into public.user_system_roles (
    user_id,
    role_id,
    assigned_by,
    assigned_at,
    expires_at
  )
  select
    assignment.user_id,
    v_site_admin_id,
    assignment.assigned_by,
    assignment.assigned_at,
    assignment.expires_at
  from public.user_system_roles assignment
  join public.system_roles role
    on role.id = assignment.role_id
  where role.code = 'SAC_ADMIN'
  on conflict (user_id, role_id) do nothing;

  delete from public.user_system_roles
  where role_id in (
    select id
    from public.system_roles
    where code in ('SAC_ADMIN', 'SAC_EXEC', 'FACULTY_ADVISOR')
  );

  delete from public.system_roles
  where code in ('SAC_ADMIN', 'SAC_EXEC', 'FACULTY_ADVISOR');
end;
$$;

-- Existing security-definer functions still reference the legacy role
-- names. Normalize those checks while old migrations remain immutable.
create or replace function public.has_system_role(
  requested_role_code text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.user_system_roles assignment
    join public.system_roles role
      on role.id = assignment.role_id
    where assignment.user_id = (select auth.uid())
      and role.code = case
        when requested_role_code in (
          'SAC_ADMIN',
          'SAC_EXEC',
          'FACULTY_ADVISOR',
          'SITE_ADMIN'
        ) then 'SITE_ADMIN'
        else requested_role_code
      end
      and (
        assignment.expires_at is null
        or assignment.expires_at > now()
      )
  );
$$;

revoke all on function public.has_system_role(text)
from public, anon, authenticated;

grant execute on function public.has_system_role(text)
to authenticated;
