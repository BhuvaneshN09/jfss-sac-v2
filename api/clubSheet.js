import { SUPABASE_UPSTREAM_ORIGIN } from "./_paths.js";

export const config = { runtime: "edge" };

const JSON_HEADERS = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store",
};

function getEnv(name) {
  return String(globalThis.process?.env?.[name] ?? "");
}

function json(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: JSON_HEADERS,
  });
}

function providedSyncKey(request) {
  const headerKey = request.headers.get("x-club-sheet-key");
  if (headerKey) return headerKey.trim();

  const authorization = request.headers.get("authorization") || "";
  const bearer = authorization.match(/^Bearer\s+(.+)$/i);
  return bearer ? bearer[1].trim() : "";
}

function keysMatch(provided, expected) {
  if (!provided || !expected) return false;
  const left = provided;
  const right = expected;
  const length = Math.max(left.length, right.length);
  let mismatch = left.length === right.length ? 0 : 1;
  for (let index = 0; index < length; index += 1) {
    mismatch |= (left.charCodeAt(index) || 0) ^ (right.charCodeAt(index) || 0);
  }
  return mismatch === 0;
}

export default async function handler(request) {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204 });
  }

  if (request.method !== "GET") {
    return json(405, { message: "Method not allowed." });
  }

  const expectedKey = getEnv("CLUB_SHEET_SYNC_KEY");
  const serviceRole =
    getEnv("SUPABASE_SERVICE_ROLE_KEY") || getEnv("SUPABASE_SECRET_KEY");

  if (!expectedKey || !serviceRole) {
    return json(503, { message: "Club sheet sync is not configured." });
  }

  if (!keysMatch(providedSyncKey(request), expectedKey)) {
    return json(401, { message: "Unauthorized." });
  }

  const upstream = await fetch(
    `${SUPABASE_UPSTREAM_ORIGIN}/rest/v1/rpc/get_official_club_sheet`,
    {
      method: "POST",
      headers: {
        apikey: serviceRole,
        Authorization: `Bearer ${serviceRole}`,
        "Content-Type": "application/json",
        Prefer: "return=representation",
      },
      body: "{}",
    },
  );

  if (!upstream.ok) {
    return json(502, { message: "Could not load the official club list." });
  }

  const clubs = await upstream.json();
  return json(200, {
    generatedAt: new Date().toISOString(),
    clubs: Array.isArray(clubs) ? clubs : [],
  });
}
