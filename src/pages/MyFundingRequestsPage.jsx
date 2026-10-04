/* eslint-disable react-hooks/set-state-in-effect */
import { useCallback, useEffect, useMemo, useState } from "react";
import { Navigate, useOutletContext } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { ClubFundingForm } from "../components/clubs/ClubFundingForm";
import { OwnedClubRequestForm } from "../components/clubs/OwnedClubRequestForm";
import { EmptyState } from "../components/ui/EmptyState";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { LoadingScreen } from "../components/ui/LoadingScreen";
import { StatusBadge } from "../components/ui/StatusBadge";
import { getMyFundingRequests } from "../services/clubFunding";
import { getOwnedApprovedClubs } from "../utils/clubPermissions";
import { getErrorMessage } from "../utils/errors";
import { formatDate } from "../utils/format";

export function MyFundingRequestsPage() {
  const { memberships = [], tabs = [] } = useOutletContext() || {};
  const { user } = useAuth();
  const canView = tabs.some((tab) => tab.id === "funding");
  const [requests, setRequests] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const leaderClubs = useMemo(
    () => getOwnedApprovedClubs(memberships),
    [memberships],
  );

  const userId = user?.id;

  const loadRequests = useCallback(async () => {
    if (!canView || !userId) return;
    setLoading(true);
    setError("");
    try {
      setRequests(await getMyFundingRequests(userId));
    } catch (loadError) {
      setError(
        getErrorMessage(loadError, "Could not load your funding requests."),
      );
    } finally {
      setLoading(false);
    }
  }, [canView, userId]);

  useEffect(() => {
    void loadRequests();
  }, [loadRequests]);

  if (!canView) {
    return <Navigate to="/my-requests/applications" replace />;
  }

  if (loading) {
    return <LoadingScreen message="Loading funding requests…" />;
  }

  return (
    <div className="stack">
      <section className="panel">
        <h2>Club funding</h2>
        <p className="muted">
          Submit a funding request for a club you own, then track reviews here.
        </p>
      </section>

      {error ? <ErrorMessage>{error}</ErrorMessage> : null}

      {leaderClubs.length === 0 ? (
        <EmptyState title="No funding clubs yet">
          Funding requests are available for officially active clubs you own.
        </EmptyState>
      ) : (
        <OwnedClubRequestForm clubs={leaderClubs}>
          {(club) => (
            <ClubFundingForm
              key={club.id}
              club={club}
              onSubmitted={loadRequests}
            />
          )}
        </OwnedClubRequestForm>
      )}

      {requests.length > 0 ? (
        <section className="panel">
          <h3>Submitted requests</h3>
          <ul className="stack">
            {requests.map((request) => (
              <li key={request.id} className="funding-request-summary">
                <div className="funding-request-summary__main">
                  <div className="request-card__labels">
                    <span className="submission-type funding-request-summary__type">
                      Funding request
                    </span>
                    <StatusBadge status={request.status} prefix="Status: " />
                  </div>
                  <strong>{request.clubs?.name || "Club funding request"}</strong>
                </div>
                <div className="funding-request-summary__meta">
                  <time
                    className="request-card__date"
                    dateTime={request.submitted_at || request.created_at || undefined}
                  >
                    Submitted {formatDate(request.submitted_at || request.created_at)}
                  </time>
                  <strong>
                    ${Number(request.total_amount || 0).toFixed(2)}
                  </strong>
                </div>
              </li>
            ))}
          </ul>
        </section>
      ) : null}
    </div>
  );
}
