import { supabase } from "../lib/supabase";
import { resolveClubLogoUrl } from "../utils/clubMedia";
import { toSameOriginSupabaseUrl } from "../utils/proxiedSupabaseUrl";
import { getErrorMessage, logServiceError } from "../utils/errors";
import { isSafeExternalHref } from "../utils/urls";

function withResolvedLogo(club) {
  if (!club) return club;
  return {
    ...club,
    logo_url: resolveClubLogoUrl(club.logo_url),
    banner_url: toSameOriginSupabaseUrl(club.banner_url) ?? null,
  };
}

const CLUB_FIELDS = `
  id,
  name,
  slug,
  short_description,
  description,
  logo_url,
  banner_url,
  contact_email,
  instagram_handle,
  meeting_location,
  meeting_schedule,
  meeting_frequency,
  meeting_days,
  meeting_time_details,
  member_application_url,
  exec_application_url,
  owner_names,
  status,
  creation_origin,
  deleted_at,
  eligible_for_reapplication,
  is_imported_seed,
  created_by,
  approved_by,
  approved_at,
  created_at,
  updated_at
`;

function mapClubMutationError(error, fallback) {
  const message = error?.message?.toLowerCase?.() || "";

  if (
    message.includes("cannot be permanently deleted") ||
    message.includes("cannot be reactivated directly")
  ) {
    return error?.message || fallback;
  }

  if (
    message.includes("permission denied") ||
    message.includes("row-level security") ||
    message.includes("rls") ||
    message.includes("42501") ||
    message.includes("only an active club owner")
  ) {
    return (
      error?.message ||
      "You do not have permission to perform this club action."
    );
  }

  if (
    message.includes("already archived") ||
    message.includes("already inactive")
  ) {
    return error?.message || "This club is already archived.";
  }

  if (
    message.includes("foreign key") ||
    message.includes("violates foreign key") ||
    message.includes("still referenced")
  ) {
    return "This club still has related records and cannot be changed that way.";
  }

  return getErrorMessage(error, fallback);
}

/** Public Explore: current-year ACTIVE clubs only (enforced by view/RLS). */
export async function getApprovedClubs() {
  const { data, error } = await supabase
    .from("public_active_clubs")
    .select(
      `
      id,
      name,
      slug,
      short_description,
      description,
      logo_url,
      contact_email,
      instagram_handle,
      meeting_location,
      meeting_schedule
    `,
    )
    .order("name", { ascending: true });

  if (error) {
    logServiceError("getApprovedClubs", error);
    throw new Error(getErrorMessage(error, "Could not load approved clubs."));
  }

  return (data ?? []).map((row) => ({
    ...row,
    status: "APPROVED",
  }));
}

export async function getClubAnnualState(clubId) {
  const schoolYear = await getCurrentClubSchoolYear();
  const { data, error } = await supabase
    .from("club_school_years")
    .select(
      "id, club_id, school_year, status, supervisor_due_at, activated_at, updated_at",
    )
    .eq("club_id", clubId)
    .eq("school_year", schoolYear)
    .maybeSingle();

  if (error) {
    logServiceError("getClubAnnualState", error);
    throw new Error(
      getErrorMessage(error, "Could not load this club’s annual status."),
    );
  }

  return data;
}

export async function getCurrentClubSchoolYear() {
  const { data, error } = await supabase.rpc(
    "get_current_club_school_year",
    {},
    { get: true },
  );
  if (error) {
    logServiceError("getCurrentClubSchoolYear", error);
    return "2026-2027";
  }
  return data || "2026-2027";
}

export async function getClubBySlug(slug) {
  const { data, error } = await supabase
    .from("clubs")
    .select(CLUB_FIELDS)
    .eq("slug", slug)
    .maybeSingle();

  if (error) {
    logServiceError("getClubBySlug", error);
    throw new Error(getErrorMessage(error, "Could not load this club."));
  }

  return withResolvedLogo(data);
}

