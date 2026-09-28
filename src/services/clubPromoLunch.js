import { supabase } from "../lib/supabase";
import { parsePromoLunchConfirmation } from "../utils/clubPromoLunch";
import { getErrorMessage, logServiceError } from "../utils/errors";

const PROMO_LUNCH_FIELDS = `
  id,
  club_id,
  submitted_by,
  applicant_email,
  school_year,
  booth_days,
  approval_email_received,
  representatives,
  status,
  review_notes,
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

export async function submitClubPromoLunchRequest(payload) {
  const { data, error } = await supabase.rpc(
    "submit_club_promo_lunch_request",
    {
      p_request_id: payload.requestId,
      p_club_id: payload.clubId,
      p_booth_days: payload.boothDays,
      p_approval_email_received: payload.approvalEmailReceived,
      p_representatives: payload.representatives,
      p_school_year: payload.schoolYear || "2026-2027",
    },
  );

  if (error) {
    logServiceError("submitClubPromoLunchRequest", error);
    throw new Error(
      getErrorMessage(error, "Could not submit the Club Promo Lunch sign-up."),
    );
  }
  return data;
}

export async function getMyClubPromoLunchRequests(userId) {
  const { data, error } = await supabase
    .from("club_promo_lunch_requests")
    .select(PROMO_LUNCH_FIELDS)
    .eq("submitted_by", userId)
    .order("created_at", { ascending: false });

  if (error) {
    logServiceError("getMyClubPromoLunchRequests", error);
    throw new Error(
      getErrorMessage(error, "Could not load your Club Promo Lunch sign-ups."),
    );
  }
  return data ?? [];
}

export async function getAdminClubPromoLunchQueue() {
  const { data, error } = await supabase
    .from("club_promo_lunch_requests")
    .select(PROMO_LUNCH_FIELDS)
    .eq("status", "SUBMITTED")
    .order("submitted_at", { ascending: true });

  if (error) {
    logServiceError("getAdminClubPromoLunchQueue", error);
    throw new Error(
      getErrorMessage(error, "Could not load Club Promo Lunch sign-ups."),
    );
  }
  return data ?? [];
}

export async function getAdminClubPromoLunchRequestById(requestId) {
  const { data, error } = await supabase
    .from("club_promo_lunch_requests")
    .select(PROMO_LUNCH_FIELDS)
    .eq("id", requestId)
    .maybeSingle();

  if (error) {
    logServiceError("getAdminClubPromoLunchRequestById", error);
    throw new Error(
      getErrorMessage(error, "Could not load this Club Promo Lunch sign-up."),
    );
  }
  return data;
}

export async function getApprovedClubPromoLunchConfirmation(clubId) {
  const { data, error } = await supabase.rpc(
    "get_public_club_promo_lunch_confirmation",
    { p_club_id: clubId },
    { get: true },
  );

  if (error) {
    logServiceError("getApprovedClubPromoLunchConfirmation", error);
    return null;
  }
  return parsePromoLunchConfirmation(data);
}

export async function getConfirmedClubPromoLunchClubIds() {
  const { data, error } = await supabase.rpc(
    "get_public_confirmed_promo_lunch_club_ids",
    {},
    { get: true },
  );

  if (error) {
    logServiceError("getConfirmedClubPromoLunchClubIds", error);
    throw new Error(
      getErrorMessage(error, "Could not load Promo Lunch confirmations."),
    );
  }
  return new Set((data || []).map((row) => row.club_id));
}

export async function reviewClubPromoLunchRequest({
  requestId,
  action,
  reviewNotes = null,
}) {
  const normalizedAction = String(action || "").toUpperCase();
  if (!["APPROVED", "REJECTED"].includes(normalizedAction)) {
    throw new Error("This sign-up can only be approved or rejected.");
  }
  if (normalizedAction === "REJECTED" && !String(reviewNotes || "").trim()) {
    throw new Error("Review notes are required when rejecting.");
  }

  const { data, error } = await supabase.rpc(
    "review_club_promo_lunch_request",
    {
      p_request_id: requestId,
      p_action: normalizedAction,
      p_review_notes: reviewNotes?.trim() || null,
    },
  );

  if (error) {
    logServiceError("reviewClubPromoLunchRequest", error);
    throw new Error(
      getErrorMessage(error, "Could not update this Club Promo Lunch sign-up."),
    );
  }
  return data;
}
