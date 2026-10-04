import { safeExternalHref } from "../../utils/urls";

export function SafeExternalLink({
  href,
  className,
  children,
  fallback = null,
}) {
  const safe = safeExternalHref(href);
  if (!safe) return fallback;
  return (
    <a
      className={className}
      href={safe}
      target="_blank"
      rel="noopener noreferrer"
    >
      {children}
    </a>
  );
}
