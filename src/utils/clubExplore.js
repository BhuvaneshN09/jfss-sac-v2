export const CLUB_EXPLORE_DESKTOP_INITIAL_COUNT = 9;
export const CLUB_EXPLORE_MOBILE_INITIAL_COUNT = 6;
export const CLUB_EXPLORE_LOAD_MORE_COUNT = 6;
export const CLUB_EXPLORE_MOBILE_QUERY = "(max-width: 1024px)";

export function getClubExploreInitialCount(isMobile) {
  return isMobile
    ? CLUB_EXPLORE_MOBILE_INITIAL_COUNT
    : CLUB_EXPLORE_DESKTOP_INITIAL_COUNT;
}
