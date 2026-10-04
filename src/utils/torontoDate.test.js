import { describe, expect, it } from "vitest";
import {
  addCalendarDaysYmd,
  diffCalendarDaysYmd,
  getAutomaticSchoolDay,
  getPostingUrgency,
  getTorontoTodayYmd,
  getTorontoTomorrowYmd,
  isValidFutureTorontoPostingDate,
  msUntilNextTorontoMidnight,
  schoolDayLabel,
} from "./torontoDate";

describe("torontoDate", () => {
  it("adds calendar days across month boundaries", () => {
    expect(addCalendarDaysYmd("2026-01-31", 1)).toBe("2026-02-01");
    expect(addCalendarDaysYmd("2026-02-28", 1)).toBe("2026-03-01");
  });

  it("diffs calendar days", () => {
    expect(diffCalendarDaysYmd("2026-08-04", "2026-08-05")).toBe(1);
    expect(diffCalendarDaysYmd("2026-08-04", "2026-08-08")).toBe(4);
  });

  it("computes urgency labels from remaining days", () => {
    const today = getTorontoTodayYmd();
    expect(getPostingUrgency(addCalendarDaysYmd(today, 1)).label).toBe(
      "Posts tomorrow",
    );
    expect(getPostingUrgency(addCalendarDaysYmd(today, 2)).tone).toBe(
      "warning",
    );
    expect(getPostingUrgency(addCalendarDaysYmd(today, 3)).label).toBe(
      "Posts in 3 days",
    );
    expect(getPostingUrgency(addCalendarDaysYmd(today, 5)).tone).toBe(
      "success",
    );
  });

  it("allows today and future posting dates, rejects past", () => {
    const today = getTorontoTodayYmd();
    expect(isValidFutureTorontoPostingDate(today)).toBe(true);
    expect(
      isValidFutureTorontoPostingDate(addCalendarDaysYmd(today, -1)),
    ).toBe(false);
    expect(isValidFutureTorontoPostingDate(getTorontoTomorrowYmd())).toBe(
      true,
    );
  });

  it("labels same-day requests as publish now", () => {
    const today = getTorontoTodayYmd();
    expect(getPostingUrgency(today).label).toBe("Publish now");
  });

  it("maps odd Toronto dates to Day 1 and even to Day 2", () => {
    expect(getAutomaticSchoolDay("2026-01-04")).toBe("DAY_2");
    expect(getAutomaticSchoolDay("2026-01-05")).toBe("DAY_1");
    expect(getAutomaticSchoolDay("2026-02-28")).toBe("DAY_2");
    expect(getAutomaticSchoolDay("2026-03-01")).toBe("DAY_1");
    expect(schoolDayLabel("DAY_1")).toBe("Day 1");
    expect(schoolDayLabel("DAY_2")).toBe("Day 2");
  });

  it("computes a positive delay until the next Toronto midnight", () => {
    expect(msUntilNextTorontoMidnight()).toBeGreaterThan(0);
    expect(msUntilNextTorontoMidnight()).toBeLessThanOrEqual(
      36 * 60 * 60 * 1000,
    );
  });
});
