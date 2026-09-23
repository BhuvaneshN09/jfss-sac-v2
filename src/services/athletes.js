import { supabase } from "../lib/supabase";
import { getErrorMessage, logServiceError } from "../utils/errors";
import { assertFileMatchesDeclaredType } from "../utils/fileMagic";
import { prepareImageFileForUpload } from "../utils/imageUpload";
import { toSameOriginSupabaseUrl } from "../utils/proxiedSupabaseUrl";

export const ATHLETE_PHOTOS_BUCKET = "athlete-photos";
export const ATHLETE_PHOTO_MAX_BYTES = 10 * 1024 * 1024;
export const ATHLETE_PHOTO_ALLOWED_TYPES = [
  "image/jpeg",
  "image/png",
  "image/webp",
];
export const ATHLETE_EDITOR_EMAILS = [
  "778130@pdsb.net",
  "845945@pdsb.net",
  "783580@pdsb.net",
  "828897@pdsb.net",
  "814061@pdsb.net",
];

export function canManageAthletesEmail(email) {
  return ATHLETE_EDITOR_EMAILS.includes(String(email || "").toLowerCase());
}

const ATHLETE_FIELDS = `
  id,
  name,
  sport,
  photo_storage_path,
  display_order,
  created_by,
  created_at,
  updated_at
`;

export function validateAthletePhoto(file) {
  if (!file) return null;
  if (!ATHLETE_PHOTO_ALLOWED_TYPES.includes(file.type)) {
    return "Athlete photos must be JPEG, PNG, or WebP files.";
  }
  if (file.size > ATHLETE_PHOTO_MAX_BYTES) {
    return "Athlete photos must be 10 MB or smaller.";
  }
  return null;
}

function extensionForMime(mime) {
  if (mime === "image/png") return "png";
  if (mime === "image/webp") return "webp";
  return "jpg";
}

function buildAthletePhotoPath(userId, file) {
  return `athlete-photos/${userId}/${crypto.randomUUID()}.${extensionForMime(file.type)}`;
}

export function getAthletePhotoUrl(path) {
  if (!path) return null;
  const { data } = supabase.storage
    .from(ATHLETE_PHOTOS_BUCKET)
    .getPublicUrl(path);
  return toSameOriginSupabaseUrl(data?.publicUrl) || null;
}

export async function getAthletesOfTheMonth() {
  const { data, error } = await supabase
    .from("athletes_of_the_month")
    .select(ATHLETE_FIELDS)
    .order("display_order", { ascending: true })
    .order("created_at", { ascending: true });

  if (error) {
    logServiceError("getAthletesOfTheMonth", error);
    throw new Error(
      getErrorMessage(error, "Could not load Athletes of the Month."),
    );
  }

  return data ?? [];
}

export async function createAthleteOfTheMonth({
  userId,
  name,
  sport,
  photoFile,
  displayOrder,
}) {
  const trimmedName = String(name || "").trim();
  const trimmedSport = String(sport || "").trim();

  if (!trimmedName) throw new Error("Athlete name is required.");
  if (!trimmedSport) throw new Error("Sport is required.");

  const photoError = validateAthletePhoto(photoFile);
  if (photoError) throw new Error(photoError);
  if (!userId) throw new Error("You must be signed in to add an athlete.");

  let photoStoragePath = null;
  if (photoFile) {
    await assertFileMatchesDeclaredType(photoFile, ATHLETE_PHOTO_ALLOWED_TYPES);
    const uploadFile = await prepareImageFileForUpload(photoFile);
    photoStoragePath = buildAthletePhotoPath(userId, uploadFile);
    const { error: uploadError } = await supabase.storage
      .from(ATHLETE_PHOTOS_BUCKET)
      .upload(photoStoragePath, uploadFile, {
        cacheControl: "3600",
        contentType: uploadFile.type,
        upsert: false,
      });

    if (uploadError) {
      logServiceError("uploadAthletePhoto", uploadError);
      throw new Error(
        getErrorMessage(uploadError, "Could not upload the athlete photo."),
      );
    }
  }

  const { data, error } = await supabase
    .from("athletes_of_the_month")
    .insert({
      name: trimmedName,
      sport: trimmedSport,
      photo_storage_path: photoStoragePath,
      display_order: Number.isInteger(displayOrder) ? displayOrder : 0,
      created_by: userId,
    })
    .select(ATHLETE_FIELDS)
    .single();

  if (error) {
    if (photoStoragePath) {
      await supabase.storage
        .from(ATHLETE_PHOTOS_BUCKET)
        .remove([photoStoragePath]);
    }
    logServiceError("createAthleteOfTheMonth", error);
    throw new Error(
      getErrorMessage(error, "Could not save the Athlete of the Month."),
    );
  }

  return data;
}

export async function deleteAthleteOfTheMonth(athlete) {
  const { error } = await supabase
    .from("athletes_of_the_month")
    .delete()
    .eq("id", athlete.id);

  if (error) {
    logServiceError("deleteAthleteOfTheMonth", error);
    throw new Error(
      getErrorMessage(error, "Could not remove the Athlete of the Month."),
    );
  }

  if (athlete.photo_storage_path) {
    const { error: photoError } = await supabase.storage
      .from(ATHLETE_PHOTOS_BUCKET)
      .remove([athlete.photo_storage_path]);
    if (photoError) logServiceError("deleteAthletePhoto", photoError);
  }
}
