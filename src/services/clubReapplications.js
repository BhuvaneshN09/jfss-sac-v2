import { supabase } from "../lib/supabase";
import { getErrorMessage, logServiceError } from "../utils/errors";
import { isValidPdsbEmail, normalizePdsbEmail } from "../utils/clubPermissions";

const REAPP_FIELDS = `
  id,
  club_id,
  club_name,
  school_year,
  requested_by,
  applicant_email,
  short_description,
  description,
  public_email,
  instagram_handle,
  meeting_frequency,
  meeting_days,
  meeting_time_details,
  meeting_location,
  member_application_url,
  exec_application_url,
  owner_names,
  proposed_logo_storage_path,
  is_seeking_teacher_supervisor,
  declaration_accepted,
  status,
  review_notes,
  reviewed_by,
  reviewed_at,
  submitted_at,
  created_at,
  updated_at,
  clubs ( id, name, slug, logo_url )
`;

export async function listEligibleClubsForReapplication(search = "") {
  const { data, error } = await supabase.rpc(
    "list_eligible_clubs_for_reapplication",
    { p_search: search || null },
  );

  if (error) {
    logServiceError("listEligibleClubsForReapplication", error);
    throw new Error(
      getErrorMessage(error, "Could not load eligible past clubs."),
    );
  }

  return data ?? [];
}

export async function submitClubReapplication(payload) {
  const { data, error } = await supabase.rpc(
    "submit_club_reapplication_with_owner_names",
    {
    p_request_id: payload.requestId,
    p_club_id: payload.clubId,
    p_short_description: payload.shortDescription,
    p_description: payload.description,
    p_public_email: payload.publicEmail,
    p_instagram_handle: payload.instagramHandle || null,
    p_meeting_frequency: payload.meetingFrequency,
    p_meeting_days: payload.meetingDays ?? [],
    p_meeting_time_details: payload.meetingTimeDetails || null,
    p_meeting_location: payload.meetingLocation || null,
    p_member_application_url: payload.memberApplicationUrl || null,
    p_exec_application_url: payload.execApplicationUrl || null,
    p_owner_names: payload.ownerNames,
    p_proposed_logo_storage_path: payload.proposedLogoStoragePath || null,
    p_is_seeking_teacher_supervisor: Boolean(
      payload.isSeekingTeacherSupervisor,
    ),
    p_declaration_accepted: Boolean(payload.declarationAccepted),
    p_supervisors: payload.supervisors ?? [],
    p_attachments: payload.attachments ?? [],
    },
  );

  if (error) {
    logServiceError("submitClubReapplication", error);
    throw new Error(
      getErrorMessage(error, "Could not submit the club re-application."),
    );
  }

  return data;
}

export async function updateClubReapplication(payload) {
  const { data, error } = await supabase.rpc(
    "update_club_reapplication_with_owner_names",
    {
    p_request_id: payload.requestId,
    p_short_description: payload.shortDescription,
    p_description: payload.description,
    p_public_email: payload.publicEmail,
    p_instagram_handle: payload.instagramHandle || null,
    p_meeting_frequency: payload.meetingFrequency,
    p_meeting_days: payload.meetingDays ?? [],
    p_meeting_time_details: payload.meetingTimeDetails || null,
    p_meeting_location: payload.meetingLocation || null,
    p_member_application_url: payload.memberApplicationUrl || null,
    p_exec_application_url: payload.execApplicationUrl || null,
    p_owner_names: payload.ownerNames,
    p_proposed_logo_storage_path: payload.proposedLogoStoragePath || null,
    p_is_seeking_teacher_supervisor: Boolean(
      payload.isSeekingTeacherSupervisor,
    ),
    p_declaration_accepted: Boolean(payload.declarationAccepted),
    p_supervisors: payload.supervisors ?? [],
    p_attachments: payload.attachments ?? null,
    },
  );

  if (error) {
    logServiceError("updateClubReapplication", error);
    throw new Error(
      getErrorMessage(error, "Could not update the club re-application."),
    );
  }

  return data;
}

export async function resubmitClubReapplication(requestId) {
  const { data, error } = await supabase.rpc("resubmit_club_reapplication", {
    p_request_id: requestId,
  });

  if (error) {
    logServiceError("resubmitClubReapplication", error);
    throw new Error(
      getErrorMessage(error, "Could not resubmit the club re-application."),
    );
  }

  return data;
}

export async function getMyClubReapplications(userId) {
  const { data, error } = await supabase
    .from("club_reapplication_requests")
    .select(
      `${REAPP_FIELDS}, club_reapplication_supervisors (*), club_reapplication_attachments (*)`,
    )
    .eq("requested_by", userId)
    .order("submitted_at", { ascending: false });

  if (error) {
    logServiceError("getMyClubReapplications", error);
    throw new Error(
      getErrorMessage(error, "Could not load your club re-applications."),
    );
  }

  return data ?? [];
}

