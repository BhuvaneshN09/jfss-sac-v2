const AUTH_RETURN_TO_KEY = "jfss_sac_auth_return_to";

export function normalizeAuthReturnPath(path) {
  const value = String(path || "").trim();
  if (!value) return null;
  if (!value.startsWith("/") || value.startsWith("//")) return null;
  if (value.includes("://") || value.includes("\\") || value.includes("\0")) {
    return null;
  }

  let decoded;
  try {
    decoded = decodeURIComponent(value);
  } catch {
    return null;
  }

  if (
    decoded.startsWith("//") ||
    decoded.includes("://") ||
    decoded.includes("\\")
  ) {
    return null;
  }

  const pathname = value.split(/[?#]/, 1)[0];
  if (pathname === "/login" || pathname.startsWith("/login/")) return null;
  return value;
}

export function rememberAuthReturnTo(path) {
  const normalized = normalizeAuthReturnPath(path);
  if (!normalized) return;
  try {
    sessionStorage.setItem(AUTH_RETURN_TO_KEY, normalized);
  } catch {
    // Ignore storage failures (private mode / quota).
  }
}

export function peekAuthReturnTo() {
  try {
    return normalizeAuthReturnPath(sessionStorage.getItem(AUTH_RETURN_TO_KEY));
  } catch {
    return null;
  }
}

export function consumeAuthReturnTo(fallback = null) {
  try {
    const value = sessionStorage.getItem(AUTH_RETURN_TO_KEY);
    sessionStorage.removeItem(AUTH_RETURN_TO_KEY);
    return (
      normalizeAuthReturnPath(value) || normalizeAuthReturnPath(fallback)
    );
  } catch {
    return normalizeAuthReturnPath(fallback);
  }
}
