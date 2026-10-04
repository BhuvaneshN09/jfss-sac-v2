import { supabase } from "../lib/supabase";
import { getCurrentClubSchoolYear } from "./clubs";
import { getErrorMessage, logServiceError } from "../utils/errors";
import { validateAnnouncementForm } from "../utils/announcementPermissions";

const ANNOUNCEMENT_FIELDS = `
  id,
  club_id,
  title,
  summary,
  body,
  visibility,
  status,
  created_by,
  submitted_at,
  reviewed_by,
  reviewed_at,
  review_notes,
  published_at,
  expires_at,
  archived_at,
  scheduled_posting_date,
  created_at,
  updated_at
`;

const ANNOUNCEMENT_WITH_CLUB = `
  ${ANNOUNCEMENT_FIELDS},
  clubs (
    id,
    name,
    slug,
    logo_url,
    status
  )
`;

const ANNOUNCEMENT_REVIEW_WITH_CLUB = `
  ${ANNOUNCEMENT_WITH_CLUB},
  submitter:profiles!created_by ( email )
`;

function mapAnnouncementError(error, fallback) {
  const message = error?.message || "";
  const lower = message.toLowerCase();

  if (
    lower.includes("could not find the function") ||
    lower.includes("function public.create_announcement") ||
    lower.includes("function public.edit_announcement") ||
    lower.includes("function public.review_announcement") ||
    lower.includes("function public.archive_announcement") ||
    error?.code === "PGRST202"
  ) {
    return "Announcement workflow is unavailable. A required database function is missing.";
  }

  if (lower.includes("only a club owner may create")) {
    return "You do not have permission to create an announcement for this club.";
  }

  if (
    lower.includes("only sac or site administrators may review") ||
    lower.includes("only sac administrators may review") ||
    lower.includes("only sac administrators and faculty advisors may review")
  ) {
    return "Only SAC administrators and faculty advisors may approve club announcements.";
  }

  if (
    lower.includes("posting date") ||
    lower.includes("scheduled posting")
  ) {
    return message;
  }

  if (lower.includes("can no longer be edited") || lower.includes("may be edited")) {
    return "This announcement can no longer be edited.";
  }

  if (lower.includes("already been reviewed") || lower.includes("cannot be")) {
    return message;
  }

  if (lower.includes("announcement not found")) {
    return "The announcement could not be found or you do not have permission to view it.";
  }

  return getErrorMessage(error, fallback);
}

async function refreshAnnouncementLifecycle() {
  // Lifecycle status is evaluated by the read policies; public reads must
  // never invoke a global mutating RPC.
}

async function fetchAnnouncementById(id) {
  await refreshAnnouncementLifecycle();

  const { data, error } = await supabase
    .from("announcements")
    .select(ANNOUNCEMENT_WITH_CLUB)
    .eq("id", id)
    .maybeSingle();

  if (error) {
    logServiceError("fetchAnnouncementById", error);
    throw new Error(
      mapAnnouncementError(
        error,
        "The announcement could not be found or you do not have permission to view it.",
      ),
    );
  }

  return data;
}

export async function getPublishedAnnouncements({
  type = "ALL",
  clubId = null,
  limit = 50,
  offset = 0,
} = {}) {
  await refreshAnnouncementLifecycle();

  let query = supabase
    .from("announcements")
    .select(ANNOUNCEMENT_WITH_CLUB)
    .eq("status", "PUBLISHED")
    .order("published_at", { ascending: false })
    .range(offset, offset + limit - 1);

  if (type === "PUBLIC") {
    query = query.eq("visibility", "PUBLIC");
  } else if (type === "CLUB") {
    query = query.eq("visibility", "CLUB_MEMBERS");
  }

  if (clubId) {
    query = query.eq("club_id", clubId);
  }

  const { data, error } = await query;

  if (error) {
    logServiceError("getPublishedAnnouncements", error);
    throw new Error(
      mapAnnouncementError(error, "Could not load announcements."),
    );
  }

  return data ?? [];
}

