import { createClient } from "@supabase/supabase-js";
import { rewriteBrowserGatewayUrl } from "./supabaseGateway";
import {
  getBrowserSupabaseUrl,
  SUPABASE_AUTH_STORAGE_KEY,
  SUPABASE_BROWSER_API_KEY,
} from "./supabaseConfig";

const SUPABASE_REQUEST_TIMEOUT_MS = 60000;

function mergeAbortSignals(left, right) {
  if (typeof AbortSignal.any === "function") {
    return AbortSignal.any([left, right]);
  }
  return right;
}

function rewriteFetchInput(input) {
  const origin = globalThis.location?.origin;
  if (typeof input === "string") {
    return rewriteBrowserGatewayUrl(input, origin);
  }
  if (input instanceof Request) {
    const rewritten = rewriteBrowserGatewayUrl(input.url, origin);
    if (rewritten === input.url) {
      return input;
    }
    return new Request(rewritten, input);
  }
  return input;
}

function scrubClientHeaders(headers) {
  headers.delete("apikey");
  headers.delete("x-client-info");
  headers.delete("x-supabase-api-version");

  const authorization = headers.get("Authorization");
  if (authorization) {
    const token = authorization.replace(/^Bearer\s+/i, "");
    if (
      token === SUPABASE_BROWSER_API_KEY ||
      token.startsWith("sb_publishable_") ||
      token.startsWith("sb_secret_")
    ) {
      headers.delete("Authorization");
    }
  }
}

function fetchWithTimeout(input, init = {}) {
  const timeoutController = new AbortController();
  const timeoutId = globalThis.setTimeout(
    () => timeoutController.abort(),
    SUPABASE_REQUEST_TIMEOUT_MS,
  );
  const signal = init.signal
    ? mergeAbortSignals(init.signal, timeoutController.signal)
    : timeoutController.signal;

  const headers = new Headers(init.headers ?? {});
  scrubClientHeaders(headers);

  return fetch(rewriteFetchInput(input), { ...init, headers, signal }).finally(
    () => {
      globalThis.clearTimeout(timeoutId);
    },
  );
}

export const supabase = createClient(
  getBrowserSupabaseUrl(),
  SUPABASE_BROWSER_API_KEY,
  {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: false,
      storageKey: SUPABASE_AUTH_STORAGE_KEY,
    },
    global: {
      fetch: fetchWithTimeout,
    },
  },
);
