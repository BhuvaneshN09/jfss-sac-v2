import { supabase } from "../lib/supabase";
import { getErrorMessage, logServiceError } from "../utils/errors";
import { assertFileMatchesDeclaredType } from "../utils/fileMagic";
import { getClubEventDisplayNames } from "../utils/clubEventDisplay";
import { prepareImageFileForUpload } from "../utils/imageUpload";
import { toAuthenticatedStorageObjectUrl, toSameOriginSupabaseUrl } from "../utils/proxiedSupabaseUrl";

export const CLUB_EVENT_PHOTOS_BUCKET = "club-event-photos";
export const CLUB_EVENT_SIGNATURES_BUCKET = "club-event-signatures";
export const CLUB_EVENT_PHOTO_MAX_BYTES = 10 * 1024 * 1024;
export const CLUB_EVENT_SIGNATURE_MAX_BYTES = 10 * 1024 * 1024;
export const CLUB_EVENT_PHOTO_ALLOWED_TYPES = [
  "image/jpeg",
  "image/png",
  "image/webp",
];
export const CLUB_EVENT_SIGNATURE_ALLOWED_TYPES = [
  "image/jpeg",
  "image/png",
  "image/webp",
  "application/pdf",
];

const EVENT_FIELDS = `
  id,
  club_id,
  submitted_by,
  applicant_email,
  school_year,
  event_name,
  event_description,
  event_date,
  event_end_date,
  requested_materials,
  is_charitable_event,
  photo_storage_path,
  signed_form_storage_path,
  status,
  review_notes,
  reviewed_by,
  reviewed_at,
  submitted_at,
  created_at,
  updated_at,
  clubs (
    id,
    name,
    slug
  )
`;

function mapEventError(error, fallback) {
  const message = error?.message || "";
  const lower = message.toLowerCase();

  if (lower.includes("only an active club owner")) {
    return "Only active club owners can submit event proposals.";
  }
  if (
    lower.includes("event proposals are available only") ||
    lower.includes("officially active") ||
    lower.includes("archived clubs cannot")
  ) {
    return message;
  }
  if (lower.includes("event date")) {
    return message;
  }
  if (lower.includes("already been reviewed")) {
    return "This event proposal has already been reviewed.";
  }
  return getErrorMessage(error, fallback);
}

export function validateClubEventPhoto(file) {
  if (!file) return null;
  if (!CLUB_EVENT_PHOTO_ALLOWED_TYPES.includes(file.type)) {
    return "Event photos must be JPEG, PNG, or WebP files.";
  }
  if (file.size > CLUB_EVENT_PHOTO_MAX_BYTES) {
    return "Event photos must be 10 MB or smaller.";
  }
  return null;
}

function extensionForMime(mime) {
  if (mime === "image/png") return "png";
  if (mime === "image/webp") return "webp";
  if (mime === "application/pdf") return "pdf";
  return "jpg";
}

export function validateClubEventSignatureFile(file) {
  if (!file) {
    return "Attach the signed Event Approval Form.";
  }
  if (!CLUB_EVENT_SIGNATURE_ALLOWED_TYPES.includes(file.type)) {
    return "The signed form must be a JPEG, PNG, WebP, or PDF.";
  }
  if (file.size > CLUB_EVENT_SIGNATURE_MAX_BYTES) {
    return "The signed form must be 10 MB or smaller.";
  }
  return null;
}

export function buildClubEventPhotoPath({ userId, requestId, file }) {
  return `event-photos/${userId}/${requestId}/${crypto.randomUUID()}.${extensionForMime(file.type)}`;
}

export async function uploadClubEventPhoto({ userId, requestId, file }) {
  const validationError = validateClubEventPhoto(file);
  if (validationError) throw new Error(validationError);
  if (!userId || !requestId || !file) {
    throw new Error("Missing event photo destination.");
  }

  await assertFileMatchesDeclaredType(file, CLUB_EVENT_PHOTO_ALLOWED_TYPES);

  const uploadFile = await prepareImageFileForUpload(file);
  const path = buildClubEventPhotoPath({ userId, requestId, file: uploadFile });
  const { error } = await supabase.storage
    .from(CLUB_EVENT_PHOTOS_BUCKET)
    .upload(path, uploadFile, {
      cacheControl: "3600",
      contentType: uploadFile.type,
      upsert: false,
    });

  if (error) {
    logServiceError("uploadClubEventPhoto", error);
    throw new Error(getErrorMessage(error, "Could not upload the event photo."));
  }

  return path;
}

export async function deleteClubEventPhoto(path) {
  if (!path) return;
  const { error } = await supabase.storage
    .from(CLUB_EVENT_PHOTOS_BUCKET)
    .remove([path]);
  if (error) logServiceError("deleteClubEventPhoto", error);
}

export function getPublicClubEventPhotoUrl(path) {
  if (!path) return null;
  return (
    toAuthenticatedStorageObjectUrl(CLUB_EVENT_PHOTOS_BUCKET, path) || null
  );
}

export async function getClubEventPhotoUrl(path) {
  if (!path) return null;
  const { data, error } = await supabase.storage
    .from(CLUB_EVENT_PHOTOS_BUCKET)
    .createSignedUrl(path, 60 * 60);
  if (error) {
    logServiceError("getClubEventPhotoUrl", error);
    return null;
  }
  return toSameOriginSupabaseUrl(data?.signedUrl) || null;
}

export function buildClubEventSignaturePath({ userId, requestId, file }) {
  return `event-signatures/${userId}/${requestId}/${crypto.randomUUID()}.${extensionForMime(file.type)}`;
}