export async function getHomepageAnnouncements(limit = 5) {
  return getPublishedAnnouncements({ limit, offset: 0 });
}

export async function getAnnouncementById(id) {
  return fetchAnnouncementById(id);
}

export async function getMyAnnouncements(userId, { status = "ALL" } = {}) {
  await refreshAnnouncementLifecycle();

  let query = supabase
    .from("announcements")
    .select(ANNOUNCEMENT_REVIEW_WITH_CLUB)
    .eq("created_by", userId)
    .order("updated_at", { ascending: false });

  if (status !== "ALL") {
    query = query.eq("status", status);
  }

  const { data, error } = await query;

  if (error) {
    logServiceError("getMyAnnouncements", error);
    throw new Error(
      mapAnnouncementError(error, "Could not load your announcements."),
    );
  }

  return data ?? [];
}

function compareReviewQueue(a, b) {
  const dateA = a.scheduled_posting_date || "9999-12-31";
  const dateB = b.scheduled_posting_date || "9999-12-31";
  if (dateA !== dateB) return dateA < dateB ? -1 : 1;

  const submittedA = a.submitted_at || "";
  const submittedB = b.submitted_at || "";
  if (submittedA !== submittedB) return submittedA < submittedB ? -1 : 1;

  const nameA = (a.clubs?.name || "General").toLowerCase();
  const nameB = (b.clubs?.name || "General").toLowerCase();
  if (nameA !== nameB) return nameA < nameB ? -1 : 1;
  return 0;
}

async function fetchAnnouncementReviewQueue(clubId) {
  await refreshAnnouncementLifecycle();

  let query = supabase
    .from("announcements")
    .select(ANNOUNCEMENT_REVIEW_WITH_CLUB)
    .in("status", ["SUBMITTED", "UNDER_REVIEW"])
    .order("scheduled_posting_date", {
      ascending: true,
      nullsFirst: false,
    })
    .order("submitted_at", { ascending: true, nullsFirst: false });

  if (clubId === null) {
    query = query.is("club_id", null);
  } else if (clubId) {
    query = query.eq("club_id", clubId);
  }

  const { data, error } = await query;

  if (error) {
    logServiceError("getAnnouncementReviewQueue", error);
    throw new Error(
      mapAnnouncementError(error, "Could not load the announcement queue."),
    );
  }

  return [...(data ?? [])].sort(compareReviewQueue);
}

export async function getAnnouncementReviewQueue() {
  return fetchAnnouncementReviewQueue();
}

export async function getAnnouncementReviewQueueForClub(clubId) {
  return fetchAnnouncementReviewQueue(clubId);
}

export async function getArchivedAnnouncements({ search = "" } = {}) {
  await refreshAnnouncementLifecycle();

  let query = supabase
    .from("announcements")
    .select(ANNOUNCEMENT_WITH_CLUB)
    .eq("status", "ARCHIVED")
    .order("scheduled_posting_date", {
      ascending: false,
      nullsFirst: false,
    })
    .order("archived_at", { ascending: false, nullsFirst: false });

  const trimmed = search.trim();
  if (trimmed) {
    query = query.or(
      `title.ilike.%${trimmed}%,summary.ilike.%${trimmed}%`,
    );
  }

  const { data, error } = await query;

  if (error) {
    logServiceError("getArchivedAnnouncements", error);
    throw new Error(
      mapAnnouncementError(error, "Could not load archived announcements."),
    );
  }

  return data ?? [];
}

export async function getOwnedClubsForAnnouncements(userId) {
  const schoolYear = await getCurrentClubSchoolYear();
  const { data, error } = await supabase
    .from("club_memberships")
    .select(
      `
      club_id,
      role,
      status,
      clubs (
        id,
        name,
        slug,
        logo_url,
        status,
        club_school_years (
          school_year,
          status
        )
      )
    `,
    )
    .eq("user_id", userId)
    .eq("role", "OWNER")
    .eq("status", "ACTIVE");

  if (error) {
    logServiceError("getOwnedClubsForAnnouncements", error);
    throw new Error(
      getErrorMessage(error, "Could not load clubs you own."),
    );
  }

  return (data ?? [])
    .map((row) => row.clubs)
    .filter(
      (club) =>
        club &&
        club.status === "APPROVED" &&
        (club.club_school_years || []).some(
          (year) => year.school_year === schoolYear && year.status === "ACTIVE",
        ),
    )
    .map((club) => ({
      id: club.id,
      name: club.name,
      slug: club.slug,
      logo_url: club.logo_url,
      status: club.status,
    }));
}

