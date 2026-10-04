import { supabase } from "../lib/supabase";
import {
  FUNDING_SIGNATURE_ALLOWED_TYPES,
  FUNDING_SIGNATURE_MAX_BYTES,
  normalizeFundingRows,
} from "../utils/clubFunding";
import { getErrorMessage, logServiceError } from "../utils/errors";
import { assertFileMatchesDeclaredType } from "../utils/fileMagic";
import { prepareImageFileForUpload } from "../utils/imageUpload";
import { toSameOriginSupabaseUrl } from "../utils/proxiedSupabaseUrl";

export const CLUB_FUNDING_SIGNATURES_BUCKET = "club-funding-signatures";

const FUNDING_FIELDS = `
  id,
  club_id,
  requested_by,
  applicant_email,
  school_year,
  usage_of_funding,
  cost_breakdown,
  total_amount,
  requires_principal_review,
  supervisor_signature_path,
  applicant_signature_path,
  status,
  review_notes,
  reviewed_by,
  reviewed_at,
  submitted_at,
  created_at,
  updated_at,
  clubs (
    name,
    slug
  )
`;

function extensionForMime(mime) {
  if (mime === "image/png") return "png";
  if (mime === "image/webp") return "webp";
  if (mime === "application/pdf") return "pdf";
  return "jpg";
}

export function validateFundingSignatureFile(file) {
  if (!file) {
    return "Attach the signed Teacher Approval Form.";
  }
  if (!FUNDING_SIGNATURE_ALLOWED_TYPES.includes(file.type)) {
    return "The signed form must be a JPEG, PNG, WebP, or PDF.";
  }
  if (file.size > FUNDING_SIGNATURE_MAX_BYTES) {
    return "The signed form must be 10 MB or smaller.";
  }
  return null;
}

export function buildFundingSignaturePath({ userId, requestId, kind, file }) {
  const extension = extensionForMime(file.type);
  return `funding-signatures/${userId}/${requestId}/${kind}-${crypto.randomUUID()}.${extension}`;
}

export async function uploadFundingSignature({
  userId,
  requestId,
  kind,
  file,
}) {
  const validationError = validateFundingSignatureFile(file);
  if (validationError) throw new Error(validationError);
  if (!userId || !requestId || !kind) {
    throw new Error("Missing funding signature destination.");
  }

  await assertFileMatchesDeclaredType(file, FUNDING_SIGNATURE_ALLOWED_TYPES);

  const uploadFile = await prepareImageFileForUpload(file);
  const path = buildFundingSignaturePath({
    userId,
    requestId,
    kind,
    file: uploadFile,
  });
  const { error } = await supabase.storage
    .from(CLUB_FUNDING_SIGNATURES_BUCKET)
    .upload(path, uploadFile, {
      cacheControl: "3600",
      upsert: false,
      contentType: uploadFile.type,
    });

  if (error) {
    logServiceError("uploadFundingSignature", error);
    throw new Error(
      getErrorMessage(error, "Could not upload the funding signature."),
    );
  }

  return path;
}

export async function deleteFundingSignature(path) {
  if (!path) return;
  const { error } = await supabase.storage
    .from(CLUB_FUNDING_SIGNATURES_BUCKET)
    .remove([path]);
  if (error) logServiceError("deleteFundingSignature", error);
}

export async function createSignedFundingSignatureUrl(
  path,
  expiresIn = 10 * 60,
) {
  if (!path) throw new Error("A funding signature path is required.");

  const { data, error } = await supabase.storage
    .from(CLUB_FUNDING_SIGNATURES_BUCKET)
    .createSignedUrl(path, expiresIn);
  if (error) {
    logServiceError("createSignedFundingSignatureUrl", error);
    throw new Error(
      getErrorMessage(error, "Could not open the funding signature."),
    );
  }
  return toSameOriginSupabaseUrl(data?.signedUrl) ?? null;
}

export async function submitClubFundingRequest(payload) {
  const { data, error } = await supabase.rpc("submit_club_funding_request", {
    p_request_id: payload.requestId,
    p_club_id: payload.clubId,
    p_usage_of_funding: payload.usageOfFunding,
    p_cost_breakdown: normalizeFundingRows(payload.costRows),
    p_supervisor_signature_path: payload.supervisorSignaturePath,
    p_applicant_signature_path: payload.applicantSignaturePath,
    p_school_year: payload.schoolYear,
  });

  if (error) {
    logServiceError("submitClubFundingRequest", error);
    throw new Error(
      getErrorMessage(error, "Could not submit the funding request."),
    );
  }
  return data;
}

export async function getMyFundingRequests(userId) {
  const { data, error } = await supabase
    .from("club_funding_requests")
    .select(FUNDING_FIELDS)
    .eq("requested_by", userId)
    .order("created_at", { ascending: false });

  if (error) {
    logServiceError("getMyFundingRequests", error);
    throw new Error(
      getErrorMessage(error, "Could not load your funding requests."),
    );
  }
  return data ?? [];
}

export async function getAdminClubFundingQueue() {
  const { data, error } = await supabase
    .from("club_funding_requests")
    .select(FUNDING_FIELDS)
    .in("status", ["SUBMITTED", "UNDER_REVIEW", "CHANGES_REQUESTED"])
    .order("requires_principal_review", { ascending: false })
    .order("submitted_at", { ascending: false });

  if (error) {
    logServiceError("getAdminClubFundingQueue", error);
    throw new Error(
      getErrorMessage(error, "Could not load the funding request queue."),
    );
  }
  return data ?? [];
}

export async function getAdminClubFundingRequestById(requestId) {
  const { data, error } = await supabase
    .from("club_funding_requests")
    .select(FUNDING_FIELDS)
    .eq("id", requestId)
    .maybeSingle();

  if (error) {
    logServiceError("getAdminClubFundingRequestById", error);
    throw new Error(
      getErrorMessage(error, "Could not load this funding request."),
    );
  }
  return data;
}

export async function reviewClubFundingRequest({
  requestId,
  action,
  reviewNotes = null,
}) {
  const normalizedAction = String(action || "").toUpperCase();
  if (!["APPROVED", "REJECTED"].includes(normalizedAction)) {
    throw new Error("Invalid funding request review action.");
  }
  if (normalizedAction === "REJECTED" && !String(reviewNotes || "").trim()) {
    throw new Error(
      "Review notes are required when rejecting a funding request.",
    );
  }

  const { data, error } = await supabase.rpc("review_club_funding_request", {
    p_request_id: requestId,
    p_action: normalizedAction,
    p_review_notes: reviewNotes?.trim() || null,
  });

  if (error) {
    logServiceError("reviewClubFundingRequest", error);
    throw new Error(
      getErrorMessage(error, "Could not update the funding request."),
    );
  }
  return data;
}
