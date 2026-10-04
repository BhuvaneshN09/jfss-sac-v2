import { supabase } from "../lib/supabase";
import { CLUB_APPLICATION_SCHOOL_YEAR } from "../config/clubApplications";
import { getErrorMessage, logServiceError } from "../utils/errors";
import { validateClubSlug } from "../utils/validation";

const REQUEST_FIELDS = `
  id,
  requested_by,
  respondent_email,
  school_year,
  proposed_name,
  short_description,
  description,
  purpose,
  student_benefit,
  potential_event_ideas,
  leader_details,
  leader_contact_information,
  club_contact_information,
  instagram_handle,
  meeting_days,
  meeting_time_details,
  meeting_location,
  logo_storage_path,
  member_application_url,
  exec_application_url,
  owner_names,
  teacher_supervisor_emails,
  faculty_advisor_name,
  faculty_advisor_email,
  expected_member_count,
  meeting_plan,
  constitution_url,
  teacher_supervisor_form_storage_path,
  status,
  review_notes,
  reviewed_by,
  reviewed_at,
  created_club_id,
  submitted_at,
  created_at,
  updated_at
`;

const ADMIN_QUEUE_STATUSES = ["SUBMITTED"];

export async function getMyClubRequests(userId) {
  const { data, error } = await supabase
    .from("club_registration_requests")
    .select(REQUEST_FIELDS)
    .eq("requested_by", userId)
    .order("created_at", { ascending: false });

  if (error) {
    logServiceError("getMyClubRequests", error);
    throw new Error(getErrorMessage(error, "Could not load your club requests."));
  }

  return data ?? [];
}

export async function isClubNameTaken(proposedName) {
  const { data, error } = await supabase.rpc("club_name_is_taken", {
    p_name: String(proposedName || "").trim(),
  });

  if (error) {
    logServiceError("isClubNameTaken", error);
    throw new Error(
      getErrorMessage(error, "Could not verify the club name."),
    );
  }

  return Boolean(data);
}

export async function submitClubRegistrationApplication(payload) {
  const { data, error } = await supabase.rpc(
    "submit_club_registration_application_with_owner_names",
    {
      p_request_id: payload.requestId,
      p_proposed_name: payload.proposedName,
      p_description: payload.description,
      p_student_benefit: payload.studentBenefit,
      p_leader_details: payload.leaderDetails,
      p_owner_names: payload.ownerNames,
      p_teacher_supervisor_emails: payload.teacherSupervisorEmails,
      p_club_contact_information: payload.clubContactInformation,
      p_teacher_supervisor_form_storage_path:
        payload.teacherSupervisorFormStoragePath,
      p_potential_event_ideas: payload.potentialEventIdeas || null,
      p_instagram_handle: payload.instagramHandle || null,
      p_meeting_days: payload.meetingDays ?? [],
      p_meeting_time_details: payload.meetingTimeDetails || null,
      p_meeting_location: payload.meetingLocation || null,
      p_logo_storage_path: payload.logoStoragePath || null,
      p_faculty_advisor_name: payload.facultyAdvisorName || null,
      p_school_year: payload.schoolYear || CLUB_APPLICATION_SCHOOL_YEAR,
      p_member_application_url: payload.memberApplicationUrl || null,
      p_exec_application_url: payload.execApplicationUrl || null,
    },
  );

  if (error) {
    logServiceError("submitClubRegistrationApplication", error);
    throw new Error(
      getErrorMessage(error, "Could not submit your club application."),
    );
  }

  return data;
}

export async function getAdminClubRequestQueue() {
  const { data, error } = await supabase
    .from("club_registration_requests")
    .select(REQUEST_FIELDS)
    .in("status", ADMIN_QUEUE_STATUSES)
    .order("submitted_at", { ascending: false, nullsFirst: false })
    .order("created_at", { ascending: false });

  if (error) {
    logServiceError("getAdminClubRequestQueue", error);
    throw new Error(
      getErrorMessage(error, "Could not load the club request queue."),
    );
  }

  return data ?? [];
}

export async function getAdminClubRequestById(requestId) {
  const { data, error } = await supabase
    .from("club_registration_requests")
    .select(REQUEST_FIELDS)
    .eq("id", requestId)
    .maybeSingle();

  if (error) {
    logServiceError("getAdminClubRequestById", error);
    throw new Error(
      getErrorMessage(error, "Could not load this club request."),
    );
  }

  return data;
}

export async function updateClubRequestReview({
  requestId,
  status,
  reviewNotes = null,
}) {
  const action = String(status || "").toUpperCase();

  if (action !== "REJECTED") {
    throw new Error("Invalid club request review action.");
  }
  if (!String(reviewNotes || "").trim()) {
    throw new Error("Review notes are required when rejecting a club request.");
  }

  const { data, error } = await supabase.rpc(
    "review_club_registration_request",
    {
      p_request_id: requestId,
      p_action: action,
      p_review_notes: reviewNotes || null,
    },
  );

  if (error) {
    logServiceError("updateClubRequestReview", error);
    throw new Error(
      getErrorMessage(error, "Could not update the club request review."),
    );
  }

  return data;
}

export async function approveClubRequest({
  requestId,
  slug,
  reviewNotes = null,
}) {
  const slugError = validateClubSlug(slug);
  if (slugError) {
    throw new Error(slugError);
  }

  const { data, error } = await supabase.rpc(
    "approve_club_registration_request",
    {
      p_request_id: requestId,
      p_slug: slug.trim().toLowerCase(),
      p_review_notes: reviewNotes || null,
    },
  );

  if (error) {
    logServiceError("approveClubRequest", error);

    const message = error.message || "";
    const lower = message.toLowerCase();

    if (
      lower.includes("could not find the function") ||
      lower.includes("function public.approve_club_registration_request") ||
      error.code === "PGRST202"
    ) {
      throw new Error(
        "Club approval is unavailable. The approve_club_registration_request function is missing on the server.",
      );
    }

    throw new Error(getErrorMessage(error, "Could not approve this club request."));
  }

  return data;
}

export async function getDashboardSummary(userId) {
  const summary = {
    requestCount: 0,
    activeMembershipCount: 0,
    recentRequests: [],
    errors: {},
  };

  try {
    const { data, error, count } = await supabase
      .from("club_registration_requests")
      .select(REQUEST_FIELDS, { count: "exact" })
      .eq("requested_by", userId)
      .order("created_at", { ascending: false })
      .limit(5);

    if (error) throw error;

    summary.requestCount = count ?? data?.length ?? 0;
    summary.recentRequests = data ?? [];
  } catch (error) {
    logServiceError("getDashboardSummary.requests", error);
    summary.errors.requests = getErrorMessage(
      error,
      "Could not load your club requests.",
    );
  }

  try {
    const { count, error } = await supabase
      .from("club_memberships")
      .select("club_id", { count: "exact", head: true })
      .eq("user_id", userId)
      .eq("status", "ACTIVE");

    if (error) throw error;

    summary.activeMembershipCount = count ?? 0;
  } catch (error) {
    logServiceError("getDashboardSummary.memberships", error);
    summary.errors.memberships = getErrorMessage(
      error,
      "Could not load your club memberships.",
    );
  }

  return summary;
}
