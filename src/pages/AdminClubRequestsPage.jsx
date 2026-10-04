import { useCallback, useEffect, useState } from "react";
import { Link, useLocation } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { ExecReviewQueueCard } from "../components/exec/ExecReviewQueueCard";
import { EmptyState } from "../components/ui/EmptyState";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { LoadingScreen } from "../components/ui/LoadingScreen";
import { PermissionNotice } from "../components/ui/PermissionNotice";
import { getAdminClubRequestQueue } from "../services/clubRequests";
import { getErrorMessage } from "../utils/errors";

export function AdminClubRequestsPage({ embedded = false }) {
  const location = useLocation();
  const { canMutateReviews } = useAuth();
  const readOnly = !canMutateReviews;
  const [requests, setRequests] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [actionSuccess, setActionSuccess] = useState("");
  const [createdClubLink, setCreatedClubLink] = useState(null);

  useEffect(() => {
    const state = location.state;
    if (state?.success) {
      // eslint-disable-next-line react-hooks/set-state-in-effect -- consume navigation feedback
      setActionSuccess(state.success);
      setCreatedClubLink(state.createdClub ?? null);
      window.history.replaceState({}, document.title);
    }
  }, [location.state]);

  const loadQueue = useCallback(async () => {
    setLoading(true);
    setError("");

    try {
      const data = await getAdminClubRequestQueue();
      setRequests(data);
    } catch (loadError) {
      setError(getErrorMessage(loadError, "Could not load the request queue."));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- intentional async queue fetch
    loadQueue();
  }, [loadQueue]);

  if (loading && requests.length === 0) {
    return <LoadingScreen message="Loading club request queue…" />;
  }

  return (
    <div className={embedded ? "exec-section" : "page"}>
      {!embedded ? (
        <header className="page-header">
          <div>
            <p className="eyebrow">Administration</p>
            <h1>Club request queue</h1>
            <p className="lede">
              Review submitted club registration requests.
            </p>
          </div>
        </header>
      ) : (
        <h2 className="exec-section__title">New Club Applications</h2>
      )}

      {readOnly ? (
        <PermissionNotice title="Read only">
          You can view club registration requests, but you cannot approve or
          reject them.
        </PermissionNotice>
      ) : null}

      {error ? <ErrorMessage>{error}</ErrorMessage> : null}

      {actionSuccess ? (
        <div className="alert alert--success" role="status">
          <strong>Success</strong>
          <p>{actionSuccess}</p>
          {createdClubLink ? (
            <p>
              <Link
                className="text-link"
                to={`/clubs/${createdClubLink.slug}`}
              >
                View {createdClubLink.name}
              </Link>
            </p>
          ) : null}
        </div>
      ) : null}

      {!error && requests.length === 0 ? (
        <EmptyState title="Queue is empty">
          There are no pending club registration requests.
        </EmptyState>
      ) : (
        <div className="exec-queue-list">
          {requests.map((request) => (
            <ExecReviewQueueCard
              key={request.id}
              to={`/exec-dashboard/applications/new/${request.id}`}
              title={request.proposed_name}
              submitter={request.respondent_email || "Unknown submitter"}
              status={request.status}
            />
          ))}
        </div>
      )}
    </div>
  );
}
