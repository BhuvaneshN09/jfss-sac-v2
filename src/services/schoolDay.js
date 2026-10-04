import { supabase } from "../lib/supabase";
import { getErrorMessage, logServiceError } from "../utils/errors";

export async function getEffectiveSchoolDay() {
  const { data, error } = await supabase.rpc(
    "get_effective_school_day",
    {},
    { get: true },
  );

  if (error) {
    logServiceError("getEffectiveSchoolDay", error);
    throw new Error(
      getErrorMessage(error, "Could not load today’s school day."),
    );
  }

  return data;
}

export async function setSchoolDayOverride(dayValue) {
  const { data, error } = await supabase.rpc("set_school_day_override", {
    p_day: dayValue,
  });

  if (error) {
    logServiceError("setSchoolDayOverride", error);
    throw new Error(
      getErrorMessage(error, "Could not update today’s school day override."),
    );
  }

  return data;
}

export async function clearSchoolDayOverride() {
  const { data, error } = await supabase.rpc("clear_school_day_override");

  if (error) {
    logServiceError("clearSchoolDayOverride", error);
    throw new Error(
      getErrorMessage(error, "Could not clear today’s school day override."),
    );
  }

  return data;
}

export async function setHalfDayOverride() {
  const { data, error } = await supabase.rpc("set_half_day_override");

  if (error) {
    logServiceError("setHalfDayOverride", error);
    throw new Error(
      getErrorMessage(error, "Could not set today’s half-day schedule."),
    );
  }

  return data;
}

export async function clearSchoolScheduleOverride() {
  const { data, error } = await supabase.rpc("clear_school_schedule_override");

  if (error) {
    logServiceError("clearSchoolScheduleOverride", error);
    throw new Error(
      getErrorMessage(error, "Could not clear today’s half-day schedule."),
    );
  }

  return data;
}
