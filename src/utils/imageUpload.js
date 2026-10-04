/** Stay under Vercel function body limits (4.5 MB legacy, plus headers). */
export const PROXY_SAFE_IMAGE_MAX_BYTES = Math.floor(3.5 * 1024 * 1024);

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

function canvasToJpegBlob(canvas, quality) {
  return new Promise((resolve, reject) => {
    canvas.toBlob(
      (blob) => {
        if (!blob) {
          reject(new Error("Could not compress this image."));
          return;
        }
        resolve(blob);
      },
      "image/jpeg",
      quality,
    );
  });
}

function fileFromBlob(blob, originalName) {
  return new File([blob], replaceExtension(originalName, "jpg"), {
    type: "image/jpeg",
    lastModified: Date.now(),
  });
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
