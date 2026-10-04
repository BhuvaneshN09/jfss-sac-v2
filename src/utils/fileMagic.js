const JPEG = (bytes) =>
  bytes.length >= 3 &&
  bytes[0] === 0xff &&
  bytes[1] === 0xd8 &&
  bytes[2] === 0xff;

const PNG = (bytes) =>
  bytes.length >= 8 &&
  bytes[0] === 0x89 &&
  bytes[1] === 0x50 &&
  bytes[2] === 0x4e &&
  bytes[3] === 0x47 &&
  bytes[4] === 0x0d &&
  bytes[5] === 0x0a &&
  bytes[6] === 0x1a &&
  bytes[7] === 0x0a;

const WEBP = (bytes) =>
  bytes.length >= 12 &&
  bytes[0] === 0x52 &&
  bytes[1] === 0x49 &&
  bytes[2] === 0x46 &&
  bytes[3] === 0x46 &&
  bytes[8] === 0x57 &&
  bytes[9] === 0x45 &&
  bytes[10] === 0x42 &&
  bytes[11] === 0x50;

const PDF = (bytes) =>
  bytes.length >= 5 &&
  bytes[0] === 0x25 &&
  bytes[1] === 0x50 &&
  bytes[2] === 0x44 &&
  bytes[3] === 0x46 &&
  bytes[4] === 0x2d;

const MAGIC_FOR_MIME = {
  "image/jpeg": JPEG,
  "image/png": PNG,
  "image/webp": WEBP,
  "application/pdf": PDF,
};

export async function fileMatchesDeclaredType(file, allowedMimeTypes) {
  if (!file || !allowedMimeTypes.includes(file.type)) return false;
  const checker = MAGIC_FOR_MIME[file.type];
  if (!checker) return false;
  const header = new Uint8Array(await file.slice(0, 12).arrayBuffer());
  return checker(header);
}

export async function assertFileMatchesDeclaredType(file, allowedMimeTypes) {
  const matches = await fileMatchesDeclaredType(file, allowedMimeTypes);
  if (!matches) {
    throw new Error(
      "That file’s contents do not match the selected type. Upload a real JPEG, PNG, WebP, or PDF.",
    );
  }
}
