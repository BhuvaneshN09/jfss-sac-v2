export function getVisibleMeetingSchedule(schedule) {
  const value = String(schedule ?? "").trim();

  if (!value || value.toLowerCase() === "biweekly") {
    return null;
  }

  return value;
}
