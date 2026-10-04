import { useCallback, useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { EmptyState } from "../components/ui/EmptyState";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { LoadingScreen } from "../components/ui/LoadingScreen";
import { PermissionNotice } from "../components/ui/PermissionNotice";
import {
  getAnnouncementReviewQueue,
} from "../services/announcements";
import { getErrorMessage } from "../utils/errors";

export function AdminAnnouncementsPage({ embedded = false }) {
  const { canMutateReviews } = useAuth();
  const readOnly = !canMutateReviews;
  const [announcements, setAnnouncements] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const loadQueue = useCallback(async () => {
    setLoading(true);
    setError("");

    try {
      const data = await getAnnouncementReviewQueue();
      setAnnouncements(data);
    } catch (loadError) {
      setError(
        getErrorMessage(loadError, "Could not load the announcement queue."),
      );
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- intentional async queue fetch
    loadQueue();
  }, [loadQueue]);

  const requestClubs = useMemo(() => {
    const clubs = new Map();
    for (const announcement of announcements) {
      const key = announcement.club_id || "general";
      if (clubs.has(key)) continue;
      clubs.set(key, {
        id: announcement.club_id,
        name: announcement.clubs?.name || "General announcements",
      });
    }
    return [...clubs.values()].sort((a, b) =>
      a.name.localeCompare(b.name),
    );
  }, [announcements]);

  if (loading && announcements.length === 0) {
    return <LoadingScreen message="Loading announcement queue…" />;
  }

  return (
    <div className={embedded ? "exec-section" : "page"}>
      {!embedded ? (
        <header className="page-header">
          <div>
            <p className="eyebrow">Administration</p>
            <h1>Announcement review queue</h1>
            <p className="lede">
              Review submissions sorted by scheduled posting date.
              Approving a same-day request publishes it immediately; future
              dates go live at midnight on that day.
            </p>
          </div>
        </header>
      ) : (
        <h2 className="exec-section__title">Announcement Review</h2>
      )}

      {readOnly ? (
        <PermissionNotice title="Read only">
          You can view announcement submissions, but you cannot approve or
          reject them.
        </PermissionNotice>
      ) : (
        <PermissionNotice title="Scheduled posting">
          Choose today to publish when approved, or a future date to
          schedule midnight go-live. Unapproved requests are cancelled after
          their posting day ends.
        </PermissionNotice>
      )}

      {error ? <ErrorMessage>{error}</ErrorMessage> : null}

      {!error && requestClubs.length === 0 ? (
        <EmptyState title="Queue is empty">
          There are no announcements awaiting review.
        </EmptyState>
      ) : (
        <div className="exec-queue-list">
          {requestClubs.map((club) => (
            <Link
              key={club.id || "general"}
              className="exec-queue-card"
              to={`/exec-dashboard/requests/announcements/${
                club.id || "general"
              }`}
            >
              <div className="exec-queue-card__main">
                <h3 className="exec-queue-card__title">{club.name}</h3>
              </div>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
