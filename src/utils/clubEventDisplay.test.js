import { describe, expect, it } from "vitest";
import { getClubEventDisplayNames } from "./clubEventDisplay";

describe("getClubEventDisplayNames", () => {
  it("shows Sikh Student Association as a co-host for Diwali After Dark", () => {
    expect(
      getClubEventDisplayNames({
        event_name: "Diwali After Dark",
        club_name: "Hindu Student Association",
      }),
    ).toEqual(["Hindu Student Association", "Sikh Student Association"]);
  });

  it("leaves other event club names unchanged", () => {
    expect(
      getClubEventDisplayNames({
        event_name: "Club Social",
        club_name: "Hindu Student Association",
      }),
    ).toEqual(["Hindu Student Association"]);
  });
});
