import { useState } from "react";
import { toSameOriginSupabaseUrl } from "../../utils/proxiedSupabaseUrl";

const DESCRIPTION_PREVIEW_LENGTH = 240;

export function EventCard({ event }) {
  const [expanded, setExpanded] = useState(false);
  const title = event.title || event.event_name;
  const date = event.date || event.event_date;
  const description = event.description || event.event_description || "";
  const photo = toSameOriginSupabaseUrl(event.photo || event.photo_url);
  const clubName = event.clubName || event.clubs?.name;
  const clubNames =
    event.clubNames?.filter(Boolean) || (clubName ? [clubName] : []);
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
        {clubNames.length > 0 ? (
          <div className="event-card__clubs" aria-label="Hosting clubs">
            {clubNames.map((name) => (
              <p className="event-card__club" key={name}>
                {name}
              </p>
            ))}
          </div>
        ) : null}
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