export async function uploadClubEventSignature({ userId, requestId, file }) {
  const validationError = validateClubEventSignatureFile(file);
  if (validationError) throw new Error(validationError);
  if (!userId || !requestId || !file) {
    throw new Error("Missing event signature destination.");
  }

  await assertFileMatchesDeclaredType(file, CLUB_EVENT_SIGNATURE_ALLOWED_TYPES);

  const uploadFile = await prepareImageFileForUpload(file);
  const path = buildClubEventSignaturePath({
    userId,
    requestId,
    file: uploadFile,
  });
  const { error } = await supabase.storage
    .from(CLUB_EVENT_SIGNATURES_BUCKET)
    .upload(path, uploadFile, {
      cacheControl: "3600",
      contentType: uploadFile.type,
      upsert: false,
    });

  if (error) {
    logServiceError("uploadClubEventSignature", error);
    throw new Error(
      getErrorMessage(error, "Could not upload the signed Event Approval Form."),
    );
  }

  return path;
}

export async function deleteClubEventSignature(path) {
  if (!path) return;
  const { error } = await supabase.storage
    .from(CLUB_EVENT_SIGNATURES_BUCKET)
    .remove([path]);
  if (error) logServiceError("deleteClubEventSignature", error);
}

export async function createSignedEventSignatureUrl(
  path,
  expiresIn = 10 * 60,
) {
  if (!path) throw new Error("An event signature path is required.");

  const { data, error } = await supabase.storage
    .from(CLUB_EVENT_SIGNATURES_BUCKET)
    .createSignedUrl(path, expiresIn);
  if (error) {
    logServiceError("createSignedEventSignatureUrl", error);
    throw new Error(
      getErrorMessage(error, "Could not open the signed Event Approval Form."),
    );
  }
  return toSameOriginSupabaseUrl(data?.signedUrl) ?? null;
}

export async function submitClubEventRequest(payload) {
  const { data, error } = await supabase.rpc("submit_club_event_request", {
    p_request_id: payload.requestId,
    p_club_id: payload.clubId,
    p_event_name: payload.eventName,
    p_event_description: payload.eventDescription,
    p_event_start_date: payload.eventStartDate,
    p_event_end_date: payload.eventEndDate,
    p_requested_materials: payload.requestedMaterials,
    p_signed_form_storage_path: payload.signedFormStoragePath,
    p_photo_storage_path: payload.photoStoragePath || null,
    p_school_year: payload.schoolYear || "2026-2027",
    p_is_charitable_event: Boolean(payload.isCharitableEvent),
  });

  if (error) {
    logServiceError("submitClubEventRequest", error);
    throw new Error(
      mapEventError(error, "Could not submit the event proposal."),
    );
  }
  return data;
}

export async function getMyClubEventRequests(userId) {
  const { data, error } = await supabase
    .from("club_event_requests")
    .select(EVENT_FIELDS)
    .eq("submitted_by", userId)
    .order("created_at", { ascending: false });

  if (error) {
    logServiceError("getMyClubEventRequests", error);
    throw new Error(
      getErrorMessage(error, "Could not load your event proposals."),
    );
  }
  return data ?? [];
}

export async function getAdminClubEventQueue() {
  const { data, error } = await supabase
    .from("club_event_requests")
    .select(EVENT_FIELDS)
    .eq("status", "SUBMITTED")
    .order("event_date", { ascending: true })
    .order("submitted_at", { ascending: true });

  if (error) {
    logServiceError("getAdminClubEventQueue", error);
    throw new Error(
      getErrorMessage(error, "Could not load the event proposal queue."),
    );
  }
  return data ?? [];
}

export async function getAdminClubEventRequestById(requestId) {
  const { data, error } = await supabase
    .from("club_event_requests")
    .select(EVENT_FIELDS)
    .eq("id", requestId)
    .maybeSingle();

  if (error) {
    logServiceError("getAdminClubEventRequestById", error);
    throw new Error(
      getErrorMessage(error, "Could not load this event proposal."),
    );
  }
  return data;
}

export async function getPublishedClubEvents() {
  const { data, error } = await supabase.rpc(
    "get_public_club_events",
    {},
    { get: true },
  );

  if (error) {
    logServiceError("getPublishedClubEvents", error);
    throw new Error(getErrorMessage(error, "Could not load events."));
  }
  return (data ?? []).map((event) => ({
    ...event,
    clubs: {
      name: event.club_name,
      slug: event.club_slug,
    },
    club_names: getClubEventDisplayNames(event),
    photo_url: getPublicClubEventPhotoUrl(event.photo_storage_path),
  }));
}

export async function reviewClubEventRequest({
  requestId,
  action,
  reviewNotes = null,
}) {
  const normalizedAction = String(action || "").toUpperCase();
  if (!["APPROVED", "REJECTED"].includes(normalizedAction)) {
    throw new Error("Event proposals can only be approved or rejected.");
  }
  if (normalizedAction === "REJECTED" && !String(reviewNotes || "").trim()) {
    throw new Error(
      "Review notes are required when rejecting an event proposal.",
    );
  }

  const { data, error } = await supabase.rpc("review_club_event_request", {
    p_request_id: requestId,
    p_action: normalizedAction,
    p_review_notes: reviewNotes?.trim() || null,
  });

  if (error) {
    logServiceError("reviewClubEventRequest", error);
    throw new Error(
      mapEventError(error, "Could not update the event proposal."),
    );
  }
  return data;
}
