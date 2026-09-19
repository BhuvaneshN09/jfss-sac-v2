import {
  isAllowedUpstreamGatewayPath,
  stripGatewaySearchParams,
} from "./_paths.js";
import {
  getPublicCdnCacheControl,
  hasUserAccessToken,
  withPublicCdnCache,
} from "./_cachePublic.js";

export const config = { runtime: "edge" };

const ALLOWED_METHODS = new Set([
  "GET",
  "HEAD",
  "POST",
  "PUT",
  "PATCH",
  "DELETE",
  "OPTIONS",
]);

function jsonError(status, message) {
  return new Response(JSON.stringify({ message }), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}

const REQUEST_HEADER_ALLOWLIST = [
  "accept",
  "accept-language",
  "authorization",
  "content-type",
  "prefer",
  "x-supabase-api-version",
];

function getServerPublishableKey() {
  const env = globalThis.process?.env ?? {};
  return env.SUPABASE_PUBLISHABLE_KEY || env.VITE_SUPABASE_PUBLISHABLE_KEY || "";
}

function shouldDropResponseHeader(name, value) {
  const header = name.toLowerCase();
  if (
    header.startsWith("sb-") ||
    header.startsWith("cf-") ||
    header.startsWith("x-supabase") ||
    header.startsWith("x-envoy")
  ) {
    return true;
  }
  if (
    header === "server" ||
    header === "alt-svc" ||
    header.startsWith("access-control-")
  ) {
    return true;
  }
  if (header === "set-cookie" && /supabase\.co/i.test(String(value || ""))) {
    return true;
  }
  return false;
}

export function sanitizeUpstreamResponse(upstream) {
  const headers = new Headers();
  upstream.headers.forEach((value, name) => {
    if (shouldDropResponseHeader(name, value)) return;
    headers.append(name, value);
  });

  return new Response(upstream.body, {
    status: upstream.status,
    statusText: upstream.statusText,
    headers,
  });
}

export function buildUpstreamHeaders(request) {
  const headers = new Headers();
  for (const name of REQUEST_HEADER_ALLOWLIST) {
    const value = request.headers.get(name);
    if (value) headers.set(name, value);
  }

  const authorization = headers.get("Authorization");
  if (authorization) {
    const token = authorization.replace(/^Bearer\s+/i, "");
    if (
      token === "public" ||
      token.startsWith("sb_publishable_") ||
      token.startsWith("sb_secret_")
    ) {
      headers.delete("Authorization");
    }
  }

  const apiKey = getServerPublishableKey();
  if (apiKey) {
    headers.set("apikey", apiKey);
    if (!headers.has("x-supabase-api-version")) {
      headers.set("x-supabase-api-version", "2024-01-01");
    }
  }

  return headers;
}

export async function proxySupabaseRequest(request, destUrl) {
  if (!ALLOWED_METHODS.has(request.method)) {
    return new Response(null, { status: 405 });
  }

  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204 });
  }

  const headers = buildUpstreamHeaders(request);
  if (!headers.get("apikey")) {
    return jsonError(503, "Service unavailable.");
  }

  let dest;
  try {
    dest = stripGatewaySearchParams(new URL(destUrl));
  } catch {
    return jsonError(400, "Invalid request.");
  }

  if (!isAllowedUpstreamGatewayPath(dest.pathname)) {
    return jsonError(404, "Not found.");
  }

  const init = {
    method: request.method,
    headers,
    redirect: "manual",
  };
  if (request.method !== "GET" && request.method !== "HEAD") {
    init.body = request.body;
    init.duplex = "half";
  }

  const upstream = await fetch(dest.toString(), init);
  const sanitized = sanitizeUpstreamResponse(upstream);
  const cacheControl = getPublicCdnCacheControl({
    method: request.method,
    pathname: dest.pathname,
    status: sanitized.status,
    hasUserToken: hasUserAccessToken(request),
    hasRange: Boolean(request.headers.get("range")),
  });
  return withPublicCdnCache(sanitized, cacheControl);
}

export default function helperNotFound() {
  return new Response(null, { status: 404 });
}
