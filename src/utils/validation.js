import { isAllowedApplicationUrl } from "./urls";

export function validateOwnerNames(value, { required = true } = {}) {
  const text = String(value ?? "").trim();
  if (!text) {
    return required ? "List the full name of every club owner." : null;
  }
  if (text.length < 2) {
    return "List the full name of every club owner.";
  }
  if (text.length > 1000) {
    return "Keep owner names to 1,000 characters or fewer.";
  }
  return null;
}

export function validateClubSlug(slug) {
  const normalized = String(slug ?? "").trim().toLowerCase();

  if (normalized.length < 2 || normalized.length > 100) {
    return "Slug must be between 2 and 100 characters.";
  }

  if (!/^[a-z0-9]+(-[a-z0-9]+)*$/.test(normalized)) {
    return "Slug may only use lowercase letters, numbers, and single hyphens.";
  }

  return null;
}

export function validateOptionalHttpsUrl(
  value,
  { previous, label = "link" } = {},
) {
  const text = String(value ?? "").trim();
  if (!text) return null;
  if (!isAllowedApplicationUrl(text, previous)) {
    return `Enter a valid https ${label}.`;
  }
  return null;
}
