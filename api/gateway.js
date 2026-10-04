import { Readable } from "node:stream";
import { pipeline } from "node:stream/promises";
import {
  resolveIncomingGatewayUrl,
  toUpstreamGatewayUrl,
} from "./_paths.js";
import { proxySupabaseRequest } from "./_forward.js";

// Node, not Edge: Edge rejects upload bodies around 1 MB with HTTP 413.
export const config = {
  runtime: "nodejs",
  maxDuration: 60,
  useWebApi: true,
};

function isWebRequest(value) {
  return Boolean(value && typeof value.headers?.get === "function");
}

function headerValue(value) {
  if (Array.isArray(value)) return value;
  return value == null ? [] : [value];
}

function nodeToWebRequest(req) {
  const host =
    req.headers["x-forwarded-host"] || req.headers.host || "localhost";
  const proto = req.headers["x-forwarded-proto"] || "https";
  const url = new URL(req.url || "/", `${proto}://${host}`);
  const headers = new Headers();

  for (const [name, value] of Object.entries(req.headers)) {
    if (name === "host" || value == null) continue;
    for (const item of headerValue(value)) {
      headers.append(name, item);
    }
  }

  const method = String(req.method || "GET").toUpperCase();
  const init = { method, headers };
  if (method !== "GET" && method !== "HEAD") {
    init.body = Readable.toWeb(req);
    init.duplex = "half";
  }
  return new Request(url, init);
}

async function sendWebResponse(res, response) {
  res.statusCode = response.status;
  const cookies = [];
  response.headers.forEach((value, name) => {
    if (name.toLowerCase() === "set-cookie") {
      cookies.push(value);
      return;
    }
    res.setHeader(name, value);
  });
  if (cookies.length === 1) {
    res.setHeader("set-cookie", cookies[0]);
  } else if (cookies.length > 1) {
    res.setHeader("set-cookie", cookies);
  }

  if (!response.body) {
    res.end();
    return;
  }
  await pipeline(Readable.fromWeb(response.body), res);
}

async function handleGateway(request) {
  return proxySupabaseRequest(
    request,
    toUpstreamGatewayUrl(
      resolveIncomingGatewayUrl(request.url, undefined, request.headers),
    ),
  );
}

export default async function handler(req, res) {
  const request = isWebRequest(req) ? req : nodeToWebRequest(req);
  const response = await handleGateway(request);
  if (res && typeof res.writeHead === "function") {
    await sendWebResponse(res, response);
    return;
  }
  return response;
}
