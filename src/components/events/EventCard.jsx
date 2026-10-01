import { useState } from "react";

const DESCRIPTION_PREVIEW_LENGTH = 240;

export function EventCard({ event }) {
  const [expanded, setExpanded] = useState(false);
  const title = event.title || event.event_name;
  const date = event.date || event.event_date;
  const description = event.description || event.event_description || "";
  const photo = event.photo || event.photo_url;
  const clubNames =
    event.clubNames || [event.clubName || event.clubs?.name].filter(Boolean);
  const shouldTruncate = description.length > DESCRIPTION_PREVIEW_LENGTH;
  const preview = shouldTruncate
    ? `${description.slice(0, DESCRIPTION_PREVIEW_LENGTH).trimEnd()}…`
    : description;

  return (
    <div className="event-card">
      <div className="event-card__photo">
        {photo ? (
          <img src={photo} alt={title} />
        ) : (
          <div className="event-card__photo-placeholder">Photo coming soon</div>
        )}
      </div>
      <div className="event-card__content">
        <p className="event-card__date">{date}</p>
        <h3 className="event-card__title">{title}</h3>
        {clubNames.map((clubName) => (
          <p className="event-card__club" key={clubName}>
            {clubName}
          </p>
        ))}
        <p className="event-card__description">
          {expanded || !shouldTruncate ? description : preview}
        </p>
        {shouldTruncate ? (
          <button
            type="button"
            className="event-card__more"
            aria-expanded={expanded}
            onClick={() => setExpanded((isExpanded) => !isExpanded)}
          >
            {expanded ? "Show less" : "More"}
          </button>
        ) : null}
      </div>
    </div>
  );
}
