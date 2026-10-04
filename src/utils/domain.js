export const ALLOWED_EMAIL_DOMAIN = "pdsb.net";

export const ENFORCE_PDSB_EMAIL_DOMAIN = true;

export function getEmailDomain(email) {
  return email?.trim().toLowerCase().split("@").pop() ?? "";
}

export function isAllowedEmailDomain(email) {
  if (!ENFORCE_PDSB_EMAIL_DOMAIN) {
    return Boolean(email?.trim());
  }

  return getEmailDomain(email) === ALLOWED_EMAIL_DOMAIN;
}

/** Student number from the PDSB email local-part (leading digits). */
export function getStudentNumberFromEmail(email) {
  const local = String(email || "")
    .trim()
    .toLowerCase()
    .split("@")[0];
  if (!local) return "";
  const match = local.match(/^(\d+)/);
  return match?.[1] || "";
}
