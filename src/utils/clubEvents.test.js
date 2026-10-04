import { describe, expect, it } from "vitest";
import { validateClubEventForm } from "./clubEvents";
import { getTorontoTodayYmd } from "./torontoDate";

const validValues = {
  eventName: "Club social",
  eventDescription: "A club social in the cafeteria after school.",
  eventStartDate: getTorontoTodayYmd(),
  eventEndDate: getTorontoTodayYmd(),
  requestedMaterials: "Tables and chairs",
  signedForm: {},
};

describe("validateClubEventForm", () => {
  it("accepts a complete event proposal", () => {
    const result = validateClubEventForm(validValues);

    expect(result.isValid).toBe(true);
    expect(result.errors).toEqual({});
    expect(result.data.isCharitableEvent).toBe(false);
  });

  it("requires a future-or-today date", () => {
    const result = validateClubEventForm({
      ...validValues,
      eventStartDate: "2020-01-01",
      eventEndDate: "2020-01-01",
    });

    expect(result.isValid).toBe(false);
    expect(result.errors.eventStartDate).toBeDefined();
  });

  it("requires the end date to be on or after the start date", () => {
    const result = validateClubEventForm({
      ...validValues,
      eventStartDate: "2026-09-10",
      eventEndDate: "2026-09-09",
    });

    expect(result.isValid).toBe(false);
    expect(result.errors.eventEndDate).toBeDefined();
  });

  it("passes through whether the event is charitable", () => {
    const result = validateClubEventForm({
      ...validValues,
      isCharitableEvent: true,
    });

    expect(result.isValid).toBe(true);
    expect(result.data.isCharitableEvent).toBe(true);
  });

  it("requires the signed Event Approval Form", () => {
    const result = validateClubEventForm({
      ...validValues,
      signedForm: null,
    });

    expect(result.isValid).toBe(false);
    expect(result.errors.signedForm).toBe(
      "Attach the signed Event Approval Form.",
    );
  });
});
