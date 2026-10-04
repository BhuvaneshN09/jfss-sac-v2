export function formatDate(value) {
  if (!value) return "—";

  try {
    return new Intl.DateTimeFormat(undefined, {
      dateStyle: "medium",
      timeStyle: "short",
    }).format(new Date(value));
  } catch {
    return String(value);
  }
}

/** Human-readable time until/after a deadline (for supervisor due dates). */
export function formatDeadlineRelative(value, now = Date.now()) {
  if (!value) return "Deadline missing";

  const dueMs = new Date(value).getTime();
  if (Number.isNaN(dueMs)) return "Deadline missing";

  const diffMs = dueMs - now;
  const absMinutes = Math.round(Math.abs(diffMs) / 60000);
  const days = Math.floor(absMinutes / (60 * 24));
  const hours = Math.floor((absMinutes % (60 * 24)) / 60);
  const minutes = absMinutes % 60;

  let span;
  if (days > 0) {
    span = `${days} day${days === 1 ? "" : "s"}`;
    if (hours > 0) span += ` ${hours} hr`;
  } else if (hours > 0) {
    span = `${hours} hour${hours === 1 ? "" : "s"}`;
  } else {
    span = `${Math.max(minutes, 1)} min`;
  }

  return diffMs < 0 ? `${span} overdue` : `${span} remaining`;
}

export function displayName(profile, user) {
  return (
    profile?.full_name?.trim() ||
    user?.user_metadata?.full_name ||
    user?.user_metadata?.name ||
    user?.email ||
    "Signed-in user"
  );
}
