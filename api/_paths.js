export const SUPABASE_PROJECT_REF = "nvpxsuafdcrobnackhnd";
export const SUPABASE_PROXY_PATH = "/api/x";
export const AUTH_SESSION_BROWSER_PATH = "/api/sf/go";
export const GATEWAY_PATH_QUERY = "_px";
export const SUPABASE_UPSTREAM_ORIGIN = `https://${SUPABASE_PROJECT_REF}.supabase.co`;

export const GRANT_TYPE_CODES = {
  id_token: "1",
  refresh_token: "2",
  password: "3",
  pkce: "4",
  web3: "5",
  sso: "6",
};

export const GRANT_CODE_TYPES = Object.fromEntries(
  Object.entries(GRANT_TYPE_CODES).map(([grantType, code]) => [code, grantType]),
);

export const ALLOWED_AUTH_GRANT_TYPES = new Set(["id_token", "refresh_token"]);

export function isAllowedAuthGrant(grantType) {
  return ALLOWED_AUTH_GRANT_TYPES.has(String(grantType || ""));
}

function fullyDecodePathname(pathname) {
  let current = String(pathname || "");
  for (let i = 0; i < 3; i += 1) {
    try {
      const next = decodeURIComponent(current);
      if (next === current) break;
      current = next;
    } catch {
      return null;
    }
  }
  return current;
}

function isBlockedUpstreamPath(pathname) {
  return (
    pathname === "/functions" ||
    pathname.startsWith("/functions/") ||
    pathname === "/realtime" ||
    pathname.startsWith("/realtime/") ||
    pathname === "/graphql" ||
    pathname.startsWith("/graphql/") ||
    pathname === "/auth/v1/admin" ||
    pathname.startsWith("/auth/v1/admin/")
  );
}

export function isAllowedUpstreamGatewayPath(pathname) {
  const decoded = fullyDecodePathname(pathname);
  if (!decoded) return false;

  const path = decoded.replace(/\\/g, "/").replace(/\/+/g, "/");
  if (!path.startsWith("/") || path.includes("..")) {
    return false;
  }

  const lower = path.toLowerCase();
  if (isBlockedUpstreamPath(lower)) {
    return false;
  }

  return (
    lower === "/rest/v1" ||
    lower.startsWith("/rest/v1/") ||
    lower === "/auth/v1" ||
    lower.startsWith("/auth/v1/") ||
    lower === "/storage/v1" ||
    lower.startsWith("/storage/v1/")
  );
}

const SERVICE_TO_ALIAS = {
  rest: "q",
  auth: "a",
  storage: "f",
  functions: "fn",
};

const ALIAS_TO_SERVICE = Object.fromEntries(
  Object.entries(SERVICE_TO_ALIAS).map(([service, alias]) => [alias, service]),
);

function parseUrl(input, origin) {
  try {
    return new URL(input, origin);
  } catch {
    return null;
  }
}

export function isAuthTokenPath(pathname) {
  return String(pathname || "").endsWith("/auth/v1/token");
}

export function rewriteBrowserAuthTokenUrl(input, origin) {
  const url = parseUrl(input, origin);
  if (!url || !isAuthTokenPath(url.pathname)) {
    return input;
  }

  const grantType = url.searchParams.get("grant_type");
  const proxied = new URL(AUTH_SESSION_BROWSER_PATH, url.origin);
  const code = grantType ? GRANT_TYPE_CODES[grantType] : undefined;

  if (code) {
    proxied.searchParams.set("g", code);
  } else if (grantType) {
    proxied.searchParams.set("g", grantType);
  }

  url.searchParams.forEach((value, key) => {
    if (key !== "grant_type" && key !== "g") {
      proxied.searchParams.set(key, value);
    }
  });

  return proxied.toString();
}

export function resolveGrantType(searchParams) {
  const code = searchParams.get("g");
  if (code && GRANT_CODE_TYPES[code]) {
    return GRANT_CODE_TYPES[code];
  }
  return searchParams.get("grant_type");
}

export function toUpstreamAuthTokenUrl(
  incomingUrl,
  upstreamOrigin = SUPABASE_UPSTREAM_ORIGIN,
) {
  const incoming = parseUrl(incomingUrl, upstreamOrigin);
  if (!incoming) {
    throw new Error("Invalid auth proxy URL.");
  }

  const dest = new URL("/auth/v1/token", upstreamOrigin);
  const grantType = resolveGrantType(incoming.searchParams);
  if (grantType) {
    dest.searchParams.set("grant_type", grantType);
  }

  incoming.searchParams.forEach((value, key) => {
    if (key !== "g" && key !== "grant_type") {
      dest.searchParams.set(key, value);
    }
  });

  return dest.toString();
}

export function toUpstreamAuthTokenPath(pathAndQuery) {
  const url = toUpstreamAuthTokenUrl(
    `https://proxy.local${pathAndQuery.startsWith("/") ? pathAndQuery : `/${pathAndQuery}`}`,
  );
  const parsed = new URL(url);
  return `${parsed.pathname}${parsed.search}`;
}

function replaceFirstSegment(pathname, from, to) {
  const prefix = `${SUPABASE_PROXY_PATH}/${from}`;
  if (pathname === prefix || pathname.startsWith(`${prefix}/`)) {
    return `${SUPABASE_PROXY_PATH}/${to}${pathname.slice(prefix.length)}`;
  }
  return pathname;
}

