import { Link } from "react-router-dom";

const sacPresidents = [
  { id: "arshaan", name: "Arshaan Thind", role: "Co-President" },
  { id: "amrita", name: "Amrita Rajaram", role: "Co-President" },
];

const groupPhoto = "/images/team/pres.jpg";

export function HomeWhoWeAre() {
  return (
    <section className="panel who-we-are" aria-labelledby="who-we-are-heading">
      <div className="who-we-are__top">
        <div className="who-we-are__photo">
          <img
            src={groupPhoto}
            alt="SAC co-presidents Arshaan Thind and Amrita Rajaram"
          />
        </div>

        <div className="who-we-are__intro">
          <p className="eyebrow">Who we are</p>
          <h2 id="who-we-are-heading">About SAC</h2>
          <p className="lede">
            SAC stands for Student Activity Council. We're a team of John
            Fraser students committed to enhancing your high school
            experience through a diverse array of events. Learn more about
            what we do and how you can get involved.
          </p>
        </div>
      </div>

      <div className="officer-row">
        <div className="officer-list">
          {sacPresidents.map((officer) => (
            <div key={officer.id} className="officer-list__item">
              <p className="officer-list__name">{officer.name}</p>
              <p className="officer-list__role">{officer.role}</p>
            </div>
          ))}
        </div>

        <div className="who-we-are__actions">
          <Link
            to="/our-team"
            className="btn-meet-team"
            onClick={() => window.scrollTo(0, 0)}
          >
            Meet the Team
          </Link>
          <Link
            to="/sac-events"
            className="btn-meet-team btn-meet-team--outline"
            onClick={() => window.scrollTo(0, 0)}
          >
            Past Events
          </Link>
        </div>
      </div>
    </section>
  );
}
