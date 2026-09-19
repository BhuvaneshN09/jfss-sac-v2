import { supabase } from "../lib/supabase";
import {
  CLUB_LOGOS_BUCKET,
  REAPP_LOGO_ALLOWED_TYPES,
  REAPP_LOGO_MAX_BYTES,
} from "../config/clubApplications";
import { getErrorMessage, logServiceError } from "../utils/errors";
import { assertFileMatchesDeclaredType } from "../utils/fileMagic";
import { resolveClubLogoUrl } from "../utils/clubMedia";
import { toSameOriginSupabaseUrl } from "../utils/proxiedSupabaseUrl";

function extensionForMime(mime) {
  if (mime === "image/png") return "png";
  if (mime === "image/webp") return "webp";
  return "jpg";
}

export function validateClubLogoFile(file) {
  if (!file) {
    return "Choose a club logo image.";
  }

  if (!REAPP_LOGO_ALLOWED_TYPES.includes(file.type)) {
    return "Logo must be JPEG, PNG, or WebP.";
  }

  if (file.size > REAPP_LOGO_MAX_BYTES) {
    return "Logo must be 5 MB or smaller.";
  }

  return null;
}

export function buildClubProfileLogoPath({ userId, clubId, file }) {
  const ext = extensionForMime(file.type);
  return `club-profile-logos/${userId}/${clubId}/${crypto.randomUUID()}.${ext}`;
}

/**
 * Upload a club logo for an owned club. Returns the storage object path
 * (stored in clubs.logo_url; resolve with resolveClubLogoUrl for display).
 * Path: club-profile-logos/{userId}/{clubId}/{uuid}.{ext}
 */
export async function uploadClubLogo({ userId, clubId, file }) {
  const validationError = validateClubLogoFile(file);
  if (validationError) {
    throw new Error(validationError);
  }

  if (!userId || !clubId) {
    throw new Error("Missing upload destination for club logo.");
  }

  await assertFileMatchesDeclaredType(file, REAPP_LOGO_ALLOWED_TYPES);

  const path = buildClubProfileLogoPath({ userId, clubId, file });

  const { error } = await supabase.storage
    .from(CLUB_LOGOS_BUCKET)
    .upload(path, file, {
      cacheControl: "3600",
      upsert: false,
      contentType: file.type,
    });

  if (error) {
    logServiceError("uploadClubLogo", error);
    throw new Error(
      getErrorMessage(
        error,
        "Could not upload the club logo.",
      ),
    );
  }

  return path;
}

export async function removeOldClubProfileLogos({
  userId,
  clubId,
  keepPath,
}) {
  if (!userId || !clubId) return;

  const prefix = `club-profile-logos/${userId}/${clubId}`;
  const { data, error } = await supabase.storage
    .from(CLUB_LOGOS_BUCKET)
    .list(prefix);

  if (error) {
    logServiceError("listOldClubProfileLogos", error);
    return;
  }

  const paths = (data || [])
    .map((file) => `${prefix}/${file.name}`)
    .filter((path) => path !== keepPath);
  if (paths.length === 0) return;

  const { error: removeError } = await supabase.storage
    .from(CLUB_LOGOS_BUCKET)
    .remove(paths);
  if (removeError) logServiceError("removeOldClubProfileLogos", removeError);
}

export function buildNewClubApplicationLogoPath({ userId, requestId, file }) {
  const ext = extensionForMime(file.type);
  return `new-club-logos/${userId}/${requestId}/${crypto.randomUUID()}.${ext}`;
}

export async function uploadNewClubLogo({ userId, requestId, file }) {
  const validationError = validateClubLogoFile(file);
  if (validationError) {
    throw new Error(validationError);
  }

  if (!userId || !requestId) {
    throw new Error("Missing upload destination for club logo.");
  }

  await assertFileMatchesDeclaredType(file, REAPP_LOGO_ALLOWED_TYPES);

  const path = buildNewClubApplicationLogoPath({ userId, requestId, file });
  const { error } = await supabase.storage
    .from(CLUB_LOGOS_BUCKET)
    .upload(path, file, {
      cacheControl: "3600",
      upsert: false,
      contentType: file.type,
    });

  if (error) {
    logServiceError("uploadNewClubLogo", error);
    throw new Error(
      getErrorMessage(error, "Could not upload the club logo."),
    );
  }

  return path;
}

export async function deleteClubLogo(path) {
  if (!path) return;

  const { error } = await supabase.storage
    .from(CLUB_LOGOS_BUCKET)
    .remove([path]);

  if (error) {
    logServiceError("deleteClubLogo", error);
  }
}

/** Signed URL for unpublished logos (admin review). Do not use on public pages. */
export async function resolveSignedClubLogoUrl(logoUrl) {
  if (!logoUrl || typeof logoUrl !== "string") return null;

  const trimmed = logoUrl.trim();
  if (!trimmed) return null;

  if (/^https:\/\//i.test(trimmed)) {
    return resolveClubLogoUrl(trimmed);
  }

  const { data, error } = await supabase.storage
    .from(CLUB_LOGOS_BUCKET)
    .createSignedUrl(trimmed, 60 * 60);

  return error ? null : toSameOriginSupabaseUrl(data?.signedUrl) || null;
}
