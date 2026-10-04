/* eslint-disable react-hooks/set-state-in-effect */
import { useEffect, useState } from "react";
import { Spinner } from "./Spinner";
import { toSameOriginSupabaseUrl } from "../../utils/proxiedSupabaseUrl";
import { safeExternalHref } from "../../utils/urls";

function isImageMime(mimeType, filename = "") {
  const mime = String(mimeType || "").toLowerCase();
  if (mime.startsWith("image/")) return true;
  const name = String(filename || "").toLowerCase();
  return /\.(jpe?g|png|webp|gif|avif)$/i.test(name);
}

function isImagePath(path = "") {
  return /\.(jpe?g|png|webp|gif|avif)(?:\?|$)/i.test(String(path));
}

/**
 * Displays an uploaded/selected file.
 * Images render inline and open in a new tab when clicked.
 * Non-images keep a document open link.
 *
 * Provide either:
 * - `url` (already resolved), or
 * - `path` + `getSignedUrl(path)` to auto-load a signed URL.
 */
export function AttachmentPreview({
  url,
  path,
  getSignedUrl,
  mimeType,
  filename,
  alt = "Attachment preview",
  className = "",
}) {
  const [resolvedUrl, setResolvedUrl] = useState(url || "");
  const [loading, setLoading] = useState(
    Boolean(path) && !url && Boolean(getSignedUrl),
  );
  const [error, setError] = useState("");

  useEffect(() => {
    if (url) {
      setResolvedUrl(url);
      setLoading(false);
      setError("");
      return undefined;
    }

    if (!path || !getSignedUrl) {
      setResolvedUrl("");
      setLoading(false);
      return undefined;
    }

    let active = true;
    setLoading(true);
    setError("");

    getSignedUrl(path)
      .then((nextUrl) => {
        if (!active) return;
        setResolvedUrl(nextUrl || "");
        if (!nextUrl) setError("Preview unavailable.");
      })
      .catch(() => {
        if (!active) return;
        setResolvedUrl("");
        setError("Could not load preview.");
      })
      .finally(() => {
        if (active) setLoading(false);
      });

    return () => {
      active = false;
    };
  }, [url, path, getSignedUrl]);

  const showAsImage =
    isImageMime(mimeType, filename) ||
    isImagePath(filename) ||
    isImagePath(path) ||
    isImagePath(resolvedUrl);

  if (loading) {
    return (
      <div className={`attachment-preview ${className}`.trim()}>
        <Spinner size="sm" label="Loading preview" />
        <span className="muted">Loading preview…</span>
      </div>
    );
  }

  if (error) {
    return (
      <div className={`attachment-preview ${className}`.trim()}>
        <p className="muted">{error}</p>
      </div>
    );
  }

  const displayUrl = safeExternalHref(
    toSameOriginSupabaseUrl(resolvedUrl) || resolvedUrl,
  );

  if (!displayUrl) return null;

  if (showAsImage) {
    return (
      <a
        href={displayUrl}
        target="_blank"
        rel="noopener noreferrer"
        className={`attachment-preview attachment-preview__link ${className}`.trim()}
        title="Open image in a new tab"
      >
        <img
          src={displayUrl}
          alt={alt}
          className="attachment-preview__image"
        />
      </a>
    );
  }

  return (
    <div
      className={`attachment-preview attachment-preview--file ${className}`.trim()}
    >
      <a
        href={displayUrl}
        target="_blank"
        rel="noopener noreferrer"
        className="button button--secondary"
      >
        Open {filename || "document"}
      </a>
    </div>
  );
}
