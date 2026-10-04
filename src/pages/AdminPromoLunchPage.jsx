import { useCallback, useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { ExecReviewQueueCard } from "../components/exec/ExecReviewQueueCard";
import { EmptyState } from "../components/ui/EmptyState";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { LoadingScreen } from "../components/ui/LoadingScreen";
import { getAdminClubPromoLunchQueue } from "../services/clubPromoLunch";
import { getErrorMessage } from "../utils/errors";

export function AdminPromoLunchPage({ embedded = false }) {
  const { isSacAdmin, isSacExec, isFacultyAdvisor } = useAuth();
  const [requests, setRequests] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const canView = isSacAdmin || isSacExec || isFacultyAdvisor;

  const loadQueue = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      setRequests(await getAdminClubPromoLunchQueue());
    } catch (loadError) {
      setError(getErrorMessage(loadError, "Could not load Promo Lunch sign-ups."));
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
    return <LoadingScreen message="Loading Promo Lunch sign-ups…" />;
  }

  return (
    <div className={embedded ? "exec-section" : "page"}>
      {embedded ? (
        <h2 className="exec-section__title">Promo Lunch</h2>
      ) : (
        <header className="page-header">
          <h1>Promo Lunch</h1>
          <Link className="text-link" to="/my-requests/promo-lunch">
            View my sign-ups
          </Link>
        </header>
      )}
      {error ? <ErrorMessage>{error}</ErrorMessage> : null}
      {!error && requests.length === 0 ? (
        <EmptyState
          title="No Promo Lunch sign-ups"
          description="There are no submitted sign-ups awaiting review."
        />
      ) : (
        <div className="exec-queue-list">
          {requests.map((request) => (
            <ExecReviewQueueCard
              key={request.id}
              to={`/exec-dashboard/requests/promo-lunch/${request.id}`}
              title={request.clubs?.name || "Club Promo Lunch"}
              submitter={request.applicant_email}
              status={request.status}
            />
          ))}
        </div>
      )}
    </div>
  );
}
