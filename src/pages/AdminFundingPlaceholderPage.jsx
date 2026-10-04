import { useCallback, useEffect, useState } from "react";
import { useLocation } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { ExecReviewQueueCard } from "../components/exec/ExecReviewQueueCard";
import { EmptyState } from "../components/ui/EmptyState";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { LoadingScreen } from "../components/ui/LoadingScreen";
import { getAdminClubFundingQueue } from "../services/clubFunding";
import { getErrorMessage } from "../utils/errors";

export function AdminFundingPlaceholderPage({ embedded = false }) {
  const location = useLocation();
  const { isSacAdmin } = useAuth();
  const [requests, setRequests] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");

  const loadQueue = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      setRequests(await getAdminClubFundingQueue());
    } catch (loadError) {
      setError(
        getErrorMessage(loadError, "Could not load funding request queue."),
      );
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    const state = location.state;
    if (state?.success) {
      // eslint-disable-next-line react-hooks/set-state-in-effect -- consume navigation feedback
      setSuccess(state.success);
      window.history.replaceState({}, document.title);
    }
  }, [location.state]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- intentional async queue fetch
    if (isSacAdmin) void loadQueue();
  }, [isSacAdmin, loadQueue]);

  if (!isSacAdmin) {
    return (
      <div className={embedded ? "exec-section" : "page"}>
        <ErrorMessage>SAC admin access is required.</ErrorMessage>
      </div>
    );
  }

  if (loading) {
    return <LoadingScreen message="Loading funding requests…" />;
  }

  return (
    <div className={embedded ? "exec-section" : "page"}>
      {embedded ? (
        <h2 className="exec-section__title">Club Funding Requests</h2>
      ) : (
        <header className="page-header">
          <h1>Club Funding Requests</h1>
        </header>
      )}

      {error ? <ErrorMessage>{error}</ErrorMessage> : null}
      {success ? (
        <div className="alert alert--success" role="status">
          {success}
        </div>
      ) : null}

      {requests.length === 0 ? (
        <EmptyState
          title="No funding requests"
          description="There are no pending funding requests."
        />
      ) : (
        <div className="exec-queue-list">
          {requests.map((request) => (
            <div className="funding-queue-item" key={request.id}>
              <ExecReviewQueueCard
                to={`/exec-dashboard/requests/funding/${request.id}`}
                title={request.clubs?.name || "Club funding request"}
                submitter={request.applicant_email}
                status={request.status}
              />
              {request.requires_principal_review ? (
                <span className="badge badge--warning">
                  Principal review
                </span>
              ) : null}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
