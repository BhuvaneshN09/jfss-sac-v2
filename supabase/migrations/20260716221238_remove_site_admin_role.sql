-- =========================================================
-- Remove the unused SITE_ADMIN application role.
-- SAC_ADMIN becomes the highest application-wide role.
-- =========================================================

begin;

-- Remove assignments first because user_system_roles.role_id
-- references system_roles.id.

delete from public.user_system_roles as assignment
using public.system_roles as role
where assignment.role_id = role.id
  and role.code = 'SITE_ADMIN';

-- Remove the role definition.

delete from public.system_roles
where code = 'SITE_ADMIN';

commit;