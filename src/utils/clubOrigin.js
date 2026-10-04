export const CLUB_CREATION_ORIGINS = {
  NEW_APPLICATION: "NEW_APPLICATION",
  HISTORICAL_IMPORT: "HISTORICAL_IMPORT",
  UNKNOWN: "UNKNOWN",
};

/**
 * Server is the source of truth. These helpers only drive UI copy and
 * cannot change archive outcomes.
 */
export function isNewApplicationClub(club) {
  return club?.creation_origin === CLUB_CREATION_ORIGINS.NEW_APPLICATION;
}

export function isTerminalArchiveClub(club) {
  return Boolean(club?.deleted_at) || isNewApplicationClub(club);
}

export function archiveOutcomeForClub(club) {
  if (isNewApplicationClub(club)) {
    return "TERMINAL";
  }
  return "SOFT";
}

export function archiveSuccessNotice(clubName, outcome) {
  const name = clubName || "The club";
  if (outcome === "TERMINAL") {
    return `${name} was permanently removed from the portal and cannot be re-applied for.`;
  }
  return `${name} was archived. Management access was removed, and the club remains available for future re-application.`;
}
