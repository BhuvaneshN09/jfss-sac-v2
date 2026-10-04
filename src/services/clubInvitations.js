import { supabase } from "../lib/supabase";
import { getErrorMessage, logServiceError } from "../utils/errors";
import {
  isValidPdsbEmail,
  normalizePdsbEmail,
} from "../utils/clubPermissions";

const INVITATION_FIELDS = `
  id,
  club_id,
  invitee_user_id,
  invitee_email,
  invited_by,
  offered_role,
  status,
  created_at,
  responded_at,
  cancelled_at,
  cancelled_by
`;

function mapInvitationError(error, fallback) {
  const message = error?.message || "";
  const lower = message.toLowerCase();

  if (lower.includes("at most three active owners")) {
    return message;
  }
  if (lower.includes("already an active member")) {
    return "This student is already an active member of this club.";
  }
  if (lower.includes("pending invitation already exists")) {
    return "A pending invitation already exists for this student.";
  }
  if (lower.includes("cannot invite yourself")) {
    return "You cannot invite yourself.";
  }
  if (lower.includes("no eligible registered student")) {
    return "No eligible registered student was found with that email.";
  }
  if (lower.includes("only an active club owner")) {
    return "Only an active club owner may manage invitations.";
  }
  if (lower.includes("no longer pending") || lower.includes("no longer eligible")) {
    return message;
  }
  if (lower.includes("only the invited student")) {
    return "Only the invited student may respond to this invitation.";
  }

  return getErrorMessage(error, fallback);
}

export async function createClubMembershipInvitation({
  clubId,
  email,
  offeredRole,
}) {
  const normalized = normalizePdsbEmail(email);
  if (!normalized || !isValidPdsbEmail(normalized)) {
    throw new Error("Enter a complete @pdsb.net email address.");
  }

  if (!["OWNER", "EXEC", "MEMBER"].includes(offeredRole)) {
    throw new Error("Choose a valid position.");
  }

  const { data, error } = await supabase.rpc(
    "create_club_membership_invitation",
    {
      p_club_id: clubId,
      p_email: normalized,
      p_offered_role: offeredRole,
    },
  );

  if (error) {
    logServiceError("createClubMembershipInvitation", error);
    throw new Error(
      mapInvitationError(error, "Could not send this invitation."),
    );
  }

  return data;
}

export async function acceptClubMembershipInvitation(invitationId) {
  const { data, error } = await supabase.rpc(
    "accept_club_membership_invitation",
    { p_invitation_id: invitationId },
  );

  if (error) {
    logServiceError("acceptClubMembershipInvitation", error);
    throw new Error(
      mapInvitationError(error, "Could not accept this invitation."),
    );
  }

  return data;
}

export async function rejectClubMembershipInvitation(invitationId) {
  const { data, error } = await supabase.rpc(
    "reject_club_membership_invitation",
    { p_invitation_id: invitationId },
  );

  if (error) {
    logServiceError("rejectClubMembershipInvitation", error);
    throw new Error(
      mapInvitationError(error, "Could not reject this invitation."),
    );
  }

  return data;
}

export async function cancelClubMembershipInvitation(invitationId) {
  const { data, error } = await supabase.rpc(
    "cancel_club_membership_invitation",
    { p_invitation_id: invitationId },
  );

  if (error) {
    logServiceError("cancelClubMembershipInvitation", error);
    throw new Error(
      mapInvitationError(error, "Could not cancel this invitation."),
    );
  }

  return data;
}

export async function getMyPendingClubInvitations(userId) {
  let query = supabase
    .from("club_membership_invitations")
    .select(
      `
      ${INVITATION_FIELDS},
      clubs (
        id,
        name,
        slug,
        logo_url,
        status,
        deleted_at
      ),
      inviter:profiles!invited_by (
        id,
        full_name,
        email
      )
    `,
    )
    .eq("status", "PENDING")
    .order("created_at", { ascending: false });

  if (userId) {
    query = query.eq("invitee_user_id", userId);
  }

  const { data, error } = await query;

  if (error) {
    logServiceError("getMyPendingClubInvitations", error);
    throw new Error(
      getErrorMessage(error, "Could not load club invitations."),
    );
  }

  return (data ?? []).filter(
    (row) =>
      row.clubs && !row.clubs.deleted_at && row.clubs.status !== "ARCHIVED",
  );
}

export async function getClubPendingInvitations(clubId) {
  const { data, error } = await supabase
    .from("club_membership_invitations")
    .select(
      `
      ${INVITATION_FIELDS},
      invitee:profiles!invitee_user_id (
        id,
        full_name,
        email
      ),
      inviter:profiles!invited_by (
        id,
        full_name,
        email
      )
    `,
    )
    .eq("club_id", clubId)
    .eq("status", "PENDING")
    .order("created_at", { ascending: false });

  if (error) {
    logServiceError("getClubPendingInvitations", error);
    throw new Error(
      getErrorMessage(error, "Could not load pending invitations."),
    );
  }

  return data ?? [];
}
