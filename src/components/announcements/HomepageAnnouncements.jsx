import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { AnnouncementCard } from "./AnnouncementCard";
import { EmptyState } from "../ui/EmptyState";
import { ErrorMessage } from "../ui/ErrorMessage";
import { Spinner } from "../ui/Spinner";
import { getHomepageAnnouncements } from "../../services/announcements";
import { getErrorMessage } from "../../utils/errors";

export function HomepageAnnouncements({ limit = 5 }) {
  const [announcements, setAnnouncements] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    let active = true;

    async function load() {
      setLoading(true);
      setError("");

      try {
        const data = await getHomepageAnnouncements(limit);
        if (!active) return;
        setAnnouncements(data);
      } catch (loadError) {
        if (!active) return;
        setError(
          getErrorMessage(loadError, "Could not load latest announcements."),
        );
      } finally {
        if (active) setLoading(false);
      }
    }

    load();
    return () => {
      active = false;
    };
  }, [limit]);

  return (
    <section className="panel homepage-announcements" aria-labelledby="home-announcements-heading">
      <div className="section-heading">
        <div>
          <p className="eyebrow">Announcements</p>
          <h2 id="home-announcements-heading">Published announcements</h2>
        </div>
        <Link className="text-link" to="/announcements">
          See more
        </Link>
      </div>

      {loading ? (
        <p className="muted">
          <Spinner size="sm" label="Loading" /> Loading announcements…
        </p>
      ) : null}

      {error ? <ErrorMessage>{error}</ErrorMessage> : null}

      {!loading && !error && announcements.length === 0 ? (
        <EmptyState title="No announcements yet">
          Published announcements will appear here.
        </EmptyState>
      ) : null}

      {!loading && !error && announcements.length > 0 ? (
        <div className="announcement-grid">
          {announcements.map((announcement) => (
            <AnnouncementCard
              key={announcement.id}
              announcement={announcement}
            />
          ))}
        </div>
      ) : null}
    </section>
  );
}
