import { supabase } from "../lib/supabase";
import { getErrorMessage, logServiceError } from "../utils/errors";
import {
  isValidPdsbEmail,
  normalizePdsbEmail,
  sortClubMemberships,
} from "../utils/clubPermissions";

const MEMBERSHIP_FIELDS = `
  club_id,
  user_id,
  role,
  status,
  added_by,
  joined_at,
  updated_at
`;

export const STUDENT_LOOKUP_RPC = "find_student_by_email";

function membershipDuplicateMessage(error) {
  const message = error?.message?.toLowerCase?.() || "";
  if (
    message.includes("duplicate key") ||
    message.includes("unique constraint") ||
    message.includes("club_memberships_pkey") ||
    message.includes("already has that active role")
  ) {
    return "This student is already a member of this club.";
  }
  return null;
}

function isMissingRpcError(error) {
  const message = error?.message?.toLowerCase?.() || "";
  return (
    error?.code === "PGRST202" ||
    message.includes("could not find the function") ||
    message.includes(`function public.${STUDENT_LOOKUP_RPC}`) ||
    message.includes("does not exist")
  );
}

function mapMembershipRows(rows) {
  return sortClubMemberships(
    (rows ?? []).map((row) => ({
      club_id: row.club_id,
      user_id: row.user_id,
      role: row.role,
      status: row.status,
      added_by: row.added_by,
      joined_at: row.joined_at,
      updated_at: row.updated_at,
      profile: row.member_profile ?? null,
      added_by_profile: row.added_by_profile ?? null,
    })),
  );
}

export async function getMyClubMemberships(userId) {
  const { data, error } = await supabase
    .from("club_memberships")
    .select(
      `
      club_id,
      user_id,
      role,
      status,
      joined_at,
      updated_at,
      clubs (
        id,
        name,
        slug,
        short_description,
        logo_url,
        status,
        deleted_at,
        meeting_location,
        meeting_schedule,
        club_school_years (
          school_year,
          status
        )
      )
    `,
    )
    .eq("user_id", userId)
    .eq("status", "ACTIVE")
    .order("joined_at", { ascending: false });

  if (error) {
    logServiceError("getMyClubMemberships", error);
    throw new Error(
      getErrorMessage(error, "Could not load your club memberships."),
    );
  }

  // Archived / inactive / terminally deleted clubs should not surface roles.
  return (data ?? []).filter(
    (row) =>
      row.clubs?.status !== "ARCHIVED" &&
      !row.clubs?.deleted_at,
  );
}

export async function getMyMembershipForClub(userId, clubId) {
  const { data, error } = await supabase
    .from("club_memberships")
    .select("club_id, user_id, role, status, joined_at")
    .eq("user_id", userId)
    .eq("club_id", clubId)
    .eq("status", "ACTIVE")
    .maybeSingle();

  if (error) {
    logServiceError("getMyMembershipForClub", error);
    throw new Error(
      getErrorMessage(error, "Could not load your membership for this club."),
    );
  }

  return data;
}

export async function getCurrentUserClubMembership(clubIdOrOptions, maybeUserId) {
  if (
    clubIdOrOptions &&
    typeof clubIdOrOptions === "object" &&
    clubIdOrOptions.clubId &&
    clubIdOrOptions.userId
  ) {
    return getMyMembershipForClub(
      clubIdOrOptions.userId,
      clubIdOrOptions.clubId,
    );
  }

  return getMyMembershipForClub(maybeUserId, clubIdOrOptions);
}

export async function getClubMemberships(clubId) {
  const { data, error } = await supabase
    .from("club_memberships")
    .select(
      `
      ${MEMBERSHIP_FIELDS},
      member_profile:profiles!user_id (
        id,
        email,
        full_name,
        is_active,
        avatar_url
      ),
      added_by_profile:profiles!added_by (
        id,
        email,
        full_name
      )
    `,
    )
    .eq("club_id", clubId)
    .eq("status", "ACTIVE");

  if (error) {
    logServiceError("getClubMemberships.withProfiles", error);

    const { data: fallbackData, error: fallbackError } = await supabase
      .from("club_memberships")
      .select(MEMBERSHIP_FIELDS)
      .eq("club_id", clubId)
      .eq("status", "ACTIVE");

    if (fallbackError) {
      logServiceError("getClubMemberships.fallback", fallbackError);
      throw new Error(
        getErrorMessage(fallbackError, "Could not load club memberships."),
      );
    }

    return {
      memberships: mapMembershipRows(fallbackData),
      profilesReadable: false,
      profilesWarning:
        "Member profiles could not be loaded. Current profiles RLS likely allows users to read only their own profile. Membership rows are shown with user UUIDs.",
    };
  }

  const memberships = mapMembershipRows(data);
  const readableCount = memberships.filter((row) => row.profile).length;
  const profilesReadable =
    memberships.length === 0 || readableCount === memberships.length;

  return {
    memberships,
    profilesReadable,
    profilesWarning: profilesReadable
      ? null
      : "Some member profiles are hidden by RLS. Users can currently read only their own profile, so other members appear as UUIDs until a safer profile-read policy or RPC is added.",
  };
}

/**
 * Privacy-preserving exact-email lookup via find_student_by_email.
 * Never queries profiles broadly from the browser.
 * Returns null when no eligible registered student matches.
 */
