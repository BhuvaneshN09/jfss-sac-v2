import { useCallback, useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { ConfirmDialog } from "../components/ui/ConfirmDialog";
import { EmptyState } from "../components/ui/EmptyState";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { LoadingScreen } from "../components/ui/LoadingScreen";
import { StatusBadge } from "../components/ui/StatusBadge";
import { Spinner } from "../components/ui/Spinner";
import {
  getMyClubReapplications,
  getReapplicationDisplayStatus,
  withdrawClubReapplication,
} from "../services/clubReapplications";
import { getClubAnnualState } from "../services/clubs";
import { formatDate } from "../utils/format";
import { getErrorMessage } from "../utils/errors";

const PAGE_SIZE = 5;

function canWithdrawReapplication(request, annualStatus) {
  if (request.status === "SUBMITTED") {
    return true;
  }
  return (
    request.status === "APPROVED" && annualStatus === "PENDING_SUPERVISOR"
  );
}

export function MyClubReapplicationsPage() {
  const { user } = useAuth();
  const [reapplications, setReapplications] = useState([]);
  const [annualByClubId, setAnnualByClubId] = useState({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [actionError, setActionError] = useState("");
  const [busyId, setBusyId] = useState(null);
  const [withdrawTarget, setWithdrawTarget] = useState(null);
  const [visibleCount, setVisibleCount] = useState(PAGE_SIZE);

  const loadRequests = useCallback(async () => {
    setLoading(true);
    setError("");

    try {
      const reapps = await getMyClubReapplications(user.id);
      setReapplications(reapps);
      setVisibleCount(PAGE_SIZE);

      const annualEntries = await Promise.all(
        reapps
          .filter((row) => row.club_id && row.status === "APPROVED")
          .map(async (row) => {
            try {
              const annual = await getClubAnnualState(row.club_id);
              return [row.club_id, annual?.status ?? null];
            } catch {
              return [row.club_id, null];
            }
          }),
      );
      setAnnualByClubId(Object.fromEntries(annualEntries));
    } catch (loadError) {
      setError(
        getErrorMessage(loadError, "Could not load your re-applications."),
      );
    } finally {
      setLoading(false);
    }
  }, [user.id]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- load request data on mount
    loadRequests();
  }, [loadRequests]);

  async function runAction(requestId, action) {
    setBusyId(requestId);
    setActionError("");
    try {
      await action();
      await loadRequests();
    } catch (actionErr) {
      setActionError(getErrorMessage(actionErr, "Action failed."));
    } finally {
      setBusyId(null);
    }
  }

  if (loading) {
    return <LoadingScreen message="Loading re-applications…" />;
  }

  const visible = reapplications.slice(0, visibleCount);
  const hasMore = visibleCount < reapplications.length;

  return (
    <div className="stack">
      <header className="page-header">
        <Link className="button button--secondary" to="/clubs/reapply">
          Re-apply an existing club
        </Link>
      </header>

      {error ? <ErrorMessage>{error}</ErrorMessage> : null}
      {actionError ? <ErrorMessage>{actionError}</ErrorMessage> : null}

      {!error && reapplications.length === 0 ? (
        <EmptyState title="No re-applications yet">
          Re-apply a past club to see it tracked here.
        </EmptyState>
      ) : null}

      {visible.map((request) => {
        const annualStatus = annualByClubId[request.club_id] || null;
        const displayStatus = getReapplicationDisplayStatus(
          request,
          annualStatus,
        );
        const canWithdraw = canWithdrawReapplication(request, annualStatus);
        const isBusy = busyId === request.id;
        const showManage =
          request.clubs?.slug &&
          request.status === "APPROVED" &&
          (annualStatus === "PENDING_SUPERVISOR" ||
            annualStatus === "ACTIVE");

        return (
          <article key={request.id} className="panel">
            <div className="section-heading">
              <div>
                <div className="request-card__labels">
                  <span className="submission-type">Re-application</span>
                  <StatusBadge status={displayStatus} prefix="Status: " />
                </div>
                <h3>
                  {request.clubs?.name || request.club_name || "Club re-application"}
                </h3>
              </div>
              <div className="request-card__aside">
                <time
                  className="request-card__date"
                  dateTime={request.submitted_at || request.created_at || undefined}
                >
                  Submitted {formatDate(request.submitted_at || request.created_at)}
                </time>
                {showManage ? (
                  <Link
                    className="text-link"
                    to={`/clubs/${request.clubs.slug}/manage`}
                  >
                    Manage club
                  </Link>
                ) : null}
              </div>
            </div>
            {request.review_notes ? (
              <p>
                <strong>Review notes:</strong> {request.review_notes}
              </p>
            ) : null}
            {request.status === "REJECTED" || request.status === "WITHDRAWN" ? (
              <p className="request-card__new-action">
                <Link
                  to={
                    request.club_id
                      ? `/clubs/reapply?club=${encodeURIComponent(request.club_id)}`
                      : "/clubs/reapply"
                  }
                >
                  Re-apply for this club
                </Link>
                . A rejected or withdrawn re-application can be submitted again.
              </p>
            ) : null}
            {canWithdraw ? (
              <div className="button-row">
                <button
                  type="button"
                  className="button button--secondary"
                  disabled={isBusy}
                  onClick={() => setWithdrawTarget(request)}
                >
                  {isBusy ? <Spinner size="sm" label="Working" /> : null}
                  Withdraw
                </button>
              </div>
            ) : null}
          </article>
        );
      })}

      {hasMore ? (
        <div className="button-row">
          <button
            type="button"
            className="button button--secondary"
            onClick={() => setVisibleCount((current) => current + PAGE_SIZE)}
          >
            View more
          </button>
        </div>
      ) : null}

      <ConfirmDialog
        open={Boolean(withdrawTarget)}
        title="Withdraw re-application?"
        confirmLabel="Withdraw"
        destructive
        busy={busyId === withdrawTarget?.id}
        onCancel={() => setWithdrawTarget(null)}
        onConfirm={() => {
          const target = withdrawTarget;
          if (!target) return;
          setWithdrawTarget(null);
          runAction(target.id, () => withdrawClubReapplication(target.id));
        }}
      >
        <p>
          This will cancel this club application and return the club to inactive
          status. The club history will remain and students may apply again in
          the future.
        </p>
      </ConfirmDialog>
    </div>
  );
}
