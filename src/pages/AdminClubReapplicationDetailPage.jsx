import { useCallback, useEffect, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { AttachmentPreview } from "../components/ui/AttachmentPreview";
import { ConfirmDialog } from "../components/ui/ConfirmDialog";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { LoadingScreen } from "../components/ui/LoadingScreen";
import { PermissionNotice } from "../components/ui/PermissionNotice";
import { TextArea } from "../components/ui/TextArea";
import { StatusBadge } from "../components/ui/StatusBadge";
import { createSignedClubDocumentUrl } from "../services/clubDocuments";
import {
  approveClubReapplication,
  getClubReapplicationById,
  reviewClubReapplication,
} from "../services/clubReapplications";
import { formatDate } from "../utils/format";
import { getErrorMessage } from "../utils/errors";
import { SafeExternalLink } from "../components/ui/SafeExternalLink";

export function AdminClubReapplicationDetailPage({ embedded = false }) {
  const { requestId } = useParams();
  const navigate = useNavigate();
  const { isSacAdmin, isSacExec } = useAuth();
  const canView = isSacAdmin || isSacExec;
  const canMutate = isSacAdmin;

  const [request, setRequest] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [actionError, setActionError] = useState("");
  const [busy, setBusy] = useState(false);
  const [reviewNotes, setReviewNotes] = useState("");
  const [confirmAction, setConfirmAction] = useState(null);

  const listPath = "/exec-dashboard/applications/reapplications";

  const loadRequest = useCallback(async () => {
    setLoading(true);
    setError("");

    try {
      const data = await getClubReapplicationById(requestId);
      if (!data) {
        setError("This re-application could not be found.");
        setRequest(null);
        return;
      }
      setRequest(data);
      setReviewNotes(data.review_notes || "");
    } catch (loadError) {
      setError(
        getErrorMessage(loadError, "Could not load this re-application."),
      );
    } finally {
      setLoading(false);
    }
  }, [requestId]);

  useEffect(() => {
    if (!canView) return;
    // eslint-disable-next-line react-hooks/set-state-in-effect -- load request data on mount
    loadRequest();
  }, [loadRequest, canView]);

  if (!canView) {
    return (
      <PermissionNotice title="Exec access required">
        Club re-application review is limited to SAC administrators and
        executives.
      </PermissionNotice>
    );
  }

  function openApproveConfirm() {
    if (!request) return;
    setConfirmAction("APPROVED");
  }

  async function runAction(action, requireNotes) {
    if (!request) return;

    const notes = reviewNotes.trim();
    if (requireNotes && !notes) {
      setActionError("Review notes are required for this action.");
      return;
    }

    setBusy(true);
    setActionError("");

    try {
      const clubName = request.clubs?.name || "Club";

      if (action === "APPROVED") {
        const withSupervisor =
          !request.is_seeking_teacher_supervisor &&
          (request.club_reapplication_supervisors || []).length > 0;
        await approveClubReapplication({
          requestId: request.id,
          reviewNotes: notes || null,
          hasTeacherSupervisor: withSupervisor,
          supervisorDueAt: null,
        });
        navigate(listPath, {
          state: {
            success: withSupervisor
              ? `${clubName} was approved and is now public on Explore.`
              : `${clubName} was approved as Pending Teacher Supervisor.`,
          },
        });
      } else {
        await reviewClubReapplication({
          requestId: request.id,
          action,
          reviewNotes: notes || null,
        });
        navigate(listPath, {
          state: {
            success: `Updated ${clubName} to ${action}.`,
          },
        });
      }
    } catch (actionErr) {
      setActionError(
        getErrorMessage(actionErr, "Could not update the request."),
      );
    } finally {
      setBusy(false);
      setConfirmAction(null);
    }
  }

  if (loading) {
    return <LoadingScreen message="Loading re-application…" />;
  }

  if (error && !request) {
    return (
      <div className={embedded ? "exec-section" : "page"}>
        <p>
          <Link className="text-link" to={listPath}>
            ← Back to reapplications
          </Link>
        </p>
        <ErrorMessage>{error}</ErrorMessage>
      </div>
    );
  }

  if (!request) {
    return null;
  }

  const clubName =
    request.clubs?.name || request.club_name || "Unknown club";
  const canReview =
    canMutate &&
    request.status === "SUBMITTED";
  const hasListedSupervisor =
    !request.is_seeking_teacher_supervisor &&
    (request.club_reapplication_supervisors || []).length > 0;

  return (
    <div className={embedded ? "exec-section" : "page"}>
      <p className="exec-detail-back">
        <Link className="text-link" to={listPath}>
          ← Back to reapplications
        </Link>
      </p>

      <section className="admin-request-hero">
        <p className="admin-request-hero__eyebrow">Submitted</p>
        <div className="admin-request-hero__heading">
          <h2 className="exec-section__title">{clubName}</h2>
          <div className="admin-request-hero__status">
            <StatusBadge status={request.status} />
            {!canMutate ? (
              <span className="badge badge--role badge--role-sac-exec">
                Read only
              </span>
            ) : null}
          </div>
        </div>
        <div className="admin-request-hero__meta">
          <div>
            <span>Applicant</span>
            <strong>{request.applicant_email || "Not recorded"}</strong>
          </div>
          <span className="admin-request-hero__divider" aria-hidden="true" />
          <div>
            <span>Submitted</span>
            <strong>{formatDate(request.submitted_at || request.created_at)}</strong>
          </div>
        </div>
      </section>

      {actionError ? <ErrorMessage>{actionError}</ErrorMessage> : null}

      <article className="panel admin-request-card">
        <dl className="detail-list">
          <div className="detail-list__description">
            <dt>Description</dt>
            <dd>{request.description}</dd>
          </div>
          {request.owner_names ? (
            <div>
              <dt>Owners</dt>
              <dd>{request.owner_names}</dd>
            </div>
          ) : null}
          <div>
            <dt>Public email</dt>
            <dd>{request.public_email}</dd>
          </div>
          {request.member_application_url ? (
            <div>
              <dt>Member application</dt>
              <dd>
                <SafeExternalLink
                  className="text-link"
                  href={request.member_application_url}
                  fallback={<span className="muted">Unsafe link omitted</span>}
                >
                  Open link
                </SafeExternalLink>
              </dd>
            </div>
          ) : null}
          {request.exec_application_url ? (
            <div>
              <dt>Executive application</dt>
              <dd>
                <SafeExternalLink
                  className="text-link"
                  href={request.exec_application_url}
                  fallback={<span className="muted">Unsafe link omitted</span>}
                >
                  Open link
                </SafeExternalLink>
              </dd>
            </div>
          ) : null}
          <div>
            <dt>Instagram</dt>
            <dd>{request.instagram_handle || "—"}</dd>
          </div>
          <div>
            <dt>Meeting</dt>
            <dd>
              {request.meeting_frequency}
              {request.meeting_days?.length
                ? ` · ${request.meeting_days.join(", ")}`
                : ""}
              {request.meeting_time_details
                ? ` · ${request.meeting_time_details}`
                : ""}
              {request.meeting_location
                ? ` · ${request.meeting_location}`
                : ""}
            </dd>
          </div>
          {request.review_notes ? (
            <div>
              <dt>Review notes</dt>
              <dd>{request.review_notes}</dd>
            </div>
          ) : null}
        </dl>

        <section className="admin-request-subsection">
          <h3>Teacher supervisor information</h3>
          {(request.club_reapplication_supervisors || []).length > 0 ? (
            <div className="admin-request-subsection__grid">
              {request.club_reapplication_supervisors.map((supervisor) => (
                <div key={supervisor.id || supervisor.supervisor_email}>
                  <span>Supervisor</span>
                  <strong>
                    {supervisor.supervisor_name}
                    <br />
                    {supervisor.supervisor_email}
                  </strong>
                </div>
              ))}
            </div>
          ) : (
            <p className="muted">
              This club has not found a teacher supervisor yet.
            </p>
          )}
        </section>

        {(request.club_reapplication_attachments || []).map((att) => (
          <AttachmentPreview
            key={att.id}
            path={att.storage_path}
            getSignedUrl={createSignedClubDocumentUrl}
            mimeType={att.mime_type}
            filename={att.original_filename}
            alt={att.original_filename || "Re-application attachment"}
          />
        ))}

        {canReview ? (
          <div className="admin-request-review">
            <TextArea
              id="review-notes"
              label="Review notes"
              value={reviewNotes}
              onChange={(event) => setReviewNotes(event.target.value)}
              hint="Required when rejecting. Optional when approving."
            />
            <div className="button-row">
              <button
                type="button"
                className="button"
                disabled={busy}
                onClick={openApproveConfirm}
              >
                Approve
              </button>
              <button
                type="button"
                className="button button--danger"
                disabled={busy}
                onClick={() => {
                  if (!reviewNotes.trim()) {
                    setActionError(
                      "Review notes are required when rejecting.",
                    );
                    return;
                  }
                  setConfirmAction("REJECTED");
                }}
              >
                Reject
              </button>
            </div>
          </div>
        ) : null}
      </article>

      {confirmAction ? (
        <ConfirmDialog
          open
          title={
            confirmAction === "APPROVED"
              ? "Approve re-application?"
              : "Reject re-application?"
          }
          confirmLabel={confirmAction === "APPROVED" ? "Approve" : "Reject"}
          destructive={confirmAction === "REJECTED"}
          busy={busy}
          onCancel={() => setConfirmAction(null)}
          onConfirm={() =>
            runAction(confirmAction, confirmAction === "REJECTED")
          }
        >
          {confirmAction === "APPROVED" ? (
            <>
              <p className="admin-request-disclaimer">
                Approving replaces the club profile, clears prior memberships,
                and assigns the applicant as OWNER.
              </p>
              {!hasListedSupervisor ? (
                <p className="admin-request-disclaimer admin-request-disclaimer--warning">
                  This application indicates that the club is still looking for
                  a teacher supervisor. Approving it will mark the club as
                  Pending Teacher Supervisor, and it will not be posted publicly
                  until a supervisor is found.
                </p>
              ) : (
                <p className="admin-request-disclaimer admin-request-disclaimer--success">
                  This application includes teacher supervisor information.
                  Approving it will activate the club and post it publicly on
                  Explore.
                </p>
              )}
            </>
          ) : (
            <p>
              This will reject the request. The club can be re-selected later
              when it is eligible for re-application.
            </p>
          )}
        </ConfirmDialog>
      ) : null}
    </div>
  );
}