export async function getApprovedClubsForStaffAnnouncements() {
  const { data, error } = await supabase
    .from("public_active_clubs")
    .select("id, name, slug, logo_url, club_record_status")
    .order("name", { ascending: true });

  if (error) {
    logServiceError("getApprovedClubsForStaffAnnouncements", error);
    throw new Error(
      getErrorMessage(error, "Could not load approved clubs."),
    );
  }

  return (data ?? []).map((row) => ({
    id: row.id,
    name: row.name,
    slug: row.slug,
    logo_url: row.logo_url,
    status: row.club_record_status || "APPROVED",
  }));
}

export async function createAnnouncement(values, action) {
  const requireClub = Boolean(values.requireClub);
  const requirePostingDate = action === "SUBMIT";

  const { isValid, errors, data } = validateAnnouncementForm(values, {
    requireClub,
    requirePostingDate,
  });

  if (!isValid) {
    const error = new Error(Object.values(errors)[0]);
    error.fieldErrors = errors;
    throw error;
  }

  const { data: announcementId, error } = await supabase.rpc(
    "create_announcement",
    {
      p_title: data.title,
      p_body: data.body,
      p_summary: data.summary,
      p_club_id: data.clubId,
      p_visibility: data.visibility,
      p_action: action,
      p_scheduled_posting_date: data.scheduledPostingDate,
    },
  );

  if (error) {
    logServiceError("createAnnouncement", error);
    throw new Error(
      mapAnnouncementError(error, "Could not create the announcement."),
    );
  }

  return announcementId;
}

export async function editAnnouncement(id, values, action) {
  const requirePostingDate = action === "SUBMIT";
  const { isValid, errors, data } = validateAnnouncementForm(values, {
    requirePostingDate,
  });

  if (!isValid) {
    const error = new Error(Object.values(errors)[0]);
    error.fieldErrors = errors;
    throw error;
  }

  const { data: announcementId, error } = await supabase.rpc(
    "edit_announcement",
    {
      p_announcement_id: id,
      p_title: data.title,
      p_body: data.body,
      p_summary: data.summary,
      p_visibility: data.visibility,
      p_action: action,
      p_scheduled_posting_date: data.scheduledPostingDate,
    },
  );

  if (error) {
    logServiceError("editAnnouncement", error);
    throw new Error(
      mapAnnouncementError(error, "Could not update the announcement."),
    );
  }

  return announcementId;
}

export async function reviewAnnouncement(id, action, reviewNotes = null) {
  const normalizedAction = String(action || "").toUpperCase();
  if (normalizedAction === "REJECTED" && !String(reviewNotes || "").trim()) {
    throw new Error(
      "Review notes are required when rejecting an announcement.",
    );
  }

  const { data: announcementId, error } = await supabase.rpc(
    "review_announcement",
    {
      p_announcement_id: id,
      p_action: normalizedAction,
      p_review_notes: reviewNotes || null,
    },
  );

  if (error) {
    logServiceError("reviewAnnouncement", error);
    throw new Error(
      mapAnnouncementError(error, "Could not review the announcement."),
    );
  }

  return announcementId;
}

export async function archiveAnnouncement(id) {
  const { data: announcementId, error } = await supabase.rpc(
    "archive_announcement",
    {
      p_announcement_id: id,
    },
  );

  if (error) {
    logServiceError("archiveAnnouncement", error);
    throw new Error(
      mapAnnouncementError(error, "Could not archive the announcement."),
    );
  }

  return announcementId;
}
