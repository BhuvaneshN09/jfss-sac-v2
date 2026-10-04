import { useCallback, useEffect, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { AttachmentPreview } from "../components/ui/AttachmentPreview";
import { ConfirmDialog } from "../components/ui/ConfirmDialog";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { LoadingScreen } from "../components/ui/LoadingScreen";
import { StatusBadge } from "../components/ui/StatusBadge";
import { TextArea } from "../components/ui/TextArea";
import {
  createSignedFundingSignatureUrl,
  getAdminClubFundingRequestById,
  reviewClubFundingRequest,
} from "../services/clubFunding";
import { getErrorMessage } from "../utils/errors";
import { formatDate } from "../utils/format";

const LIST_PATH = "/exec-dashboard/requests/funding";
const REVIEWABLE_STATUSES = [
  "SUBMITTED",
  "UNDER_REVIEW",
  "CHANGES_REQUESTED",
];

function formatCurrency(value) {
  return `$${Number(value || 0).toFixed(2)}`;
}

export function AdminClubFundingDetailPage({ embedded = false }) {
  const { requestId } = useParams();
  const navigate = useNavigate();
  const { isSacAdmin } = useAuth();
  const [request, setRequest] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [actionError, setActionError] = useState("");
  const [reviewNotes, setReviewNotes] = useState("");
  const [confirmAction, setConfirmAction] = useState(null);
  const [busy, setBusy] = useState(false);

  const loadRequest = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const data = await getAdminClubFundingRequestById(requestId);
      if (!data) {
        setError("This funding request could not be found.");
        setRequest(null);
        return;
      }
      setRequest(data);
      setReviewNotes(data.review_notes || "");
    } catch (loadError) {
      setError(
        getErrorMessage(loadError, "Could not load this funding request."),
      );
    } finally {
      setLoading(false);
    }
  }, [requestId]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- intentional async detail fetch
    if (isSacAdmin) void loadRequest();
  }, [isSacAdmin, loadRequest]);

  async function runAction() {
    if (!request || !confirmAction) return;
    const notes = reviewNotes.trim();
    if (confirmAction === "REJECTED" && !notes) {
      setActionError("Review notes are required for this action.");
      setConfirmAction(null);
      return;
    }

    setBusy(true);
    setActionError("");
    try {
      await reviewClubFundingRequest({
        requestId: request.id,
        action: confirmAction,
        reviewNotes: notes || null,
      });
      navigate(LIST_PATH, {
        state: {
          success: `Updated ${request.clubs?.name || "funding request"} to ${confirmAction}.`,
        },
      });
    } catch (actionErr) {
      setActionError(
        getErrorMessage(actionErr, "Could not update the funding request."),
      );
    } finally {
      setBusy(false);
      setConfirmAction(null);
    }
  }

  if (!isSacAdmin) {
    return (
      <div className={embedded ? "exec-section" : "page"}>
        <ErrorMessage>SAC admin access is required.</ErrorMessage>
      </div>
    );
  }

  if (loading) {
    return <LoadingScreen message="Loading funding request…" />;
  }

  if (error && !request) {
    return (
      <div className={embedded ? "exec-section" : "page"}>
        <p>
          <Link className="text-link" to={LIST_PATH}>
            ← Back to funding requests
          </Link>
        </p>
        <ErrorMessage>{error}</ErrorMessage>
      </div>
    );
  }

  if (!request) return null;

  const clubName = request.clubs?.name || "Club funding request";
  const costRows = Array.isArray(request.cost_breakdown)
    ? request.cost_breakdown
    : [];
  const canReview = REVIEWABLE_STATUSES.includes(request.status);

  return (
    <div className={embedded ? "exec-section" : "page"}>
      <p className="exec-detail-back">
        <Link className="text-link" to={LIST_PATH}>
          ← Back to funding requests
        </Link>
      </p>

      <div className="section-heading-row">
        <div>
          <h2 className="exec-section__title">{clubName}</h2>
          <StatusBadge status={request.status} />
        </div>
        {request.requires_principal_review ? (
          <span className="badge badge--warning">Principal review</span>
        ) : null}
      </div>

      {actionError ? <ErrorMessage>{actionError}</ErrorMessage> : null}

      <article className="panel admin-request-card">
        <dl className="detail-list">
          <div>
            <dt>Applicant</dt>
            <dd>{request.applicant_email}</dd>
          </div>
          <div>
            <dt>Submitted</dt>
            <dd>{formatDate(request.submitted_at)}</dd>
          </div>
          <div>
            <dt>School year</dt>
            <dd>{request.school_year}</dd>
          </div>
          <div>
            <dt>How the school/students benefit</dt>
            <dd className="prose">{request.usage_of_funding}</dd>
          </div>
        </dl>

        <section className="funding-review-breakdown">
          <h3>Cost breakdown</h3>
          <ul className="stack">
            {costRows.map((row, index) => (
              <li className="funding-review-row" key={`${row.item}-${index}`}>
                <span>{row.item}</span>
                <span>
                  {formatCurrency(row.unit_price)} × {row.quantity}
                </span>
              </li>
            ))}
          </ul>
          <p className="funding-total">
            <strong>Total</strong>
            <strong>{formatCurrency(request.total_amount)}</strong>
          </p>
        </section>

        <section className="funding-signature-review">
          <h3>Teacher Approval Form</h3>
          <AttachmentPreview
            path={request.supervisor_signature_path}
            getSignedUrl={createSignedFundingSignatureUrl}
            alt="Signed Teacher Approval Form"
          />
          {request.applicant_signature_path &&
          request.applicant_signature_path !==
            request.supervisor_signature_path ? (
            <div>
              <h4>Applicant signature and date</h4>
              <AttachmentPreview
                path={request.applicant_signature_path}
                getSignedUrl={createSignedFundingSignatureUrl}
                alt="Applicant signature and date"
              />
            </div>
          ) : null}
        </section>

        {request.review_notes ? (
          <div className="alert alert--info">
            <strong>Review notes</strong>
            <p>{request.review_notes}</p>
          </div>
        ) : null}

        {canReview ? (
          <>
            <TextArea
              id="funding-review-notes"
              label="Review notes"
              value={reviewNotes}
              onChange={(event) => setReviewNotes(event.target.value)}
              hint="Required when rejecting."
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
          </>
        ) : null}
      </article>

      <ConfirmDialog
        open={Boolean(confirmAction)}
        title={`${confirmAction || ""} funding request?`}
        confirmLabel={confirmAction === "REJECTED" ? "Reject" : "Confirm"}
        destructive={confirmAction === "REJECTED"}
        busy={busy}
        onCancel={() => setConfirmAction(null)}
        onConfirm={runAction}
      >
        <p>
          Confirm that you want to mark this request as{" "}
          <strong>{confirmAction}</strong>.
        </p>
      </ConfirmDialog>
    </div>
  );
}
