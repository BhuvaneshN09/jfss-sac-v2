import { supabase } from "../lib/supabase";
import {
  CLUB_SUPERVISOR_DOCUMENTS_BUCKET,
  REAPP_ATTACHMENT_ALLOWED_TYPES,
  REAPP_ATTACHMENT_MAX_BYTES,
} from "../config/clubApplications";
import { getErrorMessage, logServiceError } from "../utils/errors";
import { assertFileMatchesDeclaredType } from "../utils/fileMagic";
import { prepareImageFileForUpload } from "../utils/imageUpload";
import { toSameOriginSupabaseUrl } from "../utils/proxiedSupabaseUrl";

const SUPERVISOR_REQ_FIELDS = `
  id,
  club_id,
  school_year,
  submitted_by,
  status,
  review_notes,
  reviewed_by,
  reviewed_at,
  submitted_at,
  created_at,
  updated_at,
  clubs ( id, name, slug ),
  submitter:profiles!submitted_by (
    id,
    full_name,
    email
  ),
  club_supervisor_request_supervisors ( id, supervisor_name, supervisor_email ),
  club_supervisor_request_attachments (
    id,
    storage_path,
    original_filename,
    mime_type,
    size_bytes
  )
`;

export async function submitClubSupervisorRequest(payload) {
  const { data, error } = await supabase.rpc("submit_club_supervisor_request", {
    p_request_id: payload.requestId,
    p_club_id: payload.clubId,
    p_supervisors: payload.supervisors ?? [],
    p_attachments: payload.attachments ?? [],
  });

  if (error) {
    logServiceError("submitClubSupervisorRequest", error);
    throw new Error(
      getErrorMessage(error, "Could not submit supervisor information."),
    );
  }

  return data;
}

export async function reviewClubSupervisorRequest({
  requestId,
  action,
  reviewNotes = null,
}) {
  const normalizedAction = String(action || "").toUpperCase();
  if (
    normalizedAction === "REJECTED" &&
    !String(reviewNotes || "").trim()
  ) {
    throw new Error(
      "Review notes are required when rejecting a supervisor request.",
    );
  }

  const { data, error } = await supabase.rpc("review_club_supervisor_request", {
    p_request_id: requestId,
    p_action: normalizedAction,
    p_review_notes: reviewNotes,
  });

  if (error) {
    logServiceError("reviewClubSupervisorRequest", error);
    throw new Error(
      getErrorMessage(error, "Could not review this supervisor request."),
    );
  }

  return data;
}

export async function extendClubSupervisorDeadline({ clubId, newDueAt }) {
  const { data, error } = await supabase.rpc(
    "extend_club_supervisor_deadline",
    {
      p_club_id: clubId,
      p_new_due_at: newDueAt,
    },
  );

  if (error) {
    logServiceError("extendClubSupervisorDeadline", error);
    throw new Error(
      getErrorMessage(error, "Could not extend the supervisor deadline."),
    );
  }

  return data;
}

export async function adminRejectPendingSupervisorClub({
  clubId,
  reviewNotes = null,
}) {
  const { data, error } = await supabase.rpc(
    "admin_reject_pending_supervisor_club",
    {
      p_club_id: clubId,
      p_review_notes: reviewNotes,
    },
  );

  if (error) {
    logServiceError("adminRejectPendingSupervisorClub", error);
    throw new Error(
      getErrorMessage(error, "Could not reject this pending club."),
    );
  }

  return data;
}

export async function listSupervisorWatchClubs(mode = "PENDING") {
  const { data, error } = await supabase.rpc("list_supervisor_watch_clubs", {
    p_mode: mode,
  });

  if (error) {
    logServiceError("listSupervisorWatchClubs", error);
    throw new Error(
      getErrorMessage(error, "Could not load supervisor watch clubs."),
    );
  }

  return data ?? [];
}

export async function getClubSupervisorRequests(clubId) {
  const { data, error } = await supabase
    .from("club_supervisor_requests")
    .select(SUPERVISOR_REQ_FIELDS)
    .eq("club_id", clubId)
    .order("submitted_at", { ascending: false });

  if (error) {
    logServiceError("getClubSupervisorRequests", error);
    throw new Error(
      getErrorMessage(error, "Could not load supervisor requests."),
    );
  }

  return data ?? [];
}

/** Supervisor requests for clubs the user owns (RLS: owners + SAC admin/exec). */
export async function getMySupervisorRequestsForClubs(clubIds) {
  const ids = [...new Set((clubIds || []).filter(Boolean))];
  if (ids.length === 0) return [];

  const { data, error } = await supabase
    .from("club_supervisor_requests")
    .select(SUPERVISOR_REQ_FIELDS)
    .in("club_id", ids)
    .order("submitted_at", { ascending: false });

  if (error) {
    logServiceError("getMySupervisorRequestsForClubs", error);
    throw new Error(
      getErrorMessage(error, "Could not load your supervisor requests."),
    );
  }

  return data ?? [];
}