export async function findStudentByExactEmail({ clubId, email }) {
  const normalizedEmail = normalizePdsbEmail(email);

  if (!clubId) {
    throw new Error("A club is required.");
  }

  if (!normalizedEmail) {
    throw new Error("Enter the student’s complete PDSB email address.");
  }

  if (!isValidPdsbEmail(normalizedEmail)) {
    throw new Error(
      "Enter the student’s complete @pdsb.net email address.",
    );
  }

  const { data, error } = await supabase.rpc(STUDENT_LOOKUP_RPC, {
    p_club_id: clubId,
    p_email: normalizedEmail,
  });

  if (error) {
    logServiceError("findStudentByExactEmail", error);

    if (isMissingRpcError(error)) {
      const missing = new Error(
        "Student lookup is not available until the secure email-search function is installed.",
      );
      missing.code = "STUDENT_LOOKUP_RPC_MISSING";
      missing.rpcName = STUDENT_LOOKUP_RPC;
      throw missing;
    }

    const message = error.message?.toLowerCase?.() || "";

    if (
      error.code === "42501" ||
      message.includes("permission to search") ||
      message.includes("do not have permission")
    ) {
      throw new Error(
        "You do not have permission to search for students for this club.",
      );
    }

    if (
      message.includes("complete @pdsb.net") ||
      message.includes("email is required")
    ) {
      throw new Error(
        "Enter the student’s complete @pdsb.net email address.",
      );
    }

    if (message.includes("club not found") || message.includes("unavailable")) {
      throw new Error(
        "This club is not available for membership changes.",
      );
    }

    if (message.includes("authentication required")) {
      throw new Error("You must be signed in to search for students.");
    }

    throw new Error("Unable to search for that student.");
  }

  const rows = Array.isArray(data) ? data : data ? [data] : [];

  if (rows.length > 1) {
    console.error(
      "[findStudentByExactEmail] Unexpected multiple rows returned",
      rows.length,
    );
    throw new Error("Student lookup returned an unexpected result.");
  }

  if (rows.length === 0) {
    return null;
  }

  const student = rows[0];

  return {
    id: student.id,
    full_name: student.full_name ?? null,
    email: student.email ?? normalizedEmail,
    avatar_url: student.avatar_url ?? null,
    existing_role: student.existing_role ?? null,
    existing_status: student.existing_status ?? null,
  };
}

export async function probeStudentLookupAvailability() {
  const { error } = await supabase.rpc(STUDENT_LOOKUP_RPC, {
    p_club_id: "00000000-0000-0000-0000-000000000000",
    p_email: "lookup-probe@pdsb.net",
  });

  if (!error) {
    return { available: true, warning: null };
  }

  if (isMissingRpcError(error)) {
    return {
      available: false,
      warning:
        "Student lookup is not available until the secure email-search function (find_student_by_email) is installed.",
      rpcName: STUDENT_LOOKUP_RPC,
    };
  }

  return { available: true, warning: null };
}

export async function addClubMembership({ clubId, userId, role, addedBy }) {
  if (!clubId || !userId) {
    throw new Error("Missing membership details.");
  }

  if (!["OWNER", "EXEC", "MEMBER"].includes(role)) {
    throw new Error("Invalid club membership role.");
  }

  const { error } = await supabase.rpc("add_club_membership", {
    p_club_id: clubId,
    p_target_user_id: userId,
    p_role: role,
  });

  if (error) {
    logServiceError("addClubMembership", error);

    const duplicate = membershipDuplicateMessage(error);
    if (duplicate) {
      throw new Error(duplicate);
    }

    const message = error.message?.toLowerCase?.() || "";
    if (
      message.includes("at most three active owners") ||
      message.includes("at most three active owner")
    ) {
      throw new Error("A club may have at most three active owners.");
    }

    if (
      error.code === "42501" ||
      message.includes("permission") ||
      message.includes("row-level security") ||
      message.includes("violates row-level security")
    ) {
      throw new Error(
        "You do not have permission to assign this club role.",
      );
    }

    if (message.includes("already has that active role")) {
      throw new Error("This student already has that active role in this club.");
    }

    throw new Error(
      getErrorMessage(error, "Could not add this club member."),
    );
  }

  const { data, error: fetchError } = await supabase
    .from("club_memberships")
    .select(MEMBERSHIP_FIELDS)
    .eq("club_id", clubId)
    .eq("user_id", userId)
    .single();

  if (fetchError) {
    return {
      club_id: clubId,
      user_id: userId,
      role,
      status: "ACTIVE",
      added_by: addedBy ?? null,
    };
  }

  return data;
}

export async function updateClubMembershipRole({ clubId, userId, role }) {
  if (role === "OWNER") {
    return addClubMembership({ clubId, userId, role });
  }

  const { data, error } = await supabase
    .from("club_memberships")
    .update({
      role,
      status: "ACTIVE",
    })
    .eq("club_id", clubId)
    .eq("user_id", userId)
    .select(MEMBERSHIP_FIELDS)
    .maybeSingle();

  if (error) {
    logServiceError("updateClubMembershipRole", error);
    throw new Error(
      getErrorMessage(
        error,
        "You do not have permission to change this member’s role.",
      ),
    );
  }

  if (!data) {
    throw new Error(
      "You do not have permission to change this member’s role.",
    );
  }

  return data;
}

export async function removeClubMembership({ clubId, userId }) {
  const { data, error } = await supabase
    .from("club_memberships")
    .delete()
    .eq("club_id", clubId)
    .eq("user_id", userId)
    .select(MEMBERSHIP_FIELDS)
    .maybeSingle();

  if (error) {
    logServiceError("removeClubMembership", error);

    const message = error.message?.toLowerCase?.() || "";
    if (
      error.code === "42501" ||
      message.includes("row-level security") ||
      message.includes("permission")
    ) {
      throw new Error(
        "You do not have permission to remove this club membership.",
      );
    }

    throw new Error(
      getErrorMessage(error, "Could not remove this club membership."),
    );
  }

  if (!data) {
    throw new Error("This membership has already been removed.");
  }

  return data;
}

export async function leaveClub({ clubId, userId }) {
  return removeClubMembership({ clubId, userId });
}
