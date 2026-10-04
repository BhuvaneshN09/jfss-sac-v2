import { useCallback, useEffect, useState } from "react";
import { EmptyState } from "../components/ui/EmptyState";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { LoadingScreen } from "../components/ui/LoadingScreen";
import { StatusBadge } from "../components/ui/StatusBadge";
import { useAuth } from "../context/AuthContext";
import { getMyClubPromoLunchRequests } from "../services/clubPromoLunch";
import { getErrorMessage } from "../utils/errors";
import { formatDate } from "../utils/format";
import { getPromoLunchDaysLabel } from "../utils/clubPromoLunch";

export function MyPromoLunchRequestsPage() {
  const { user } = useAuth();
  const [requests, setRequests] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const loadRequests = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      setRequests(await getMyClubPromoLunchRequests(user.id));
    } catch (loadError) {
      setError(
        getErrorMessage(loadError, "Could not load your Promo Lunch sign-ups."),
      );
    } finally {
      setLoading(false);
    }
  }, [user.id]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- intentional async request fetch
    loadRequests();
  }, [loadRequests]);

  if (loading) {
    return <LoadingScreen message="Loading Promo Lunch sign-ups…" />;
  }

  return (
    <div className="stack">
      <header className="page-header">
        <div>
          <p className="eyebrow">Submissions</p>
          <h1>Club Promo Lunch</h1>
        </div>
      </header>
      {error ? <ErrorMessage>{error}</ErrorMessage> : null}
      {!error && requests.length === 0 ? (
        <EmptyState
          title="No sign-ups yet"
          description="Submit a Club Promo Lunch sign-up from Manage Club."
        />
      ) : (
        requests.map((request) => (
          <article className="request-card" key={request.id}>
            <div className="request-card__header">
              <div>
                <div className="request-card__labels">
                  <span className="submission-type request-card__type">
                    Promo Lunch
                  </span>
                  <StatusBadge status={request.status} prefix="Status: " />
                </div>
                <h2>{request.clubs?.name || "Club Promo Lunch"}</h2>
              </div>
              <time className="request-card__date">
                Submitted {formatDate(request.submitted_at)}
              </time>
            </div>
            <dl className="meta-list">
              <div>
                <dt>Booth days</dt>
                <dd>{getPromoLunchDaysLabel(request.booth_days)}</dd>
              </div>
              <div>
                <dt>Approval email</dt>
                <dd>{request.approval_email_received ? "Yes" : "No"}</dd>
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
      )}
    </div>
  );
}
