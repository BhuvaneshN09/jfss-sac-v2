export function getClubEventDisplayNames(event) {
  const clubName = event?.club_name || event?.clubs?.name || "";
  const eventName = event?.event_name || event?.title || "";
  const clubNames = clubName ? [clubName] : [];

  if (
    eventName.trim().toLowerCase() === "diwali after dark" &&
    clubName.trim().toLowerCase() === "hindu student association"
  ) {
    clubNames.push("Sikh Student Association");
  }

  return clubNames;
}
