import { CLUB_LIAISONS } from "../../config/clubApplications";

/**
 * Club liaison contact list.
 * Use `embedded` inside another panel (e.g. apply disclaimer).
 */
export function ClubLiaisonContacts({ embedded = false }) {
  const body = (
    <>
      <h2 className={embedded ? "club-liaison-contacts__title" : undefined}>
        Club liaisons
      </h2>
      <p className="muted club-liaison-contacts__lede">
        If you have any questions, please contact our club liaisons:
      </p>
      <ul className="club-liaison-contacts__list">
        {CLUB_LIAISONS.map((person) => (
          <li key={person.email} className="club-liaison-contacts__person">
            <strong className="club-liaison-contacts__name">{person.name}</strong>
            <a className="text-link" href={`mailto:${person.email}`}>
              {person.email}
            </a>
            <span className="muted">IG: {person.instagram}</span>
          </li>
        ))}
      </ul>
    </>
  );

  if (embedded) {
    return (
      <div className="club-liaison-contacts club-liaison-contacts--embedded">
        {body}
      </div>
    );
  }

  return <section className="panel club-liaison-contacts">{body}</section>;
}
