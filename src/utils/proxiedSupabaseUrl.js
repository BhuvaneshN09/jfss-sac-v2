import {
  SUPABASE_PROJECT_REF,
  SUPABASE_PROXY_PATH,
} from "../lib/supabaseConfig";
import { toBrowserProxyPath } from "../lib/supabaseGateway";

function isAuthoritativeSupabaseHost(hostname) {
  const parts = String(hostname || "")
    .trim()
    .toLowerCase()
    .split(".");

  return (
    parts.length === 3 &&
    parts[0] === SUPABASE_PROJECT_REF &&
    parts[1] === "supabase" &&
    parts[2] === "co"
  );
}

function rewriteSameOriginProxyPath(pathname) {
  if (pathname === "/supabase" || pathname.startsWith("/supabase/")) {
    return toBrowserProxyPath(pathname.replace(/^\/supabase/, "") || "/");
  }
  if (
    pathname === SUPABASE_PROXY_PATH ||
    pathname.startsWith(`${SUPABASE_PROXY_PATH}/`)
  ) {
    return toBrowserProxyPath(pathname.slice(SUPABASE_PROXY_PATH.length) || "/");
  }
  return pathname;
}

/**
 * Rewrite this project's Storage/Auth/REST URLs onto the current origin's
 * bland API proxy. Leaves every other value alone.
 */
export function toSameOriginSupabaseUrl(value, origin) {
  if (value == null || typeof value !== "string") {
    return value;
  }

  const trimmed = value.trim();
  if (!trimmed) {
    return value;
  }

  let parsed;
  try {
    parsed = new URL(trimmed);
  } catch {
    return value;
  }

  const resolvedOrigin =
    origin ??
    (typeof globalThis !== "undefined" ? globalThis.location?.origin : "");

  if (!resolvedOrigin) {
    return value;
  }

  const sameOrigin = parsed.origin === new URL(resolvedOrigin).origin;
  if (!isAuthoritativeSupabaseHost(parsed.hostname) && !sameOrigin) {
    return value;
  }
  if (sameOrigin && rewriteSameOriginProxyPath(parsed.pathname) === parsed.pathname) {
    return value;
  }

  const proxied = new URL(resolvedOrigin);
  proxied.pathname = isAuthoritativeSupabaseHost(parsed.hostname)
    ? toBrowserProxyPath(parsed.pathname)
    : rewriteSameOriginProxyPath(parsed.pathname);
  proxied.search = parsed.search;
  proxied.hash = parsed.hash;
  return proxied.toString();
}

function encodeStorageObjectPath(objectPath) {
  return String(objectPath || "")
    .trim()
    .replace(/^\/+/, "")
    .split("/")
    .filter(Boolean)
    .map((segment) => encodeURIComponent(segment))
    .join("/");
}

/**
 * Stable same-origin URL for a private-bucket object that RLS already allows
 * anonymous readers to download. Used by <img> tags so every visitor shares
 * one cacheable URL instead of a unique signed URL.
 *
 * Returns a same-origin path (not an absolute URL) so localhost preview and
 * production both pass href safety checks.
 */
export function toAuthenticatedStorageObjectUrl(bucket, objectPath) {
  const encoded = encodeStorageObjectPath(objectPath);
  if (!bucket || !encoded || encoded.includes("..")) return null;
  return toBrowserProxyPath(
    `/storage/v1/object/authenticated/${bucket}/${encoded}`,
  );
}
