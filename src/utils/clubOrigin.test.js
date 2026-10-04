import { describe, expect, it } from "vitest";
import {
  archiveOutcomeForClub,
  archiveSuccessNotice,
  isNewApplicationClub,
  isTerminalArchiveClub,
} from "./clubOrigin.js";

describe("club archive origin helpers", () => {
  it("treats NEW_APPLICATION as terminal archive outcome", () => {
    const club = { creation_origin: "NEW_APPLICATION", name: "Robotics" };
    expect(isNewApplicationClub(club)).toBe(true);
    expect(isTerminalArchiveClub(club)).toBe(true);
    expect(archiveOutcomeForClub(club)).toBe("TERMINAL");
    expect(archiveSuccessNotice(club.name, "TERMINAL")).toMatch(
      /permanently removed/,
    );
  });

  it("treats HISTORICAL_IMPORT as soft archive", () => {
    const club = { creation_origin: "HISTORICAL_IMPORT", name: "Chefs" };
    expect(isNewApplicationClub(club)).toBe(false);
    expect(archiveOutcomeForClub(club)).toBe("SOFT");
    expect(archiveSuccessNotice(club.name, "SOFT")).toMatch(/re-application/);
  });

  it("does not let client status spoof terminal behavior", () => {
    const spoofed = {
      creation_origin: "HISTORICAL_IMPORT",
      status: "APPROVED",
      eligible_for_reapplication: false,
    };
    expect(archiveOutcomeForClub(spoofed)).toBe("SOFT");
    expect(isNewApplicationClub(spoofed)).toBe(false);
  });

  it("recognizes already-deleted clubs as terminal for UI", () => {
    expect(
      isTerminalArchiveClub({
        creation_origin: "HISTORICAL_IMPORT",
        deleted_at: "2026-07-31T00:00:00Z",
      }),
    ).toBe(true);
  });

  it("keeps UNKNOWN on the soft-archive path", () => {
    expect(archiveOutcomeForClub({ creation_origin: "UNKNOWN" })).toBe("SOFT");
  });
});
