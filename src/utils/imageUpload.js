/** Stay under Vercel function body limits (4.5 MB legacy, plus headers). */
export const PROXY_SAFE_IMAGE_MAX_BYTES = Math.floor(3.5 * 1024 * 1024);

/** Logos render at most ~120px wide; 512px covers high-DPI screens. */
export const CLUB_LOGO_MAX_EDGE = 512;
export const DISPLAY_PHOTO_MAX_EDGE = 1600;
const DISPLAY_IMAGE_KEEP_BYTES = 200 * 1024;

function replaceExtension(name, ext) {
  const base = String(name || "image").replace(/\.[^/.]+$/, "");
  return `${base || "image"}.${ext}`;
}

function canCompressImages() {
  return (
    typeof createImageBitmap === "function" &&
    typeof document !== "undefined" &&
    typeof document.createElement === "function"
  );
}

async function loadBitmap(file) {
  try {
    return await createImageBitmap(file, { imageOrientation: "from-image" });
  } catch {
    return createImageBitmap(file);
  }
}

function canvasToBlob(canvas, type, quality) {
  return new Promise((resolve, reject) => {
    canvas.toBlob(
      (blob) => {
        if (!blob) {
          reject(new Error("Could not compress this image."));
          return;
        }
        resolve(blob);
      },
      type,
      quality,
    );
  });
}

function canvasToJpegBlob(canvas, quality) {
  return canvasToBlob(canvas, "image/jpeg", quality);
}

function fileFromBlob(blob, originalName) {
  const isWebp = blob.type === "image/webp";
  return new File([blob], replaceExtension(originalName, isWebp ? "webp" : "jpg"), {
    type: isWebp ? "image/webp" : "image/jpeg",
    lastModified: Date.now(),
  });
}

/**
 * Shrinks public display images (logos, event and athlete photos) to the
 * pixel size the site actually renders. Every visitor downloads these, so
 * oversized originals directly drive storage egress.
 *
 * Encodes WebP to keep logo transparency; browsers without a WebP encoder
 * fall back to JPEG on a white background. Returns the original file when
 * it is already small or re-encoding would not help.
 */
export async function downscaleImageForDisplay(file, maxEdge) {
  if (!file || !String(file.type || "").startsWith("image/")) {
    return file;
  }
  if (!canCompressImages()) {
    return file;
  }

  let bitmap;
  try {
    bitmap = await loadBitmap(file);
  } catch {
    return file;
  }

  try {
    const longest = Math.max(bitmap.width, bitmap.height, 1);
    if (longest <= maxEdge && file.size <= DISPLAY_IMAGE_KEEP_BYTES) {
      return file;
    }

    const scale = Math.min(1, maxEdge / longest);
    const canvas = document.createElement("canvas");
    canvas.width = Math.max(1, Math.round(bitmap.width * scale));
    canvas.height = Math.max(1, Math.round(bitmap.height * scale));
    const ctx = canvas.getContext("2d");
    if (!ctx) return file;

    ctx.drawImage(bitmap, 0, 0, canvas.width, canvas.height);
    let blob = await canvasToBlob(canvas, "image/webp", 0.85);
    if (blob.type !== "image/webp") {
      ctx.globalCompositeOperation = "destination-over";
      ctx.fillStyle = "#ffffff";
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      blob = await canvasToJpegBlob(canvas, 0.85);
    }

    return blob.size < file.size ? fileFromBlob(blob, file.name) : file;
  } catch {
    return file;
  } finally {
    bitmap.close?.();
  }
}

/**
 * Re-encodes large images so storage uploads fit through the same-origin proxy.
 * Leaves small files and non-images unchanged.
 */
export async function prepareImageFileForUpload(
  file,
  maxBytes = PROXY_SAFE_IMAGE_MAX_BYTES,
) {
  if (!file || !String(file.type || "").startsWith("image/")) {
    return file;
  }
  if (file.size <= maxBytes) {
    return file;
  }
  if (!canCompressImages()) {
    return file;
  }

  const bitmap = await loadBitmap(file);
  try {
    const canvas = document.createElement("canvas");
    const ctx = canvas.getContext("2d");
    if (!ctx) return file;

    let maxEdge = Math.min(2048, Math.max(bitmap.width, bitmap.height, 1));
    let smallest = file;

    while (maxEdge >= 640) {
      const scale = maxEdge / Math.max(bitmap.width, bitmap.height, 1);
      canvas.width = Math.max(1, Math.round(bitmap.width * scale));
      canvas.height = Math.max(1, Math.round(bitmap.height * scale));
      ctx.fillStyle = "#ffffff";
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.drawImage(bitmap, 0, 0, canvas.width, canvas.height);

      for (const quality of [0.82, 0.7, 0.55]) {
        const blob = await canvasToJpegBlob(canvas, quality);
        if (blob.size < smallest.size) {
          smallest = blob;
        }
        if (blob.size <= maxBytes) {
          return fileFromBlob(blob, file.name);
        }
      }

      maxEdge = Math.round(maxEdge * 0.75);
    }

    if (smallest !== file && smallest.size < file.size) {
      return fileFromBlob(smallest, file.name);
    }

    return file;
  } finally {
    bitmap.close?.();
  }
}
