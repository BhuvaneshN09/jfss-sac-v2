import { CLUB_LOGOS_BUCKET } from "../config/clubApplications";
import {
  toAuthenticatedStorageObjectUrl,
  toSameOriginSupabaseUrl,
} from "./proxiedSupabaseUrl";
import { isSafeExternalHref } from "./urls";

function rejectUnsafeLogoValue(trimmed) {
  return (
    trimmed.startsWith("data:") ||
    /^javascript:/i.test(trimmed) ||
    /^http:\/\//i.test(trimmed)
  );
}

/**
 * club.logo_url may be a full URL or a club-logos storage path
 * (e.g. after reapplication approval).
 *
 * Public pages use a stable authenticated-object URL so Vercel can CDN-cache
 * the image bytes. Unpublished logos still need resolveSignedClubLogoUrl
 * from the club logos service.
 */
export function resolveClubLogoUrl(logoUrl, origin) {
  if (!logoUrl || typeof logoUrl !== "string") return null;

  const trimmed = logoUrl.trim();
  if (!trimmed || rejectUnsafeLogoValue(trimmed)) return null;

  if (/^https:\/\//i.test(trimmed)) {
    const proxied = toSameOriginSupabaseUrl(trimmed, origin);
    const resolved = typeof proxied === "string" ? proxied : trimmed;
    return isSafeExternalHref(resolved) ? resolved : null;
  }

  const stable = toAuthenticatedStorageObjectUrl(CLUB_LOGOS_BUCKET, trimmed);
  return isSafeExternalHref(stable) ? stable : null;
}