export function rewriteBrowserServiceAliases(input, origin) {
  const url = parseUrl(input, origin);
  if (!url) return input;

  let pathname = url.pathname;
  for (const [service, alias] of Object.entries(SERVICE_TO_ALIAS)) {
    pathname = replaceFirstSegment(pathname, service, alias);
  }
  if (pathname === url.pathname) return input;
  url.pathname = pathname;
  return url.toString();
}

export function rewriteBrowserGatewayUrl(input, origin) {
  return rewriteBrowserServiceAliases(
    rewriteBrowserAuthTokenUrl(input, origin),
    origin,
  );
}

function getHeader(headers, name) {
  if (!headers) return null;
  if (typeof headers.get === "function") {
    return headers.get(name);
  }
  return headers[name] ?? headers[name.toLowerCase()] ?? null;
}

function looksLikeGatewayPath(value) {
  return /^(q|a|f|fn|rest|auth|storage|functions)\/v1\//.test(
    String(value || ""),
  );
}

export function shouldDropGatewaySearchParam(key, value) {
  if (key === GATEWAY_PATH_QUERY || key === "") return true;
  if (String(key).includes("/v1/")) return true;
  return looksLikeGatewayPath(value);
}

export function stripGatewaySearchParams(url) {
  const dropKeys = [];
  url.searchParams.forEach((value, key) => {
    if (shouldDropGatewaySearchParam(key, value)) {
      dropKeys.push(key);
    }
  });
  for (const key of dropKeys) {
    url.searchParams.delete(key);
  }
  return url;
}

function copySearchParams(from, to) {
  stripGatewaySearchParams(from);
  to.search = "";
  from.searchParams.forEach((value, key) => {
    to.searchParams.append(key, value);
  });
}

export function resolveIncomingGatewayUrl(requestUrl, origin, headers) {
  const incoming = parseUrl(requestUrl, origin);
  if (!incoming) return requestUrl;

  const nested = incoming.searchParams.get(GATEWAY_PATH_QUERY);

  const hasProxyPath =
    incoming.pathname === SUPABASE_PROXY_PATH ||
    incoming.pathname.startsWith(`${SUPABASE_PROXY_PATH}/`);

  if (!hasProxyPath && nested) {
    incoming.pathname = `${SUPABASE_PROXY_PATH}/${String(nested).replace(/^\/+/, "")}`;
  } else if (!hasProxyPath) {
    const forwarded =
      getHeader(headers, "x-forwarded-uri") ||
      getHeader(headers, "x-original-uri");
    const forwardedUrl = forwarded
      ? parseUrl(forwarded, incoming.origin)
      : null;
    if (
      forwardedUrl &&
      (forwardedUrl.pathname === SUPABASE_PROXY_PATH ||
        forwardedUrl.pathname.startsWith(`${SUPABASE_PROXY_PATH}/`))
    ) {
      incoming.pathname = forwardedUrl.pathname;
    }
  }

  stripGatewaySearchParams(incoming);
  return incoming.toString();
}

export function toUpstreamGatewayUrl(
  incomingUrl,
  upstreamOrigin = SUPABASE_UPSTREAM_ORIGIN,
) {
  const incoming = parseUrl(incomingUrl, upstreamOrigin);
  if (!incoming) {
    throw new Error("Invalid API proxy URL.");
  }

  const nested = incoming.searchParams.get(GATEWAY_PATH_QUERY);
  const hasProxyPath =
    incoming.pathname === SUPABASE_PROXY_PATH ||
    incoming.pathname.startsWith(`${SUPABASE_PROXY_PATH}/`);
  if (!hasProxyPath && nested) {
    incoming.pathname = `${SUPABASE_PROXY_PATH}/${String(nested).replace(/^\/+/, "")}`;
  }

  let pathname = incoming.pathname;
  if (pathname === SUPABASE_PROXY_PATH) {
    pathname = "/";
  } else if (pathname.startsWith(`${SUPABASE_PROXY_PATH}/`)) {
    pathname = pathname.slice(SUPABASE_PROXY_PATH.length);
  }

  const segments = pathname.split("/").filter(Boolean);
  if (segments[0] && ALIAS_TO_SERVICE[segments[0]]) {
    segments[0] = ALIAS_TO_SERVICE[segments[0]];
  }

  const dest = new URL(upstreamOrigin);
  dest.pathname = `/${segments.join("/")}`;
  dest.hash = incoming.hash;
  copySearchParams(incoming, dest);
  return dest.toString();
}

export const config = { runtime: "edge" };

export function toBrowserProxyPath(upstreamPathname) {
  const raw = String(upstreamPathname || "");
  const path = raw.startsWith("/") ? raw : `/${raw}`;
  const segments = path.split("/").filter(Boolean);
  if (segments[0] && SERVICE_TO_ALIAS[segments[0]]) {
    segments[0] = SERVICE_TO_ALIAS[segments[0]];
  }
  return `${SUPABASE_PROXY_PATH}/${segments.join("/")}`;
}

export default function helperNotFound() {
  return new Response(null, { status: 404 });
}

