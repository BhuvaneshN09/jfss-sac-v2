import { useCallback, useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { ExecReviewQueueCard } from "../components/exec/ExecReviewQueueCard";
import { EmptyState } from "../components/ui/EmptyState";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { LoadingScreen } from "../components/ui/LoadingScreen";
import { getAdminClubEventQueue } from "../services/clubEvents";
import { getErrorMessage } from "../utils/errors";

export function AdminEventsPage({ embedded = false }) {
  const { isSacAdmin, isSacExec, isFacultyAdvisor } = useAuth();
  const [events, setEvents] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const canView = isSacAdmin || isSacExec || isFacultyAdvisor;

  const loadQueue = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      setEvents(await getAdminClubEventQueue());
    } catch (loadError) {
      setError(
        getErrorMessage(loadError, "Could not load the event proposal queue."),
      );
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- intentional async queue fetch
    if (canView) void loadQueue();
  }, [canView, loadQueue]);

  if (!canView) {
    return (
      <div className={embedded ? "exec-section" : "page"}>
        <ErrorMessage>Executive access is required.</ErrorMessage>
      </div>
    );
  }

  if (loading) {
    return <LoadingScreen message="Loading event proposals…" />;
  }

  return (
    <div className={embedded ? "exec-section" : "page"}>
      {embedded ? (
        <h2 className="exec-section__title">Events</h2>
      ) : (
        <header className="page-header">
          <h1>Events</h1>
          <Link className="text-link" to="/events">
            View public events
          </Link>
        </header>
      )}

      {error ? <ErrorMessage>{error}</ErrorMessage> : null}
      {!error && events.length === 0 ? (
        <EmptyState
          title="No events"
          description="There are no submitted events."
        />
      ) : (
        <div className="exec-queue-list">
          {events.map((event) => (
            <ExecReviewQueueCard
              key={event.id}
              to={`/exec-dashboard/requests/events/${event.id}`}
              title={event.event_name}
              submitter={event.applicant_email}
              status={event.status}
            />
          ))}
        </div>
      )}
    </div>
  );
}
