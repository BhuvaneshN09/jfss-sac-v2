const TORONTO_TZ = "America/Toronto";
const YMD_PATTERN = /^(\d{4})-(\d{2})-(\d{2})$/;

/** Today's calendar date in America/Toronto as YYYY-MM-DD. */
export function getTorontoTodayYmd(now = new Date()) {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: TORONTO_TZ,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(now);
}

/** Add whole calendar days to a YYYY-MM-DD string (timezone-agnostic). */
export function addCalendarDaysYmd(ymd, days) {
  const match = YMD_PATTERN.exec(String(ymd || "").trim());
  if (!match) return "";

  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const utc = new Date(Date.UTC(year, month - 1, day + Number(days)));
  const y = utc.getUTCFullYear();
  const m = String(utc.getUTCMonth() + 1).padStart(2, "0");
  const d = String(utc.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

export function getTorontoTomorrowYmd(now = new Date()) {
  return addCalendarDaysYmd(getTorontoTodayYmd(now), 1);
}

/** Whole calendar days from `fromYmd` to `toYmd` (to - from). */
export function diffCalendarDaysYmd(fromYmd, toYmd) {
  const from = YMD_PATTERN.exec(String(fromYmd || "").trim());
  const to = YMD_PATTERN.exec(String(toYmd || "").trim());
  if (!from || !to) return null;

  const fromUtc = Date.UTC(
    Number(from[1]),
    Number(from[2]) - 1,
    Number(from[3]),
  );
  const toUtc = Date.UTC(Number(to[1]), Number(to[2]) - 1, Number(to[3]));
  return Math.round((toUtc - fromUtc) / 86_400_000);
}

/**
 * Days remaining until a scheduled Toronto posting date, relative to Toronto today.
 * 1 = posts tomorrow.
 */
export function getPostingDaysRemaining(scheduledYmd, now = new Date()) {
  return diffCalendarDaysYmd(getTorontoTodayYmd(now), scheduledYmd);
}

export function getPostingUrgency(scheduledYmd, now = new Date()) {
  const days = getPostingDaysRemaining(scheduledYmd, now);
  if (days == null || days < 0) {
    return {
      days,
      tone: "danger",
      label: "Past due",
    };
  }
  if (days === 0) {
    return { days, tone: "danger", label: "Publish now" };
  }
  if (days === 1) {
    return { days, tone: "danger", label: "Posts tomorrow" };
  }
  if (days === 2) {
    return { days, tone: "warning", label: "Posts in 2 days" };
  }
  if (days === 3) {
    return { days, tone: "warning", label: "Posts in 3 days" };
  }
  return {
    days,
    tone: "success",
    label: `Posts in ${days} days`,
  };
}

/** Format a YYYY-MM-DD calendar date without timezone shift. */
export function formatDateOnly(ymd) {
  if (!ymd) return "—";
  const match = YMD_PATTERN.exec(String(ymd).trim());
  if (!match) return String(ymd);

  try {
    return new Intl.DateTimeFormat(undefined, {
      dateStyle: "medium",
      timeZone: "UTC",
    }).format(
      new Date(
        Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3])),
      ),
    );
  } catch {
    return String(ymd);
  }
}

/** True when ymd is today or a future America/Toronto calendar date. */
export function isValidFutureTorontoPostingDate(ymd, now = new Date()) {
  if (!YMD_PATTERN.test(String(ymd || "").trim())) return false;
  return diffCalendarDaysYmd(getTorontoTodayYmd(now), ymd) >= 0;
}

export function getAutomaticSchoolDay(ymd, now = new Date()) {
  const dateYmd = ymd || getTorontoTodayYmd(now);
  const match = YMD_PATTERN.exec(String(dateYmd).trim());
  if (!match) return null;
  const dayOfMonth = Number(match[3]);
  return dayOfMonth % 2 === 1 ? "DAY_1" : "DAY_2";
}

export function schoolDayLabel(dayValue) {
  if (dayValue === "DAY_1") return "Day 1";
  if (dayValue === "DAY_2") return "Day 2";
  return "—";
}

/**
 * Milliseconds until the next America/Toronto midnight.
 * Uses binary search so daylight-saving transitions are handled safely.
 */
export function msUntilNextTorontoMidnight(now = new Date()) {
  const tomorrowYmd = getTorontoTomorrowYmd(now);
  let lo = now.getTime();
  let hi = now.getTime() + 36 * 60 * 60 * 1000;

  while (hi - lo > 250) {
    const mid = Math.floor((lo + hi) / 2);
    if (getTorontoTodayYmd(new Date(mid)) < tomorrowYmd) {
      lo = mid;
    } else {
      hi = mid;
    }
  }

  return Math.max(hi - now.getTime(), 1000);
}
