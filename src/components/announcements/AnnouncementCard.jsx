import { Link } from "react-router-dom";
import { AnnouncementStatusBadge } from "./AnnouncementStatusBadge";
import { announcementExcerpt } from "../../utils/announcementPermissions";
import { formatDate } from "../../utils/format";
import { formatDateOnly } from "../../utils/torontoDate";

function announcementDateLabel(announcement, showStatus) {
  if (showStatus) {
    return formatDate(
      announcement.created_at ||
        announcement.updated_at ||
        announcement.published_at,
    );
  }
  if (announcement.scheduled_posting_date) {
    return formatDateOnly(announcement.scheduled_posting_date);
  }
  return formatDate(
    announcement.published_at ||
      announcement.updated_at ||
      announcement.created_at,
  );
}

export function AnnouncementCard({
  announcement,
  showStatus = false,
  actions = null,
}) {
  const club = announcement.clubs;
  const excerpt = announcementExcerpt(announcement, 180);
  const dateLabel = announcementDateLabel(announcement, showStatus);

  return (
    <article className="announcement-card announcement-card--text-only">
      <div className="announcement-card__body">
        {showStatus ? (
          <div className="request-card__labels">
            <span className="submission-type announcement-card__type">
              Announcement request
            </span>
            <AnnouncementStatusBadge
              status={announcement.status}
              prefix="Status: "
            />
          </div>
        ) : null}
        <div className="announcement-card__header">
          <h2 className="announcement-card__title">
            {announcement.title}
          </h2>
          <time className="announcement-card__date" dateTime={
            (showStatus
              ? announcement.created_at
              : announcement.scheduled_posting_date ||
                announcement.published_at ||
                announcement.updated_at ||
                announcement.created_at) ||
            undefined
          }>
            {showStatus ? `Submitted ${dateLabel}` : dateLabel}
          </time>
        </div>

        {excerpt ? (
          <p className="announcement-card__excerpt">{excerpt}</p>
        ) : null}

        <p className="announcement-card__club">
          {club?.slug ? (
            <Link className="text-link" to={`/clubs/${club.slug}`}>
              {club.name}
            </Link>
          ) : club?.name ? (
            club.name
          ) : (
            "John Fraser SAC"
          )}
        </p>

        {actions ? (
          <div className="button-row button-row--compact announcement-card__actions">
            {actions}
          </div>
        ) : null}
      </div>
    </article>
  );
}
