import { Link } from "react-router-dom";
import { resolveClubLogoUrl } from "../../utils/clubMedia";

export function ClubCard({ club }) {
  const initial = club.name?.charAt(0)?.toUpperCase() || "C";
  const logoUrl = resolveClubLogoUrl(club.logo_url);
  const instagramHandle = club.instagram_handle
    ? `@${String(club.instagram_handle).replace(/^@/, "")}`
    : "";

  return (
    <article className="club-card">
      <div className="club-card__media">
        {logoUrl ? (
          <img
            src={logoUrl}
            alt=""
            className="club-card__logo"
            loading="lazy"
            decoding="async"
          />
        ) : (
          <div
            className="club-card__logo club-card__logo--fallback"
            aria-hidden="true"
          >
            {initial}
          </div>
        )}
      </div>

      <div className="club-card__body">
        <h2>
          <Link to={`/clubs/${club.slug}`}>{club.name}</Link>
        </h2>

        {club.description ? (
          <p className="club-card__summary">{club.description}</p>
        ) : (
          <p className="club-card__summary muted">
            No description provided.
          </p>
        )}

        {instagramHandle || club.contact_email ? (
          <dl className="meta-list">
            {instagramHandle ? (
              <div>
                <dt>Instagram</dt>
                <dd>{instagramHandle}</dd>
              </div>
            ) : null}
            {club.contact_email ? (
              <div>
                <dt>Email</dt>
                <dd>{club.contact_email}</dd>
              </div>
            ) : null}
          </dl>
        ) : null}

        <Link className="text-link" to={`/clubs/${club.slug}`}>
          View club details
        </Link>
      </div>
    </article>
  );
}
