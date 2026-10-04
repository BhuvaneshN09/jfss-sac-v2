/**
 * Shared role helpers for Exec Dashboard and review UI.
 * Based on global system_roles codes only — not club memberships.
 */

export const EXEC_DASHBOARD_ROLES = [
  "SITE_ADMIN",
];

export const REVIEW_MUTATOR_ROLES = ["SITE_ADMIN"];

export const SCHOOL_DAY_MUTATOR_ROLES = ["SITE_ADMIN"];

export function hasSystemRoleCode(systemRoles, code) {
  return (systemRoles || []).some((role) => role.code === code);
}

export function canAccessExecDashboard(systemRoles) {
  return EXEC_DASHBOARD_ROLES.some((code) =>
    hasSystemRoleCode(systemRoles, code),
  );
}

export function canMutateReviews(systemRoles) {
  return REVIEW_MUTATOR_ROLES.some((code) =>
    hasSystemRoleCode(systemRoles, code),
  );
}

export function canMutateSchoolDay(systemRoles) {
  return SCHOOL_DAY_MUTATOR_ROLES.some((code) =>
    hasSystemRoleCode(systemRoles, code),
  );
}

export function isSiteAdminRole(systemRoles) {
  return hasSystemRoleCode(systemRoles, "SITE_ADMIN");
}