export async function getActiveClubAdvisors(clubId, schoolYear = null) {
  let query = supabase
    .from("club_advisors")
    .select(
      "id, club_id, school_year, supervisor_name, supervisor_email, status, created_at",
    )
    .eq("club_id", clubId)
    .eq("status", "ACTIVE")
    .order("supervisor_name", { ascending: true });

  if (schoolYear) {
    query = query.eq("school_year", schoolYear);
  }

  const { data, error } = await query;

  if (error) {
    logServiceError("getActiveClubAdvisors", error);
    throw new Error(
      getErrorMessage(error, "Could not load teacher supervisors."),
    );
  }

  return data ?? [];
}

export async function getAdminSupervisorRequestQueue({
  status = "ALL",
} = {}) {
  let query = supabase
    .from("club_supervisor_requests")
    .select(SUPERVISOR_REQ_FIELDS)
    .order("submitted_at", { ascending: false });

  if (status === "ALL") {
    query = query.in("status", [
      "SUBMITTED",
      "UNDER_REVIEW",
      "CHANGES_REQUESTED",
    ]);
  } else {
    query = query.eq("status", status);
  }

  const { data, error } = await query;

  if (error) {
    logServiceError("getAdminSupervisorRequestQueue", error);
    throw new Error(
      getErrorMessage(error, "Could not load supervisor request queue."),
    );
  }

  return data ?? [];
}

export function validateSupervisorAttachmentFile(file) {
  if (!file) return "Choose a file to upload.";
  if (!REAPP_ATTACHMENT_ALLOWED_TYPES.includes(file.type)) {
    return "Upload JPEG, PNG, WebP, or PDF only.";
  }
  if (file.size > REAPP_ATTACHMENT_MAX_BYTES) {
    return "Attachments must be 10 MB or smaller.";
  }
  return null;
}

export async function uploadSupervisorDocument({ userId, requestId, file }) {
  const validationError = validateSupervisorAttachmentFile(file);
  if (validationError) throw new Error(validationError);

  await assertFileMatchesDeclaredType(file, REAPP_ATTACHMENT_ALLOWED_TYPES);

  const uploadFile = await prepareImageFileForUpload(file);
  const ext =
    uploadFile.type === "application/pdf"
      ? "pdf"
      : uploadFile.type === "image/png"
        ? "png"
        : uploadFile.type === "image/webp"
          ? "webp"
          : "jpg";
  const path = `supervisor-requests/${userId}/${requestId}/${crypto.randomUUID()}.${ext}`;

  const { error } = await supabase.storage
    .from(CLUB_SUPERVISOR_DOCUMENTS_BUCKET)
    .upload(path, uploadFile, {
      cacheControl: "3600",
      upsert: false,
      contentType: uploadFile.type,
    });

  if (error) {
    logServiceError("uploadSupervisorDocument", error);
    throw new Error(
      getErrorMessage(error, "Could not upload the supervisor document."),
    );
  }

  return {
    storage_path: path,
    original_filename: uploadFile.name,
    mime_type: uploadFile.type,
    size_bytes: uploadFile.size,
  };
}

export async function deleteSupervisorDocument(path) {
  if (!path) return;
  const { error } = await supabase.storage
    .from(CLUB_SUPERVISOR_DOCUMENTS_BUCKET)
    .remove([path]);
  if (error) logServiceError("deleteSupervisorDocument", error);
}

export async function createSignedSupervisorDocumentUrl(
  path,
  expiresIn = 60 * 10,
) {
  const { data, error } = await supabase.storage
    .from(CLUB_SUPERVISOR_DOCUMENTS_BUCKET)
    .createSignedUrl(path, expiresIn);

  if (error) {
    logServiceError("createSignedSupervisorDocumentUrl", error);
    throw new Error(
      getErrorMessage(error, "Could not open the supervisor document."),
    );
  }

  return toSameOriginSupabaseUrl(data?.signedUrl) ?? null;
}

/** Default supervisor deadline: now + 7 days (local datetime-local value). */
export function defaultSupervisorDeadlineLocalValue(fromDate = new Date()) {
  const due = new Date(fromDate.getTime() + 7 * 24 * 60 * 60 * 1000);
  const pad = (n) => String(n).padStart(2, "0");
  return `${due.getFullYear()}-${pad(due.getMonth() + 1)}-${pad(due.getDate())}T${pad(due.getHours())}:${pad(due.getMinutes())}`;
}

export function localDateTimeValueToIso(value) {
  if (!value) return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  return date.toISOString();
}
