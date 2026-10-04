import { useCallback, useEffect, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { getErrorMessage } from "../utils/errors";
import { formatDate } from "../utils/format";
import { getPromoLunchDaysLabel } from "../utils/clubPromoLunch";
import {
  getAdminClubPromoLunchRequestById,
  reviewClubPromoLunchRequest,
} from "../services/clubPromoLunch";
import { ConfirmDialog } from "../components/ui/ConfirmDialog";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { LoadingScreen } from "../components/ui/LoadingScreen";
import { StatusBadge } from "../components/ui/StatusBadge";
import { TextArea } from "../components/ui/TextArea";

const LIST_PATH = "/exec-dashboard/requests/promo-lunch";

export function AdminPromoLunchDetailPage({ embedded = false }) {
  const { requestId } = useParams();
  const navigate = useNavigate();
  const { canMutateReviews, isSacAdmin, isSacExec, isFacultyAdvisor } =
    useAuth();
  const [request, setRequest] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [actionError, setActionError] = useState("");
  const [reviewNotes, setReviewNotes] = useState("");
  const [confirmAction, setConfirmAction] = useState("");
  const [busy, setBusy] = useState(false);
  const canView = isSacAdmin || isSacExec || isFacultyAdvisor;

  const loadRequest = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const data = await getAdminClubPromoLunchRequestById(requestId);
      if (!data) {
        setError("This sign-up could not be found.");
        return;
      }
      setRequest(data);
      setReviewNotes(data.review_notes || "");
    } catch (loadError) {
      setError(getErrorMessage(loadError, "Could not load this sign-up."));
    } finally {
      setLoading(false);
    }
  }, [requestId]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- intentional async detail fetch
    if (canView) void loadRequest();
  }, [canView, loadRequest]);

  async function runAction() {
    if (!request || !confirmAction) return;
    const notes = reviewNotes.trim();
    if (confirmAction === "REJECTED" && !notes) {
      setActionError("Review notes are required when rejecting.");
      setConfirmAction("");
      return;
    }
    setBusy(true);
    setActionError("");
    try {
      await reviewClubPromoLunchRequest({
        requestId: request.id,
        action: confirmAction,
        reviewNotes: notes || null,
      });
      navigate(LIST_PATH, {
        state: { success: `Updated ${request.clubs?.name || "sign-up"}.` },
      });
    } catch (actionErr) {
      setActionError(getErrorMessage(actionErr, "Could not update this sign-up."));
    } finally {
      setBusy(false);
      setConfirmAction("");
    }
  }

  if (!canView) {
    return (
      <div className={embedded ? "exec-section" : "page"}>
        <ErrorMessage>Executive access is required.</ErrorMessage>
      </div>
    );
  }
  if (loading) return <LoadingScreen message="Loading Promo Lunch sign-up…" />;
  if (!request) {
    return (
      <div className={embedded ? "exec-section" : "page"}>
        <Link className="text-link" to={LIST_PATH}>
          ← Back to Promo Lunch
        </Link>
        <ErrorMessage>{error || "Sign-up not found."}</ErrorMessage>
      </div>
    );
  }

  const canReview = canMutateReviews && request.status === "SUBMITTED";
  return (
    <div className={embedded ? "exec-section" : "page"}>
      <p className="exec-detail-back">
        <Link className="text-link" to={LIST_PATH}>
          ← Back to Promo Lunch
        </Link>
      </p>
      <section className="admin-request-hero">
        <p className="admin-request-hero__eyebrow">Submitted</p>
        <div className="admin-request-hero__heading">
          <h2 className="exec-section__title">
            {request.clubs?.name || "Club Promo Lunch"}
          </h2>
          <StatusBadge status={request.status} />
        </div>
        <div className="admin-request-hero__meta">
          <div>
            <span>Applicant</span>
            <strong>{request.applicant_email}</strong>
          </div>
          <span className="admin-request-hero__divider" aria-hidden="true" />
          <div>
            <span>Submitted</span>
            <strong>{formatDate(request.submitted_at)}</strong>
          </div>
        </div>
      </section>
      {actionError ? <ErrorMessage>{actionError}</ErrorMessage> : null}
      <article className="panel admin-request-card">
        <dl className="detail-list">
          <div>
            <dt>Booth days</dt>
            <dd>{getPromoLunchDaysLabel(request.booth_days)}</dd>
          </div>
          <div>
            <dt>Approval email received</dt>
            <dd>{request.approval_email_received ? "Yes" : "No"}</dd>
          </div>
          <div className="detail-list__description">
            <dt>Representative(s)</dt>
            <dd>{request.representatives}</dd>
          </div>
        </dl>
        {request.review_notes ? (
          <div className="alert alert--info">
            <strong>Review notes</strong>
            <p>{request.review_notes}</p>
          </div>
        ) : null}
        {canReview ? (
          <div className="admin-request-review">
            <TextArea
              id="promo-lunch-review-notes"
              label="Review notes"
              value={reviewNotes}
              onChange={(event) => setReviewNotes(event.target.value)}
              hint="Required when rejecting. Optional when approving."
              disabled={busy}
            />
            <div className="button-row">
              <button
                type="button"
                className="button button--primary"
                disabled={busy}
                onClick={() => setConfirmAction("APPROVED")}
              >
                Approve
              </button>
              <button
                type="button"
                className="button button--danger"
                disabled={busy}
                onClick={() => setConfirmAction("REJECTED")}
              >
                Reject
              </button>
            </div>
          </div>
        ) : null}
      </article>
      <ConfirmDialog
        open={Boolean(confirmAction)}
        title={`${confirmAction === "REJECTED" ? "Reject" : "Approve"} sign-up?`}
        confirmLabel={confirmAction === "REJECTED" ? "Reject" : "Approve"}
        destructive={confirmAction === "REJECTED"}
        busy={busy}
        onCancel={() => setConfirmAction("")}
        onConfirm={runAction}
      >
        <p>Confirm this Club Promo Lunch decision.</p>
      </ConfirmDialog>
    </div>
  );
}
