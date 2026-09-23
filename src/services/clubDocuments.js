import { supabase } from "../lib/supabase";
import {
  CLUB_APPLICATION_DOCUMENTS_BUCKET,
  SIGNED_FORM_ALLOWED_TYPES,
  SIGNED_FORM_MAX_BYTES,
} from "../config/clubApplications";
import { getErrorMessage, logServiceError } from "../utils/errors";
import { assertFileMatchesDeclaredType } from "../utils/fileMagic";
import { prepareImageFileForUpload } from "../utils/imageUpload";
import { toSameOriginSupabaseUrl } from "../utils/proxiedSupabaseUrl";

function extensionForMime(mime) {
  if (mime === "image/png") return "png";
  if (mime === "image/webp") return "webp";
  return "jpg";
}

export function validateSignedFormFile(file) {
  if (!file) {
    return "Upload a clear image of the signed Teacher Supervisor Form.";
  }

  if (!SIGNED_FORM_ALLOWED_TYPES.includes(file.type)) {
    return "Upload a JPEG, PNG, or WebP image only.";
  }

  if (file.size > SIGNED_FORM_MAX_BYTES) {
    return "Signed-form images must be 10 MB or smaller.";
  }

  return null;
}

export function buildApplicationDocumentPath({
  folder,
  userId,
  submissionId,
  file,
}) {
  const safeExt = extensionForMime(file.type);
  const unique = crypto.randomUUID();
  return `${folder}/${userId}/${submissionId}/${unique}.${safeExt}`;
}

export async function uploadClubApplicationDocument({
  folder,
  userId,
  submissionId,
  file,
}) {
  const validationError = validateSignedFormFile(file);
  if (validationError) {
    throw new Error(validationError);
  }

  if (!userId || !submissionId) {
    throw new Error("Missing upload destination.");
  }

  await assertFileMatchesDeclaredType(file, SIGNED_FORM_ALLOWED_TYPES);

  const uploadFile = await prepareImageFileForUpload(file);
  const path = buildApplicationDocumentPath({
    folder,
    userId,
    submissionId,
    file: uploadFile,
  });

  const { error } = await supabase.storage
    .from(CLUB_APPLICATION_DOCUMENTS_BUCKET)
    .upload(path, uploadFile, {
      cacheControl: "3600",
      upsert: false,
      contentType: uploadFile.type,
    });

  if (error) {
    logServiceError("uploadClubApplicationDocument", error);
    throw new Error(
      getErrorMessage(error, "Could not upload the signed form image."),
    );
  }

  return path;
}

export async function deleteClubApplicationDocument(path) {
  if (!path) return;

  const { error } = await supabase.storage
    .from(CLUB_APPLICATION_DOCUMENTS_BUCKET)
    .remove([path]);

  if (error) {
    logServiceError("deleteClubApplicationDocument", error);
  }
}

export async function createSignedClubDocumentUrl(path, expiresIn = 60 * 10) {
  if (!path) {
    throw new Error("A storage path is required.");
  }

  const { data, error } = await supabase.storage
    .from(CLUB_APPLICATION_DOCUMENTS_BUCKET)
    .createSignedUrl(path, expiresIn);

  if (error) {
    logServiceError("createSignedClubDocumentUrl", error);
    throw new Error(
      getErrorMessage(error, "Could not open the signed form image."),
    );
  }

  return toSameOriginSupabaseUrl(data?.signedUrl) ?? null;
}
