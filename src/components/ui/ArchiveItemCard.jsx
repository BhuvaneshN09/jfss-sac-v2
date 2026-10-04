import { Link } from "react-router-dom";
import { formatDate } from "../../utils/format";
import { toSameOriginSupabaseUrl } from "../../utils/proxiedSupabaseUrl";

function truncateText(text, maxLength = 180) {
  const source = String(text || "")
    .trim()
    .replace(/\s+/g, " ");
  if (!source) return "";
  if (source.length <= maxLength) return source;
  return `${source.slice(0, maxLength - 1).trimEnd()}…`;
}

/**
 * Homepage-style archive card: title, truncated description, archived date,
 * optional image, and an “Open in more detail” action.
 */
export function ArchiveItemCard({
  title,
  description,
  archivedAt,
  imageUrl,
  detailTo,
  detailLabel = "Open in more detail",
}) {
  const excerpt = truncateText(description, 180);
  const mediaUrl = toSameOriginSupabaseUrl(imageUrl);

  return (
    <article className="announcement-card">
      {mediaUrl ? (
        <img src={mediaUrl} alt="" className="announcement-card__image" />
      ) : (
        <div
          className="announcement-card__image announcement-card__image--fallback"
          aria-hidden="true"
        />
      )}

      <div className="announcement-card__body">
        <div className="announcement-card__header">
          <h3 className="announcement-card__title">
            {detailTo ? (
              <Link to={detailTo}>{title}</Link>
            ) : (
              title
            )}
          </h3>
          <time
            className="announcement-card__date"
            dateTime={archivedAt || undefined}
          >
            {archivedAt ? formatDate(archivedAt) : "Unknown date"}
          </time>
        </div>

        {excerpt ? (
          <p className="announcement-card__excerpt">{excerpt}</p>
        ) : (
          <p className="announcement-card__excerpt muted">No description.</p>
        )}

        {detailTo ? (
          <div className="button-row button-row--compact announcement-card__actions">
            <Link className="button button--secondary" to={detailTo}>
              {detailLabel}
            </Link>
          </div>
        ) : null}
      </div>
    </article>
  );
}
