import { describe, expect, it } from "vitest";
import {
  CLUB_EXPLORE_DESKTOP_INITIAL_COUNT,
  CLUB_EXPLORE_LOAD_MORE_COUNT,
  CLUB_EXPLORE_MOBILE_INITIAL_COUNT,
  getClubExploreInitialCount,
} from "./clubExplore.js";

describe("club explore paging", () => {
  it("starts with nine clubs on desktop and six on mobile", () => {
    expect(getClubExploreInitialCount(false)).toBe(
      CLUB_EXPLORE_DESKTOP_INITIAL_COUNT,
    );
    expect(getClubExploreInitialCount(true)).toBe(
      CLUB_EXPLORE_MOBILE_INITIAL_COUNT,
    );
    expect(CLUB_EXPLORE_DESKTOP_INITIAL_COUNT).toBe(9);
    expect(CLUB_EXPLORE_MOBILE_INITIAL_COUNT).toBe(6);
  });

  it("adds six clubs when Load six more is pressed", () => {
    expect(CLUB_EXPLORE_LOAD_MORE_COUNT).toBe(6);
  });
});
