import { isClubOwner, canSubmitClubRequestFormsFromMembership } from "./clubPermissions";

/**
 * Subtabs for My Requests — only kinds the user can submit with their roles.
 * Club applications / re-applications are available to every signed-in user.
 */
export function buildMyRequestTabs({
  canCreateAnnouncements = false,
  memberships = [],
} = {}) {
  const activeMemberships = (memberships || []).filter(
    (membership) => membership.status === "ACTIVE" && membership.clubs,
  );
  const canSubmitOfficialClubRequests = activeMemberships.some((membership) =>
    canSubmitClubRequestFormsFromMembership(membership),
  );
  const canSubmitSupervisor = activeMemberships.some((membership) =>
    isClubOwner(membership.role),
  );
  const canSubmitFunding = canSubmitOfficialClubRequests;
  const canSubmitEvents = canSubmitOfficialClubRequests;
  const canSubmitPromoLunch = canSubmitOfficialClubRequests;

  return [
    {
      id: "clubRequests",
      to: "/my-requests/club-requests",
      label: "Club Applications",
    },
    ...(canCreateAnnouncements
      ? [
          {
            id: "announcements",
            to: "/my-requests/announcements",
            label: "Announcements",
          },
        ]
      : []),
    ...(canSubmitSupervisor
      ? [
          {
            id: "supervisor",
            to: "/my-requests/supervisor",
            label: "Supervisor",
          },
        ]
      : []),
    ...(canSubmitFunding
      ? [
          {
            id: "funding",
            to: "/my-requests/funding",
            label: "Club Funding",
          },
        ]
      : []),
    ...(canSubmitEvents
      ? [
          {
            id: "events",
            to: "/my-requests/events",
            label: "Events",
          },
        ]
      : []),
    ...(canSubmitPromoLunch
      ? [
          {
            id: "promoLunch",
            to: "/my-requests/promo-lunch",
            label: "Promo Lunch",
          },
        ]
      : []),
  ];
}
