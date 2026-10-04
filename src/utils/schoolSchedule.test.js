import { describe, expect, it } from "vitest";
import {
  buildDaySchedule,
  formatBellTime,
  formatPeriodLine,
} from "./schoolSchedule";

describe("schoolSchedule", () => {
  it("formats regular day 1 and day 2 period lines", () => {
    const day1 = buildDaySchedule("DAY_1");
    expect(day1.map((period) => period.line)).toEqual([
      "Period 1: 8:25 am – 9:40 am",
      "Period 2: 9:43 am – 10:58 am",
      "Lunch: 10:58 am – 12:13 pm",
      "Period 3: 12:13 pm – 1:28 pm",
      "Period 4: 1:31 pm – 2:46 pm",
    ]);

    const day2 = buildDaySchedule("DAY_2");
    expect(day2.map((period) => period.label)).toEqual([
      "Period 2",
      "Period 1",
      "Lunch",
      "Period 4",
      "Period 3",
    ]);
  });

  it("formats half-day schedules with day-dependent period order", () => {
    const day1 = buildDaySchedule("DAY_1", { halfDay: true });
    expect(day1.map((period) => period.line)).toEqual([
      "Period 1: 8:25 am – 9:02 am",
      "Period 2: 9:05 am – 9:42 am",
      "Period 3: 9:45 am – 10:22 am",
      "Period 4: 10:25 am – 11:02 am",
    ]);

    const day2 = buildDaySchedule("DAY_2", { halfDay: true });
    expect(day2.map((period) => period.line)).toEqual([
      "Period 2: 8:25 am – 9:02 am",
      "Period 1: 9:05 am – 9:42 am",
      "Period 4: 9:45 am – 10:22 am",
      "Period 3: 10:25 am – 11:02 am",
    ]);
  });

  it("formats 24h times for display", () => {
    expect(formatBellTime("08:25")).toBe("8:25 am");
    expect(formatBellTime("13:28")).toBe("1:28 pm");
    expect(
      formatPeriodLine({ label: "Lunch", start: "10:58", end: "12:13" }),
    ).toBe("Lunch: 10:58 am – 12:13 pm");
  });
});
