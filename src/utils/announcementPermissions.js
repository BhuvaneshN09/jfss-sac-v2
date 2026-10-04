import {
  getTorontoTodayYmd,
  isValidFutureTorontoPostingDate,
} from "./torontoDate";

export const ANNOUNCEMENT_STATUS_LABELS = {
  DRAFT: "Draft",
  SUBMITTED: "Submitted",
  UNDER_REVIEW: "Under review",
  CHANGES_REQUESTED: "Changes requested",
  PUBLISHED: "Published",
  REJECTED: "Rejected",
  CANCELLED: "Cancelled",
  ARCHIVED: "Archived",
};

export function canPublishDirectly({
  isSacAdmin = false,
  isFacultyAdvisor = false,
}) {
  // Kept for AuthContext compatibility. Direct publish is disabled;
  // staff submit for review and approve from the queue.
  return isSacAdmin || isFacultyAdvisor;
}

export function canCreateAnnouncement({
  isSacAdmin = false,
  isFacultyAdvisor = false,
  ownedClubs = [],
}) {
  return (
    canPublishDirectly({ isSacAdmin, isFacultyAdvisor }) ||
    (ownedClubs?.length ?? 0) > 0
  );
}

export function isClubOwnerFor(ownedClubs, clubId) {
  return (ownedClubs || []).some((club) => club.id === clubId);
}

export function canEditAnnouncement({
  announcement,
  userId,
  isSacAdmin = false,
  isFacultyAdvisor = false,
  ownedClubs = [],
}) {
  if (!announcement || !userId) return false;

  if (isSacAdmin) {
    return !["ARCHIVED", "CANCELLED", "REJECTED", "PUBLISHED"].includes(
      announcement.status,
    );
  }

  if (
    isFacultyAdvisor &&
    announcement.created_by === userId &&
    ["DRAFT", "CHANGES_REQUESTED"].includes(announcement.status)
  ) {
    return true;
  }

  if (
    announcement.created_by === userId &&
    announcement.club_id &&
    isClubOwnerFor(ownedClubs, announcement.club_id) &&
    ["DRAFT", "CHANGES_REQUESTED"].includes(announcement.status)
  ) {
    return true;
  }

  return false;
}

export function canArchiveAnnouncement({
  announcement,
  userId,
  isSacAdmin = false,
  isFacultyAdvisor = false,
}) {
  if (!announcement || announcement.status !== "PUBLISHED") return false;
  if (isSacAdmin) return true;
  return isFacultyAdvisor && announcement.created_by === userId;
}

export function getAllowedEditActions({
  announcement,
  userId,
  isSacAdmin = false,
  isFacultyAdvisor = false,
  ownedClubs = [],
}) {
  if (
    !canEditAnnouncement({
      announcement,
      userId,
      isSacAdmin,
      isFacultyAdvisor,
      ownedClubs,
    })
  ) {
    return [];
  }

  if (["DRAFT", "CHANGES_REQUESTED"].includes(announcement.status)) {
    return ["SAVE", "SUBMIT"];
  }

  if (isSacAdmin) {
    return ["SAVE"];
  }

  return [];
}

export function validateAnnouncementForm(
  values,
  { requireClub = false, requirePostingDate = false } = {},
) {
  const errors = {};
  const title = String(values.title ?? "").trim();
  const summaryRaw = String(values.summary ?? "").trim();
  const body = String(values.body ?? "").trim();
  const clubId = values.clubId || null;
  const visibility = String(values.visibility || "PUBLIC").trim().toUpperCase();
  const postingDateRaw = String(values.scheduledPostingDate ?? "").trim();

  if (title.length < 3 || title.length > 160) {
    errors.title = "Title must be between 3 and 160 characters.";
  }

  if (summaryRaw && summaryRaw.length > 500) {
    errors.summary = "Summary must be at most 500 characters.";
  }

  if (body.length < 10 || body.length > 30000) {
    errors.body = "Body must be between 10 and 30,000 characters.";
  }

  if (clubId && !["PUBLIC", "CLUB_MEMBERS"].includes(visibility)) {
    errors.visibility = "Choose who can see this announcement.";
  }

  if (requireClub && !clubId) {
    errors.clubId = "Select a club for this announcement.";
  }

  let scheduledPostingDate = null;
  if (requirePostingDate || postingDateRaw) {
    if (!postingDateRaw) {
      errors.scheduledPostingDate = "Announcement posting date is required.";
    } else if (!isValidFutureTorontoPostingDate(postingDateRaw)) {
      errors.scheduledPostingDate =
        "Choose today or a future date.";
    } else {
      scheduledPostingDate = postingDateRaw;
    }
  }

  return {
    isValid: Object.keys(errors).length === 0,
    errors,
    data: {
      title,
      summary: summaryRaw || null,
      body,
      clubId,
      visibility: clubId ? visibility : "PUBLIC",
      scheduledPostingDate,
    },
    minPostingDate: getTorontoTodayYmd(),
  };
}

export function announcementExcerpt(announcement, maxLength = 180) {
  const source =
    announcement?.body?.trim() ||
    announcement?.summary?.trim() ||
    "";
  if (source.length <= maxLength) return source;
  return `${source.slice(0, maxLength - 1).trimEnd()}…`;
}

export function toDateOnlyValue(value) {
  if (!value) return "";
  const raw = String(value);
  if (/^\d{4}-\d{2}-\d{2}$/.test(raw)) return raw;
  // Avoid shifting date-only ISO timestamps across timezones.
  const prefix = raw.slice(0, 10);
  return /^\d{4}-\d{2}-\d{2}$/.test(prefix) ? prefix : "";
}
