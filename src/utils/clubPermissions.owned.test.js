import { describe, expect, it } from "vitest";
import {
  canArchiveOwnedClub,
  canSubmitClubRequestForms,
  getClubRequestBlockedMessage,
  getOwnedApprovedClubs,
} from "./clubPermissions.js";

describe("getOwnedApprovedClubs", () => {
  it("returns officially active clubs the user owns", () => {
    const clubs = getOwnedApprovedClubs([
      {
        status: "ACTIVE",
        role: "OWNER",
        clubs: {
          id: "1",
          name: "Chess",
          status: "APPROVED",
          deleted_at: null,
          club_school_years: [
            { school_year: "2026-2027", status: "ACTIVE" },
          ],
        },
      },
      {
        status: "ACTIVE",
        role: "EXEC",
        clubs: {
          id: "2",
          name: "Drama",
          status: "APPROVED",
          deleted_at: null,
          club_school_years: [
            { school_year: "2026-2027", status: "ACTIVE" },
          ],
        },
      },
      {
        status: "ACTIVE",
        role: "OWNER",
        clubs: {
          id: "3",
          name: "Old",
          status: "ARCHIVED",
          deleted_at: null,
          club_school_years: [
            { school_year: "2026-2027", status: "INACTIVE" },
          ],
        },
      },
      {
        status: "ACTIVE",
        role: "OWNER",
        clubs: {
          id: "4",
          name: "Pending",
          status: "APPROVED",
          deleted_at: null,
          club_school_years: [
            { school_year: "2026-2027", status: "PENDING_SUPERVISOR" },
          ],
        },
      },
    ]);

    expect(clubs).toEqual([
      expect.objectContaining({ id: "1", name: "Chess" }),
    ]);
  });
});

describe("canSubmitClubRequestForms", () => {
  it("allows active owners of officially active clubs", () => {
    expect(
      canSubmitClubRequestForms({
        clubRole: "OWNER",
        membershipStatus: "ACTIVE",
        annualStatus: "ACTIVE",
        clubStatus: "APPROVED",
      }),
    ).toBe(true);
  });

  it("blocks pending-supervisor, archived, and inactive clubs", () => {
    expect(
      canSubmitClubRequestForms({
        clubRole: "OWNER",
        membershipStatus: "ACTIVE",
        annualStatus: "PENDING_SUPERVISOR",
        clubStatus: "APPROVED",
      }),
    ).toBe(false);
    expect(
      canSubmitClubRequestForms({
        clubRole: "OWNER",
        membershipStatus: "ACTIVE",
        annualStatus: "ACTIVE",
        clubStatus: "ARCHIVED",
      }),
    ).toBe(false);
    expect(
      canSubmitClubRequestForms({
        clubRole: "OWNER",
        membershipStatus: "ACTIVE",
        annualStatus: "INACTIVE",
        clubStatus: "APPROVED",
      }),
    ).toBe(false);
    expect(
      canSubmitClubRequestForms({
        clubRole: "OWNER",
        membershipStatus: "ACTIVE",
      }),
    ).toBe(false);
  });

  it("blocks executives", () => {
    expect(
      canSubmitClubRequestForms({
        clubRole: "EXEC",
        membershipStatus: "ACTIVE",
        annualStatus: "ACTIVE",
        clubStatus: "APPROVED",
      }),
    ).toBe(false);
  });

  it("does not let site admins submit as a non-owner", () => {
    expect(
      canSubmitClubRequestForms({
        clubRole: "MEMBER",
        membershipStatus: "ACTIVE",
        annualStatus: "ACTIVE",
        clubStatus: "APPROVED",
      }),
    ).toBe(false);
  });
});

describe("getClubRequestBlockedMessage", () => {
  it("explains archived and pending-supervisor clubs", () => {
    expect(
      getClubRequestBlockedMessage({ clubStatus: "ARCHIVED", noun: "requests" }),
    ).toBe("Archived clubs cannot submit requests.");
    expect(
      getClubRequestBlockedMessage({
        annualStatus: "PENDING_SUPERVISOR",
        noun: "announcements",
      }),
    ).toBe(
      "This club is not officially on the site yet. Announcements unlock after teacher supervisor approval.",
    );
    expect(
      getClubRequestBlockedMessage({
        clubStatus: "APPROVED",
        annualStatus: "ACTIVE",
        isSacAdmin: true,
        noun: "requests",
      }),
    ).toBe(
      "You can view this form, but only an active owner of this club can submit requests.",
    );
  });
});

describe("canArchiveOwnedClub", () => {
  it("allows active owners of ACTIVE or pending-supervisor clubs", () => {
    expect(
      canArchiveOwnedClub({
        clubRole: "OWNER",
        membershipStatus: "ACTIVE",
        annualStatus: "ACTIVE",
      }),
    ).toBe(true);
    expect(
      canArchiveOwnedClub({
        clubRole: "OWNER",
        membershipStatus: "ACTIVE",
        annualStatus: "PENDING_SUPERVISOR",
      }),
    ).toBe(true);
  });

  it("blocks executives, inactive memberships, and inactive annual clubs", () => {
    expect(
      canArchiveOwnedClub({
        clubRole: "EXEC",
        membershipStatus: "ACTIVE",
        annualStatus: "ACTIVE",
      }),
    ).toBe(false);
    expect(
      canArchiveOwnedClub({
        clubRole: "OWNER",
        membershipStatus: "INACTIVE",
        annualStatus: "ACTIVE",
      }),
    ).toBe(false);
    expect(
      canArchiveOwnedClub({
        clubRole: "OWNER",
        membershipStatus: "ACTIVE",
        annualStatus: "INACTIVE",
      }),
    ).toBe(false);
  });

  it("allows site admins to archive any club they do not own", () => {
    expect(
      canArchiveOwnedClub({
        isSacAdmin: true,
        annualStatus: "ACTIVE",
      }),
    ).toBe(true);
    expect(
      canArchiveOwnedClub({
        isSacAdmin: true,
        clubRole: "MEMBER",
        membershipStatus: "ACTIVE",
        annualStatus: "PENDING_SUPERVISOR",
      }),
    ).toBe(true);
    expect(
      canArchiveOwnedClub({
        isSacAdmin: true,
        annualStatus: "INACTIVE",
      }),
    ).toBe(true);
    expect(
      canArchiveOwnedClub({
        isSacAdmin: true,
        annualStatus: "SUSPENDED",
      }),
    ).toBe(true);
    expect(
      canArchiveOwnedClub({
        isSacAdmin: true,
      }),
    ).toBe(true);
    expect(
      canArchiveOwnedClub({
        isSacAdmin: true,
        clubStatus: "ARCHIVED",
        annualStatus: "INACTIVE",
      }),
    ).toBe(false);
  });
});
