import { CLUB_APPLICATION_SCHOOL_YEAR } from "../config/clubApplications";

export const CLUB_ROLE_ORDER = {
  OWNER: 0,
  EXEC: 1,
  MEMBER: 2,
};

export const CLUB_ROLE_LABELS = {
  OWNER: "Owner",
  EXEC: "Executive",
  MEMBER: "Member",
};

export function getClubRoleLabel(role) {
  return CLUB_ROLE_LABELS[role] || role || "Unknown";
}

/** Display label for a scoped club membership, e.g. "CS Club Executive". */
export function formatClubScopedRole(clubName, role) {
  const club = String(clubName || "Unknown club").trim() || "Unknown club";
  return `${club} ${getClubRoleLabel(role)}`;
}

export function getClubRole(memberships, clubId) {
  const match = (memberships || []).find(
    (membership) => membership.club_id === clubId,
  );
  return match?.role ?? null;
}

export function isClubOwner(role) {
  return role === "OWNER";
}

/** Approved clubs the user currently owns (for event/funding/supervisor forms). */
export function getOwnedApprovedClubs(memberships = []) {
  return (memberships || [])
    .filter((membership) => canSubmitClubRequestFormsFromMembership(membership))
    .map((membership) => membership.clubs)
    .filter(Boolean);
}

export function getMembershipAnnualStatus(
  membership,
  schoolYear = CLUB_APPLICATION_SCHOOL_YEAR,
) {
  const years = membership?.clubs?.club_school_years;
  if (Array.isArray(years)) {
    return years.find((row) => row.school_year === schoolYear)?.status ?? null;
  }
  return membership?.annualStatus ?? null;
}

/** Official, currently active clubs may submit event/funding/promo-lunch forms. */
export function canSubmitClubRequestForms({
  clubRole,
  membershipStatus,
  annualStatus,
  clubStatus,
  deletedAt = null,
} = {}) {
  if (deletedAt) return false;
  if (clubStatus && clubStatus !== "APPROVED") return false;
  if (!isClubOwner(clubRole) || membershipStatus !== "ACTIVE") {
    return false;
  }

  return annualStatus === "ACTIVE";
}

export function canSubmitClubRequestFormsFromMembership(membership) {
  return canSubmitClubRequestForms({
    clubRole: membership?.role,
    membershipStatus: membership?.status,
    annualStatus: getMembershipAnnualStatus(membership),
    clubStatus: membership?.clubs?.status,
    deletedAt: membership?.clubs?.deleted_at,
  });
}

export function getClubRequestBlockedMessage({
  clubStatus,
  annualStatus,
  noun = "requests",
  isSacAdmin = false,
} = {}) {
  if (clubStatus === "ARCHIVED") {
    return `Archived clubs cannot submit ${noun}.`;
  }
  if (annualStatus === "PENDING_SUPERVISOR") {
    return `This club is not officially on the site yet. ${capitalize(noun)} unlock after teacher supervisor approval.`;
  }
  if (isSacAdmin) {
    return `You can view this form, but only an active owner of this club can submit ${noun}.`;
  }
  return `Only an active owner of an officially active club can submit ${noun}.`;
}

function capitalize(value) {
  const text = String(value || "");
  if (!text) return text;
  return text.charAt(0).toUpperCase() + text.slice(1);
}

/** Active OWNER or site admin may archive a club (never permanently delete). */
export function canArchiveOwnedClub({
  clubRole,
  membershipStatus,
  annualStatus,
  clubStatus,
  isSacAdmin = false,
}) {
  if (clubStatus === "ARCHIVED") {
    return false;
  }

  if (isSacAdmin) {
    return true;
  }

  if (!isClubOwner(clubRole) || membershipStatus !== "ACTIVE") {
    return false;
  }

  return annualStatus === "ACTIVE" || annualStatus === "PENDING_SUPERVISOR";
}

export function isClubExec(role) {
  return role === "EXEC";
}

export function canSearchStudents({ clubRole, isSacAdmin = false }) {
  return isSacAdmin || isClubOwner(clubRole);
}

