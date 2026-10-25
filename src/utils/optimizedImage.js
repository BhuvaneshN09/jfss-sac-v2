/** Must stay in sync with images.sizes / qualities / localPatterns in vercel.json. */
export const OPTIMIZED_LOGO_WIDTH = 256;
export const OPTIMIZED_PHOTO_WIDTH = 1080;
const OPTIMIZED_IMAGE_QUALITY = 75;
const OPTIMIZABLE_SOURCE_PATH =
  /^\/api\/x\/f\/v1\/object\/(public|authenticated)\/(club-logos|club-event-photos|athlete-photos)\/.+$/;

/**
 * Same-origin Vercel Image Optimization URL for a public storage image, or
 * null when the source cannot be optimized (dev server, signed URLs,
 * static assets, other origins).
 */
export function toOptimizedImageUrl(
  src,
  width,
  {
    enabled = import.meta.env.PROD,
    origin = globalThis.location?.origin,
  } = {},
) {
  if (!enabled || !origin || typeof src !== "string" || !src.trim()) {
    return null;
  }

  let parsed;
  try {
    parsed = new URL(src, origin);
  } catch {
    return null;
  }

  if (parsed.origin !== new URL(origin).origin || parsed.search) return null;
  if (!OPTIMIZABLE_SOURCE_PATH.test(parsed.pathname)) return null;

  const params = new URLSearchParams({
    url: parsed.pathname,
    w: String(width),
    q: String(OPTIMIZED_IMAGE_QUALITY),
  });
  return `/_vercel/image?${params.toString()}`;
}
