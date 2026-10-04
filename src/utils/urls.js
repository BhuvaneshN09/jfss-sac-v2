const MAX_URL_LENGTH = 2000;

function hostnameIsPrivateOrLocal(hostname) {
  const host = String(hostname || "")
    .toLowerCase()
    .replace(/\.$/, "")
    .replace(/^\[|\]$/g, "");

  if (host === "localhost" || host.endsWith(".localhost") || host === "::1") {
    return true;
  }

  const ipv4 = host.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
  if (!ipv4) return false;

  const octets = ipv4.slice(1).map(Number);
  if (octets.some((part) => part > 255)) return true;
  const [a, b] = octets;
  if (a === 10 || a === 127 || a === 0) return true;
  if (a === 192 && b === 168) return true;
  if (a === 172 && b >= 16 && b <= 31) return true;
  if (a === 169 && b === 254) return true;
  return false;
}

function parseHttpUrl(value, { httpsOnly }) {
  const text = String(value ?? "").trim();
  if (!text || text.length > MAX_URL_LENGTH || /\s/.test(text)) {
    return null;
  }

  let url;
  try {
    url = new URL(text);
  } catch {
    return null;
  }

  if (httpsOnly) {
    if (url.protocol !== "https:") return null;
  } else if (url.protocol !== "https:" && url.protocol !== "http:") {
    return null;
  }

  if (url.username || url.password) return null;
  if (!url.hostname || url.hostname.includes("..")) return null;
  if (hostnameIsPrivateOrLocal(url.hostname)) return null;
  return url;
}

function isSafeSameOriginPath(value) {
  const text = String(value ?? "").trim();
  if (!text.startsWith("/") || text.startsWith("//")) return false;
  if (text.includes("\\") || text.includes("://")) return false;
  const pathOnly = text.split(/[?#]/, 1)[0];
  return !pathOnly.split("/").includes("..");
}

/** Allowed for newly saved application links. */
export function isSafeHttpsUrl(value) {
  return Boolean(parseHttpUrl(value, { httpsOnly: true }));
}

/**
 * Allowed for rendering existing http(s) links, same-origin paths, and blob
 * previews. Blocks javascript:/data: hrefs.
 */
export function isSafeExternalHref(value) {
  const text = String(value ?? "").trim();
  if (!text || text.length > MAX_URL_LENGTH) return false;
  if (text.startsWith("blob:")) {
    try {
      return new URL(text).protocol === "blob:";
    } catch {
      return false;
    }
  }
  if (isSafeSameOriginPath(text)) return true;
  return Boolean(parseHttpUrl(text, { httpsOnly: false }));
}

export function safeExternalHref(value) {
  const text = String(value ?? "").trim();
  return isSafeExternalHref(text) ? text : null;
}

/** Existing unchanged http(s) links may stay; new/changed values must be https. */
export function isAllowedApplicationUrl(value, previousValue) {
  const trimmed = String(value ?? "").trim();
  if (!trimmed) return true;
  if (
    previousValue != null &&
    trimmed === String(previousValue).trim() &&
    isSafeExternalHref(trimmed)
  ) {
    return true;
  }
  return isSafeHttpsUrl(trimmed);
}
