/** Regular JFSS bell times (America/Toronto), including lunch. */
export const FULL_DAY_BELL_SLOTS = [
  { start: "08:25", end: "09:40" },
  { start: "09:43", end: "10:58" },
  { start: "10:58", end: "12:13" },
  { start: "12:13", end: "13:28" },
  { start: "13:31", end: "14:46" },
];

/** Half-day JFSS bell times (no lunch). */
export const HALF_DAY_BELL_SLOTS = [
  { start: "08:25", end: "09:02" },
  { start: "09:05", end: "09:42" },
  { start: "09:45", end: "10:22" },
  { start: "10:25", end: "11:02" },
];

/** Period labels for each chronological slot by school day + schedule mode. */
export const DAY_PERIOD_LABELS = {
  FULL: {
    DAY_1: ["Period 1", "Period 2", "Lunch", "Period 3", "Period 4"],
    DAY_2: ["Period 2", "Period 1", "Lunch", "Period 4", "Period 3"],
  },
  HALF: {
    DAY_1: ["Period 1", "Period 2", "Period 3", "Period 4"],
    DAY_2: ["Period 2", "Period 1", "Period 4", "Period 3"],
  },
};

const TIME_PATTERN = /^([01]\d|2[0-3]):([0-5]\d)$/;

/** Minutes since midnight for HH:MM, or null if invalid. */
export function timeToMinutes(value) {
  const match = TIME_PATTERN.exec(String(value || "").trim());
  if (!match) return null;
  return Number(match[1]) * 60 + Number(match[2]);
}

/** Format stored 24h HH:MM as "8:25 am". */
export function formatBellTime(hhmm) {
  const minutes = timeToMinutes(hhmm);
  if (minutes == null) return String(hhmm || "");
  const hours24 = Math.floor(minutes / 60);
  const mins = minutes % 60;
  const suffix = hours24 >= 12 ? "pm" : "am";
  const hours12 = hours24 % 12 || 12;
  return `${hours12}:${String(mins).padStart(2, "0")} ${suffix}`;
}

export function formatPeriodLine({ label, start, end }) {
  return `${label}: ${formatBellTime(start)} – ${formatBellTime(end)}`;
}

export function getBellSlots({ halfDay = false } = {}) {
  return (halfDay ? HALF_DAY_BELL_SLOTS : FULL_DAY_BELL_SLOTS).map((slot) => ({
    ...slot,
  }));
}

export function getPeriodLabels(dayValue, { halfDay = false } = {}) {
  const mode = halfDay ? "HALF" : "FULL";
  const byDay = DAY_PERIOD_LABELS[mode];
  return byDay[dayValue] || byDay.DAY_1;
}

/** Build labeled periods for a school day and schedule mode. */
export function buildDaySchedule(dayValue, { halfDay = false } = {}) {
  const labels = getPeriodLabels(dayValue, { halfDay });
  const slots = getBellSlots({ halfDay });
  return labels.map((label, index) => ({
    label,
    start: slots[index].start,
    end: slots[index].end,
    line: formatPeriodLine({
      label,
      start: slots[index].start,
      end: slots[index].end,
    }),
  }));
}
