const DAY_SECONDS = 86400;
const WEEK_SECONDS = 604800;

const PUBLIC_READ_STORAGE_BUCKETS = new Set([
  "club-logos",
  "club-event-photos",
  "athlete-photos",
]);

function decodePathname(pathname) {
  const raw = String(pathname || "");
  try {
    return decodeURIComponent(raw);
  } catch {
    return raw;
  }
}

function restExact(path, resource) {
  return path === `/rest/v1/${resource}`;
}

function cacheControl({ maxAge, sMaxAge, swr }) {
  return `public, max-age=${maxAge}, s-maxage=${sMaxAge}, stale-while-revalidate=${swr}`;
}

/**
 * True when the browser sent a user JWT. Dummy publishable keys are ignored
 * because the gateway injects the real API key server-side.
 */
export function hasUserAccessToken(request) {
  const authorization =
    request?.headers?.get?.("authorization") ||
    request?.headers?.get?.("Authorization") ||
    "";
  const token = String(authorization)
    .replace(/^Bearer\s+/i, "")
    .trim();

  if (!token || token === "public") return false;
  if (token.startsWith("sb_publishable_") || token.startsWith("sb_secret_")) {
    return false;
  }
  return token.split(".").length === 3;
}

function sharedPublicCacheControl(path) {
  if (path.startsWith("/storage/v1/object/public/")) {
    return cacheControl({
      maxAge: 3600,
      sMaxAge: DAY_SECONDS,
      swr: WEEK_SECONDS,
    });
  }

  if (restExact(path, "public_active_clubs")) {
    return cacheControl({ maxAge: 0, sMaxAge: 120, swr: 300 });
  }
  if (restExact(path, "athletes_of_the_month")) {
    return cacheControl({ maxAge: 0, sMaxAge: 300, swr: 600 });
  }
  if (restExact(path, "rpc/get_public_club_events")) {
    return cacheControl({ maxAge: 0, sMaxAge: 120, swr: 300 });
  }
  if (restExact(path, "rpc/get_public_confirmed_promo_lunch_club_ids")) {
    return cacheControl({ maxAge: 0, sMaxAge: 120, swr: 300 });
  }
  if (restExact(path, "rpc/get_public_club_promo_lunch_confirmation")) {
    return cacheControl({ maxAge: 0, sMaxAge: 120, swr: 300 });
  }
  if (restExact(path, "rpc/get_current_club_school_year")) {
    return cacheControl({ maxAge: 0, sMaxAge: 3600, swr: DAY_SECONDS });
  }

  return null;
}

function anonymousOnlyCacheControl(path) {
  const authenticatedPrefix = "/storage/v1/object/authenticated/";
  if (path.startsWith(authenticatedPrefix)) {
    const rest = path.slice(authenticatedPrefix.length);
    const bucket = rest.split("/")[0];
    if (PUBLIC_READ_STORAGE_BUCKETS.has(bucket) && rest.includes("/")) {
      return cacheControl({
        maxAge: 3600,
        sMaxAge: DAY_SECONDS,
        swr: WEEK_SECONDS,
      });
    }
    return null;
  }

  if (restExact(path, "rpc/get_effective_school_day")) {
    return cacheControl({ maxAge: 0, sMaxAge: 60, swr: 120 });
  }
  if (restExact(path, "announcements")) {
    return cacheControl({ maxAge: 0, sMaxAge: 60, swr: 120 });
  }
  if (restExact(path, "clubs")) {
    return cacheControl({ maxAge: 0, sMaxAge: 120, swr: 300 });
  }

  return null;
}

/**
 * CDN cache policy for same-origin Supabase gateway responses.
 * Never returns a policy for auth, mutations, private documents, or
 * personalized REST reads.
 */
export function getPublicCdnCacheControl({
  method,
  pathname,
  status,
  hasUserToken,
  hasRange,
} = {}) {
  const verb = String(method || "").toUpperCase();
  if (verb !== "GET" && verb !== "HEAD") return null;
  if (Number(status) !== 200) return null;
  if (hasRange) return null;

  const path = decodePathname(pathname);
  const shared = sharedPublicCacheControl(path);
  if (shared) return shared;
  if (hasUserToken) return null;
  return anonymousOnlyCacheControl(path);
}

export function withPublicCdnCache(response, cacheControlValue) {
  if (!cacheControlValue || !response) return response;

  const headers = new Headers(response.headers);
  headers.delete("set-cookie");
  headers.set("Cache-Control", cacheControlValue);
  headers.set("CDN-Cache-Control", cacheControlValue);
  headers.set("Vercel-CDN-Cache-Control", cacheControlValue);

  const vary = headers.get("Vary");
  if (!vary) {
    headers.set("Vary", "Accept, Prefer");
  } else if (!/accept/i.test(vary)) {
    headers.set("Vary", `${vary}, Accept`);
  }

  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

export const config = { runtime: "edge" };

export default function helperNotFound() {
  return new Response(null, { status: 404 });
}