export async function getClubReapplicationById(requestId) {
  const { data, error } = await supabase
    .from("club_reapplication_requests")
    .select(
      `${REAPP_FIELDS}, club_reapplication_supervisors (*), club_reapplication_attachments (*)`,
    )
    .eq("id", requestId)
    .maybeSingle();

  if (error) {
    logServiceError("getClubReapplicationById", error);
    throw new Error(
      getErrorMessage(error, "Could not load this re-application."),
    );
  }

  return data;
}

export async function getAdminClubReapplicationQueue() {
  const { data, error } = await supabase
    .from("club_reapplication_requests")
    .select(
      `${REAPP_FIELDS}, club_reapplication_supervisors (*), club_reapplication_attachments (*)`,
    )
    .eq("status", "SUBMITTED")
    .order("submitted_at", { ascending: false });

  if (error) {
    logServiceError("getAdminClubReapplicationQueue", error);
    throw new Error(
      getErrorMessage(error, "Could not load the re-application queue."),
    );
  }

  return data ?? [];
}

export async function reviewClubReapplication({
  requestId,
  action,
  reviewNotes = null,
}) {
  const normalizedAction = String(action || "").toUpperCase();
  if (!["APPROVED", "REJECTED"].includes(normalizedAction)) {
    throw new Error("Invalid re-application review action.");
  }
  if (normalizedAction === "REJECTED" && !String(reviewNotes || "").trim()) {
    throw new Error(
      "Review notes are required when rejecting a re-application.",
    );
  }

  const { data, error } = await supabase.rpc("review_club_reapplication", {
    p_request_id: requestId,
    p_action: normalizedAction,
    p_review_notes: reviewNotes,
  });

  if (error) {
    logServiceError("reviewClubReapplication", error);
    throw new Error(
      getErrorMessage(error, "Could not review this re-application."),
    );
  }

  return data;
}

export async function approveClubReapplication({
  requestId,
  reviewNotes = null,
  hasTeacherSupervisor = null,
  supervisorDueAt = null,
}) {
  const { data, error } = await supabase.rpc("approve_club_reapplication", {
    p_request_id: requestId,
    p_review_notes: reviewNotes,
    p_has_teacher_supervisor: hasTeacherSupervisor,
    p_supervisor_due_at: supervisorDueAt,
  });

  if (error) {
    logServiceError("approveClubReapplication", error);
    throw new Error(
      getErrorMessage(error, "Could not approve this re-application."),
    );
  }

  return data;
}

export async function withdrawClubReapplication(requestId) {
  const { data, error } = await supabase.rpc("withdraw_club_reapplication", {
    p_request_id: requestId,
  });

  if (error) {
    logServiceError("withdrawClubReapplication", error);
    throw new Error(
      getErrorMessage(error, "Could not withdraw this re-application."),
    );
  }

  return data;
}

export async function getApprovedReapplicationForClub(clubId) {
  const schoolYear = await getCurrentClubSchoolYearSafe();
  const { data, error } = await supabase
    .from("club_reapplication_requests")
    .select("id, club_id, school_year, status, requested_by, reviewed_at")
    .eq("club_id", clubId)
    .eq("school_year", schoolYear)
    .eq("status", "APPROVED")
    .order("reviewed_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (error) {
    logServiceError("getApprovedReapplicationForClub", error);
    throw new Error(
      getErrorMessage(error, "Could not load the approved re-application."),
    );
  }

  return data;
}

async function getCurrentClubSchoolYearSafe() {
  const { data, error } = await supabase.rpc(
    "get_current_club_school_year",
    {},
    { get: true },
  );
  if (error) return "2026-2027";
  return data || "2026-2027";
}

/** Applicant-facing label: never show bare "Approved" while pending supervisor. */
export function getReapplicationDisplayStatus(request, annualStatus = null) {
  if (
    request?.status === "APPROVED" &&
    annualStatus === "PENDING_SUPERVISOR"
  ) {
    return "PENDING_TEACHER_SUPERVISOR";
  }
  return request?.status || "UNKNOWN";
}

export function validateSupervisorEntries(
  entries,
  { required = true, max = 3 } = {},
) {
  const cleaned = (entries || [])
    .map((entry) => ({
      name: String(entry.name ?? "").trim(),
      email: normalizePdsbEmail(entry.email),
    }))
    .filter((entry) => entry.name || entry.email);

  if (!required && cleaned.length === 0) {
    return { supervisors: [], error: null };
  }

  if (required && cleaned.length < 1) {
    return {
      supervisors: [],
      error:
        "Add at least one teacher supervisor, or mark that you are still searching.",
    };
  }

  if (cleaned.length > max) {
    return {
      supervisors: [],
      error:
        max === 1
          ? "You may list only one teacher supervisor."
          : `You may list at most ${max} teacher supervisors.`,
    };
  }

  for (const entry of cleaned) {
    if (entry.name.length < 2) {
      return {
        supervisors: [],
        error: "Each supervisor needs a full name.",
      };
    }
    if (!isValidPdsbEmail(entry.email)) {
      return {
        supervisors: [],
        error: "Each supervisor email must be an exact @pdsb.net address.",
      };
    }
  }

  return { supervisors: cleaned, error: null };
}
