import { SUPABASE_PROXY_PATH } from "../../api/_paths.js";

export {
  SUPABASE_PROJECT_REF,
  SUPABASE_PROXY_PATH,
} from "../../api/_paths.js";

export const SUPABASE_AUTH_STORAGE_KEY = "jfss-sac-session";
export const SUPABASE_BROWSER_API_KEY = "public";

export function getBrowserSupabaseUrl(origin) {
  const resolvedOrigin =
    origin ??
    (typeof globalThis !== "undefined" ? globalThis.location?.origin : "");

  if (!resolvedOrigin) {
    throw new Error("Missing browser origin for the same-origin API URL.");
  }

  return new URL(SUPABASE_PROXY_PATH, resolvedOrigin).href.replace(/\/$/, "");
}
