import { useCallback, useEffect, useMemo, useState } from "react";
import { Link, Navigate, useOutletContext } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { ClubEventForm } from "../components/clubs/ClubEventForm";
import { OwnedClubRequestForm } from "../components/clubs/OwnedClubRequestForm";
import { EmptyState } from "../components/ui/EmptyState";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { LoadingScreen } from "../components/ui/LoadingScreen";
import { StatusBadge } from "../components/ui/StatusBadge";
import { getMyClubEventRequests } from "../services/clubEvents";
import { getOwnedApprovedClubs } from "../utils/clubPermissions";
import { getErrorMessage } from "../utils/errors";
import { formatDate } from "../utils/format";
import { formatDateOnly } from "../utils/torontoDate";

export function MyEventRequestsPage() {
  const { memberships = [], tabs = [] } = useOutletContext() || {};
  const { user } = useAuth();
  const canView = tabs.some((tab) => tab.id === "events");
  const [requests, setRequests] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const leaderClubs = useMemo(
    () => getOwnedApprovedClubs(memberships),
    [memberships],
  );

  const loadRequests = useCallback(async () => {
    if (!canView || !user?.id) return;
    setLoading(true);
    setError("");
    try {
      setRequests(await getMyClubEventRequests(user.id));
    } catch (loadError) {
      setError(getErrorMessage(loadError, "Could not load your event proposals."));
    } finally {
      setLoading(false);
    }
  }, [canView, user.id]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- intentional async request fetch
    loadRequests();
  }, [loadRequests]);

  if (!canView) {
    return <Navigate to="/my-requests/applications" replace />;
  }

  if (loading) {
    return <LoadingScreen message="Loading event proposals…" />;
  }

  return (
    <div className="stack">
      <header className="page-header">
        <div>
          <p className="eyebrow">Submissions</p>
          <h1>Events</h1>
          <p className="muted">
            Submit an event proposal for a club you own, then track reviews
            here.
          </p>
        </div>
        <Link className="button button--primary" to="/events">
          View events
        </Link>
      </header>

      {error ? <ErrorMessage>{error}</ErrorMessage> : null}

      {leaderClubs.length === 0 ? (
        <EmptyState
          title="No event clubs yet"
          description="Event proposals are available for officially active clubs you own."
        />
      ) : (
        <OwnedClubRequestForm clubs={leaderClubs}>
          {(club) => (
            <ClubEventForm
              key={club.id}
              club={club}
              onSubmitted={loadRequests}
            />
          )}
        </OwnedClubRequestForm>
      )}

      {requests.length > 0
        ? requests.map((request) => (
            <article className="request-card" key={request.id}>
              <div className="request-card__header">
                <div>
                  <div className="request-card__labels">
                    <span className="submission-type request-card__type">
                      Event proposal
                    </span>
                    <StatusBadge status={request.status} prefix="Status: " />
                  </div>
                  <h2>{request.event_name}</h2>
                  <p className="muted">{request.clubs?.name}</p>
                </div>
                <time
                  className="request-card__date"
                  dateTime={request.submitted_at || request.created_at || undefined}
                >
                  Submitted {formatDate(request.submitted_at || request.created_at)}
                </time>
              </div>
              <dl className="meta-list">
                <div>
                  <dt>Event dates</dt>
                  <dd>
                    {formatDateOnly(request.event_date)} –{" "}
                    {formatDateOnly(request.event_end_date)}
                  </dd>
                </div>
                <div>
                  <dt>Charitable event</dt>
                  <dd>{request.is_charitable_event ? "Yes" : "No"}</dd>
                </div>
                <div>
                  <dt>Updated</dt>
                  <dd>{formatDate(request.updated_at)}</dd>
                </div>
              </dl>
              {request.review_notes ? (
                <div className="request-card__notes">
                  <strong>Review notes</strong>
                  <p>{request.review_notes}</p>
                </div>
              ) : null}
            </article>
          ))
        : null}
    </div>
  );
}
