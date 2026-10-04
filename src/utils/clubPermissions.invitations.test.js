import { describe, expect, it } from "vitest";
import {
  getAddableRoles,
  getInvitableRoles,
  canAddClubRole,
} from "./clubPermissions.js";

describe("club invitation role rules", () => {
  it("allows owners to invite MEMBER/EXEC/OWNER when slots remain", () => {
    expect(
      getInvitableRoles({
        currentUserRole: "OWNER",
        activeOwnerCount: 2,
        pendingOwnerInvitationCount: 0,
      }),
    ).toEqual(["MEMBER", "EXEC", "OWNER"]);
  });

  it("blocks a fourth owner slot including pending invitations", () => {
    expect(
      getInvitableRoles({
        currentUserRole: "OWNER",
        activeOwnerCount: 2,
        pendingOwnerInvitationCount: 1,
      }),
    ).toEqual(["MEMBER", "EXEC"]);

    expect(
      canAddClubRole({
        currentUserRole: "OWNER",
        newRole: "OWNER",
        activeOwnerCount: 3,
        pendingOwnerInvitationCount: 0,
      }),
    ).toBe(false);
  });

  it("does not let executives send invitations", () => {
    expect(
      getAddableRoles({
        currentUserRole: "EXEC",
        activeOwnerCount: 1,
      }),
    ).toEqual([]);
  });
});