export function getAddableRoles({
  currentUserRole,
  isSacAdmin = false,
  activeOwnerCount = 0,
  pendingOwnerInvitationCount = 0,
}) {
  // Invitations are owner-only. EXECs keep other manage capabilities.
  if (!(isSacAdmin || isClubOwner(currentUserRole))) {
    return [];
  }

  const roles = ["MEMBER", "EXEC"];
  const reservedOwners =
    Number(activeOwnerCount || 0) + Number(pendingOwnerInvitationCount || 0);
  if (reservedOwners < 3) {
    roles.push("OWNER");
  }
  return roles;
}

export function getInvitableRoles(options) {
  return getAddableRoles(options);
}

export function canAddClubRole({
  currentUserRole,
  newRole,
  isSacAdmin = false,
  activeOwnerCount = 0,
  pendingOwnerInvitationCount = 0,
}) {
  return getAddableRoles({
    currentUserRole,
    isSacAdmin,
    activeOwnerCount,
    pendingOwnerInvitationCount,
  }).includes(newRole);
}

export function canChangeMemberRole({
  currentUserRole,
  targetCurrentRole,
  targetNewRole,
  isSacAdmin = false,
}) {
  return canChangeClubRole({
    currentUserRole,
    targetRole: targetCurrentRole,
    newRole: targetNewRole,
    isSacAdmin,
  });
}

export function canChangeClubRole({
  currentUserRole,
  targetRole,
  targetCurrentRole,
  newRole,
  targetNewRole,
  isSacAdmin = false,
}) {
  const currentTargetRole = targetCurrentRole ?? targetRole;
  const nextRole = targetNewRole ?? newRole;

  if (!nextRole || currentTargetRole === nextRole) {
    return false;
  }

  if (currentTargetRole === "OWNER" || nextRole === "OWNER") {
    return false;
  }

  // EXEC may only keep MEMBER as MEMBER (reactivation), not promote/demote.
  if (isSacAdmin || isClubOwner(currentUserRole)) {
    return nextRole === "EXEC" || nextRole === "MEMBER";
  }

  return false;
}

export function canRemoveMember({
  currentUserRole,
  targetRole,
  isSelf = false,
  isSacAdmin = false,
}) {
  return canRemoveClubMember({
    currentUserRole,
    targetRole,
    isSelf,
    isSacAdmin,
  });
}

export function canRemoveClubMember({
  currentUserRole,
  targetRole,
  isSelf = false,
  isSacAdmin = false,
  activeOwnerCount = 1,
}) {
  if (targetRole === "OWNER") {
    if (isSacAdmin && activeOwnerCount > 1) {
      return true;
    }
    if (isSelf && isClubOwner(currentUserRole) && activeOwnerCount > 1) {
      return true;
    }
    return false;
  }

  if (isSacAdmin) {
    return true;
  }

  if (isClubOwner(currentUserRole)) {
    return targetRole === "EXEC" || targetRole === "MEMBER";
  }

  if (isClubExec(currentUserRole)) {
    return targetRole === "MEMBER";
  }

  if (isSelf && (targetRole === "EXEC" || targetRole === "MEMBER")) {
    return true;
  }

  return false;
}

export function sortClubMemberships(memberships) {
  return [...(memberships || [])].sort((a, b) => {
    const roleDiff =
      (CLUB_ROLE_ORDER[a.role] ?? 99) - (CLUB_ROLE_ORDER[b.role] ?? 99);

    if (roleDiff !== 0) return roleDiff;

    const aLabel = (
      a.profile?.full_name ||
      a.profile?.email ||
      a.user_id ||
      ""
    ).toLowerCase();
    const bLabel = (
      b.profile?.full_name ||
      b.profile?.email ||
      b.user_id ||
      ""
    ).toLowerCase();

    return aLabel.localeCompare(bLabel);
  });
}

export function normalizePdsbEmail(email) {
  return String(email ?? "").trim().toLowerCase();
}

export function getEmailDomain(email) {
  return normalizePdsbEmail(email).split("@").pop() || "";
}

export function isValidPdsbEmail(email) {
  const normalized = normalizePdsbEmail(email);
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalized)) {
    return false;
  }
  return getEmailDomain(normalized) === "pdsb.net";
}
