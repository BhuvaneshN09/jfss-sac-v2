import { describe, expect, it } from "vitest";
import {
  getPromoLunchConfirmationDays,
  getPromoLunchDaysLabel,
  parsePromoLunchConfirmation,
  validateClubPromoLunchForm,
} from "./clubPromoLunch";

describe("validateClubPromoLunchForm", () => {
  it("accepts a complete sign-up", () => {
    const result = validateClubPromoLunchForm({
      boothDays: "BOTH",
      approvalEmailReceived: true,
      representatives: "Jason Chou - jason@example.com",
    });

    expect(result.isValid).toBe(true);
    expect(result.errors).toEqual({});
  });

  it("accepts October 6 or October 7", () => {
    expect(
      validateClubPromoLunchForm({
        boothDays: "OCTOBER_6",
        approvalEmailReceived: false,
        representatives: "Jason Chou - jason@example.com",
      }).isValid,
    ).toBe(true);
    expect(
      validateClubPromoLunchForm({
        boothDays: "OCTOBER_7",
        approvalEmailReceived: false,
        representatives: "Jason Chou - jason@example.com",
      }).isValid,
    ).toBe(true);
  });

  it("requires all sign-up details", () => {
    const result = validateClubPromoLunchForm({
      boothDays: "",
      approvalEmailReceived: null,
      representatives: "",
    });

    expect(result.isValid).toBe(false);
    expect(Object.keys(result.errors)).toHaveLength(3);
  });
});

describe("getPromoLunchDaysLabel", () => {
  it("labels the Club Promo Lunch booth days", () => {
    expect(getPromoLunchDaysLabel("OCTOBER_6")).toBe("October 6th");
    expect(getPromoLunchDaysLabel("OCTOBER_7")).toBe("October 7th");
    expect(getPromoLunchDaysLabel("BOTH")).toBe("Both");
  });
});

describe("getPromoLunchConfirmationDays", () => {
  it("lists each confirmed booth day", () => {
    expect(getPromoLunchConfirmationDays("OCTOBER_6")).toEqual(["October 6th"]);
    expect(getPromoLunchConfirmationDays("OCTOBER_7")).toEqual(["October 7th"]);
    expect(getPromoLunchConfirmationDays("BOTH")).toEqual([
      "October 6th",
      "October 7th",
    ]);
    expect(getPromoLunchConfirmationDays(null)).toEqual([]);
  });
});

describe("parsePromoLunchConfirmation", () => {
  it("reads booth days from the public confirmation", () => {
    expect(parsePromoLunchConfirmation("OCTOBER_6")).toEqual({
      status: "APPROVED",
      boothDays: "OCTOBER_6",
    });
    expect(parsePromoLunchConfirmation(true)).toEqual({
      status: "APPROVED",
      boothDays: null,
    });
    expect(parsePromoLunchConfirmation(false)).toBeNull();
    expect(parsePromoLunchConfirmation(null)).toBeNull();
  });
});
