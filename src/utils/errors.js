const SCHOOL_NETWORK_SIGN_IN_MESSAGE =
  "This network blocked the sign-in request. On school Wi-Fi, try a phone hotspot, then reload.";

export const SIGN_IN_TO_SEE_MESSAGE = "Sign in to see this.";
export const CLUB_NAME_TAKEN_MESSAGE =
  "A club with that name already exists.";

function isOpaqueSerializedMessage(message) {
  const trimmed = String(message || "").trim();
  return trimmed === "{}" || trimmed === "[]" || trimmed === "null";
}

export function isSignInRequiredMessage(message) {
  const lower = String(message || "").toLowerCase();
  return (
    lower.includes("sign in to see") ||
    lower.includes("you do not have permission to perform this action") ||
    lower.includes("permission denied") ||
    lower.includes("42501") ||
    lower.includes("row-level security")
  );
}

export function getErrorMessage(error, fallback = "Something went wrong.") {
  if (!error) return fallback;

  const message =
    typeof error === "string"
      ? error
      : error.message || error.error_description || fallback;

  const status = typeof error === "object" ? error.status ?? error.statusCode : undefined;
  const lower = message.toLowerCase();

  if (
    status === 413 ||
    lower.includes("http 413") ||
    lower.includes("payload too large") ||
    lower.includes("function_payload_too_large")
  ) {
    return "The file was too large to upload. Try a smaller JPEG photo and submit again.";
  }

  if (
    status === 502 ||
    status === 503 ||
    status === 504 ||
    isOpaqueSerializedMessage(message)
  ) {
    return SCHOOL_NETWORK_SIGN_IN_MESSAGE;
  }

  if (
    lower.includes("the page could not be found") ||
    (lower.includes("not_found") && /::[a-z0-9]+-/i.test(message))
  ) {
    return "Could not reach the API. Refresh the page after the latest deploy is live.";
  }

  if (lower.includes("duplicate key") || lower.includes("unique constraint")) {
    if (
      lower.includes("club_memberships") ||
      lower.includes("club_memberships_pkey")
    ) {
      return "This student is already a member of this club.";
    }
    if (
      lower.includes("club_reapp") ||
      lower.includes("club_reapplication")
    ) {
      return "A re-application for this club is already in progress.";
    }
    if (lower.includes("slug") || lower.includes("clubs_slug")) {
      return "That club slug is already taken. Choose a different slug.";
    }
    if (lower.includes("name")) {
      return CLUB_NAME_TAKEN_MESSAGE;
    }
    return "That value is already in use. Please choose another.";
  }

  if (lower.includes("a re-application for this club is already in progress")) {
    return "A re-application for this club is already in progress.";
  }

  if (lower.includes("a club with that name already exists")) {
    return CLUB_NAME_TAKEN_MESSAGE;
  }

  if (
    lower.includes("approve_club_registration_request") &&
    (lower.includes("could not find") ||
      lower.includes("does not exist") ||
      lower.includes("function") ||
      lower.includes("404"))
  ) {
    return "Club approval is unavailable. The approval function is missing on the server.";
  }

  if (
    lower.includes("only an active club owner") ||
    lower.includes("club details can only be edited while") ||
    lower.includes("officially active") ||
    lower.includes("archived clubs cannot")
  ) {
    return message;
  }

  if (lower.includes("only sac or site administrators") ||
    lower.includes("only sac administrators") ||
    lower.includes("only a club owner") ||
    lower.includes("permission denied") ||
    lower.includes("42501") ||
    lower.includes("row-level security") ||
    lower.includes("rls")
  ) {
    return SIGN_IN_TO_SEE_MESSAGE;
  }

  if (
    lower.includes("create_announcement") ||
    lower.includes("edit_announcement") ||
    lower.includes("review_announcement") ||
    lower.includes("archive_announcement")
  ) {
    if (
      lower.includes("could not find") ||
      lower.includes("does not exist") ||
      lower.includes("pgrst202")
    ) {
      return "Announcement workflow is unavailable. A required database function is missing.";
    }
  }

  if (lower.includes("too many submissions")) {
    return "Too many submissions. Please wait and try again.";
  }

  if (lower.includes("failed to fetch") || lower.includes("network")) {
    return "Network error. Check your connection and try again.";
  }

  return message || fallback;
}

export function logServiceError(context, error) {
  if (import.meta.env.DEV) {
    console.error(`[${context}]`, error);
  }
}
