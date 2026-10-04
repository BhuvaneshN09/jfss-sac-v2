import { supabase } from "../lib/supabase";
import { getErrorMessage, logServiceError } from "../utils/errors";

const PROFILE_FIELDS =
  "id, email, full_name, avatar_url, graduation_year, is_active, created_at, updated_at";

function isActiveAssignment(expiresAt) {
  if (!expiresAt) return true;
  return new Date(expiresAt).getTime() > Date.now();
}

function normalizeJoinedRole(row) {
  const roleRecord = Array.isArray(row.system_roles)
    ? row.system_roles[0]
    : row.system_roles;

  return {
    code: roleRecord?.code ?? null,
    name: roleRecord?.name ?? null,
    description: roleRecord?.description ?? null,
    assigned_at: row.assigned_at,
    expires_at: row.expires_at,
    role_id: row.role_id ?? roleRecord?.id ?? null,
  };
}

async function getRolesByIds(roleIds) {
  if (!roleIds.length) return new Map();

  const { data, error } = await supabase
    .from("system_roles")
    .select("id, code, name, description")
    .in("id", roleIds);

  if (error) {
    logServiceError("getRolesByIds", error);
    throw new Error(getErrorMessage(error, "Could not load system role definitions."));
  }

  return new Map((data ?? []).map((role) => [role.id, role]));
}

export async function getCurrentProfile(userId) {
  const { data, error } = await supabase
    .from("profiles")
    .select(PROFILE_FIELDS)
    .eq("id", userId)
    .maybeSingle();

  if (error) {
    logServiceError("getCurrentProfile", error);
    throw new Error(getErrorMessage(error, "Could not load your profile."));
  }

  return data;
}

export async function getCurrentUserSystemRoles(userId) {
  const { data, error } = await supabase
    .from("user_system_roles")
    .select(
      `
      role_id,
      assigned_at,
      expires_at,
      system_roles!role_id (
        id,
        code,
        name,
        description
      )
    `,
    )
    .eq("user_id", userId);

  if (error) {
    logServiceError("getCurrentUserSystemRoles.join", error);

    // Fallback for environments where the nested relationship hint fails.
    const { data: assignments, error: assignmentError } = await supabase
      .from("user_system_roles")
      .select("role_id, assigned_at, expires_at")
      .eq("user_id", userId);

    if (assignmentError) {
      logServiceError("getCurrentUserSystemRoles.fallback", assignmentError);
      throw new Error(
        getErrorMessage(assignmentError, "Could not load your system roles."),
      );
    }

    const roleMap = await getRolesByIds(
      (assignments ?? []).map((row) => row.role_id).filter(Boolean),
    );

    return (assignments ?? [])
      .filter((row) => isActiveAssignment(row.expires_at))
      .map((row) => {
        const role = roleMap.get(row.role_id);
        return {
          code: role?.code ?? null,
          name: role?.name ?? null,
          description: role?.description ?? null,
          assigned_at: row.assigned_at,
          expires_at: row.expires_at,
          role_id: row.role_id,
        };
      })
      .filter((role) => role.code);
  }

  const normalized = (data ?? [])
    .filter((row) => isActiveAssignment(row.expires_at))
    .map(normalizeJoinedRole);

  const missingRoleIds = normalized
    .filter((role) => !role.code && role.role_id)
    .map((role) => role.role_id);

  if (missingRoleIds.length > 0) {
    const roleMap = await getRolesByIds(missingRoleIds);
    return normalized
      .map((role) => {
        if (role.code) return role;
        const fallback = roleMap.get(role.role_id);
        return {
          ...role,
          code: fallback?.code ?? null,
          name: fallback?.name ?? null,
          description: fallback?.description ?? null,
        };
      })
      .filter((role) => role.code);
  }

  return normalized.filter((role) => role.code);
}