export async function getClubById(clubId) {
  const { data, error } = await supabase
    .from("clubs")
    .select(CLUB_FIELDS)
    .eq("id", clubId)
    .maybeSingle();

  if (error) {
    logServiceError("getClubById", error);
    throw new Error(getErrorMessage(error, "Could not load this club."));
  }

  return withResolvedLogo(data);
}

/**
 * Owner (or SAC_ADMIN) profile update. Preserves club UUID and slug.
 * Validation matches the create-club application form for shared fields.
 */
export async function updateOwnedClubProfile(clubId, values) {
  const name = String(values?.name ?? "").trim();
  const description = String(values?.description ?? "").trim();
  const contactEmail = String(values?.contactEmail ?? "").trim().toLowerCase();
  const instagramHandle = String(values?.instagramHandle ?? "")
    .trim()
    .replace(/^@+/, "");
  const meetingDays = Array.isArray(values?.meetingDays)
    ? values.meetingDays
    : [];
  const meetingTimeDetails =
    String(values?.meetingTimeDetails ?? "").trim() || null;
  const meetingLocation = String(values?.meetingLocation ?? "").trim() || null;
  const memberApplicationUrl =
    String(values?.memberApplicationUrl ?? "").trim() || null;
  const execApplicationUrl =
    String(values?.execApplicationUrl ?? "").trim() || null;
  const ownerNames = String(values?.ownerNames ?? "").trim() || null;
  const logoUrl =
    values?.logoUrl === undefined || values?.logoUrl === null
      ? undefined
      : String(values.logoUrl).trim() || null;

  if (name.length < 2) {
    throw new Error("Enter your club name.");
  }

  if (description.length < 10) {
    throw new Error(
      "Provide a detailed club description (at least 10 characters).",
    );
  }

  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(contactEmail)) {
    throw new Error("Enter a valid public club email.");
  }

  if (!instagramHandle) {
    throw new Error("Enter the club Instagram handle.");
  }

  if (memberApplicationUrl && !isSafeExternalHref(memberApplicationUrl)) {
    throw new Error("Enter a valid member application link.");
  }
  if (execApplicationUrl && !isSafeExternalHref(execApplicationUrl)) {
    throw new Error("Enter a valid executive application link.");
  }

  const rpcArgs = {
    p_club_id: clubId,
    p_name: name,
    p_description: description,
    p_contact_email: contactEmail,
    p_leader_contact_information: null,
    p_short_description: null,
    p_logo_url: logoUrl ?? null,
    p_instagram_handle: instagramHandle,
    p_meeting_days: meetingDays,
    p_meeting_time_details: meetingTimeDetails,
    p_meeting_location: meetingLocation,
    p_member_application_url: memberApplicationUrl,
    p_exec_application_url: execApplicationUrl,
    p_owner_names: ownerNames,
  };

  const { data, error } = await supabase.rpc(
    "update_owned_club_profile_with_owner_names",
    rpcArgs,
  );

  if (error) {
    logServiceError("updateOwnedClubProfile", error);
    throw new Error(
      mapClubMutationError(error, "Could not save club details."),
    );
  }

  return withResolvedLogo(data);
}

/**
 * Owner or site-admin archive via secure RPC. Archived clubs remain
 * available for re-registration.
 */
export async function archiveOwnedClub(clubId) {
  const { data, error } = await supabase.rpc("archive_owned_club", {
    p_club_id: clubId,
  });

  if (error) {
    logServiceError("archiveOwnedClub", error);
    throw new Error(
      mapClubMutationError(error, "Could not archive this club."),
    );
  }

  return data;
}

export async function listArchivedClubs(search = "") {
  const { data, error } = await supabase.rpc("list_archived_clubs", {
    p_search: search.trim() || null,
  });

  if (error) {
    logServiceError("listArchivedClubs", error);
    throw new Error(
      getErrorMessage(error, "Could not load archived clubs."),
    );
  }

  return data ?? [];
}
