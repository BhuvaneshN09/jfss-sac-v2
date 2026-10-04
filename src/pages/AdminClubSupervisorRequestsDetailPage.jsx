import { useCallback, useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { AttachmentPreview } from "../components/ui/AttachmentPreview";
import { ConfirmDialog } from "../components/ui/ConfirmDialog";
import { EmptyState } from "../components/ui/EmptyState";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { LoadingScreen } from "../components/ui/LoadingScreen";
import { PermissionNotice } from "../components/ui/PermissionNotice";
import { Spinner } from "../components/ui/Spinner";
import { StatusBadge } from "../components/ui/StatusBadge";
import { TextArea } from "../components/ui/TextArea";
import {
  createSignedSupervisorDocumentUrl,
  getClubSupervisorRequests,
  reviewClubSupervisorRequest,
} from "../services/clubSupervisors";
import { formatDate } from "../utils/format";
import { getErrorMessage } from "../utils/errors";

const OPEN_STATUSES = ["SUBMITTED", "UNDER_REVIEW", "CHANGES_REQUESTED"];

export function AdminClubSupervisorRequestsDetailPage({ embedded = false }) {
  const { clubId } = useParams();
  const { isSacAdmin, isSacExec } = useAuth();
  const canView = isSacAdmin || isSacExec;
  const canMutate = isSacAdmin;
  const [requests, setRequests] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [actionError, setActionError] = useState("");
  const [success, setSuccess] = useState("");
  const [notesById, setNotesById] = useState({});
  const [busyId, setBusyId] = useState(null);
  const [confirmAction, setConfirmAction] = useState(null);

  const loadRequests = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const data = await getClubSupervisorRequests(clubId);
      setRequests(data);
    } catch (loadError) {
      setError(
        getErrorMessage(loadError, "Could not load supervisor requests."),
      );
    } finally {
      setLoading(false);
    }
  }, [clubId]);

  useEffect(() => {
    if (!canView) return;
    // eslint-disable-next-line react-hooks/set-state-in-effect -- intentional async detail fetch
    loadRequests();
  }, [canView, loadRequests]);

  async function runAction(request, action) {
    const notes = (notesById[request.id] || "").trim();
    if (action === "REJECTED" && !notes) {
      setActionError("Review notes are required when rejecting.");
      return;
    }

    setBusyId(request.id);
    setActionError("");
    setSuccess("");
    try {
      await reviewClubSupervisorRequest({
        requestId: request.id,
        action,
        reviewNotes: notes || null,
      });
      setSuccess(
        action === "APPROVED"
          ? "Teacher supervisor request approved."
          : "Teacher supervisor request rejected.",
      );
      setConfirmAction(null);
      await loadRequests();
    } catch (actionErrorValue) {
      setActionError(
        getErrorMessage(actionErrorValue, "Could not update the request."),
      );
    } finally {
      setBusyId(null);
    }
  }

  if (!canView) {
    return (
      <PermissionNotice title="Exec access required">
        Supervisor request review is limited to SAC administrators and
        executives.
      </PermissionNotice>
    );
  }

  if (loading) {
    return <LoadingScreen message="Loading supervisor requests…" />;
  }

  const clubName = requests[0]?.clubs?.name || "Supervisor requests";

  return (
    <div className={embedded ? "exec-section" : "page"}>
      <p className="exec-detail-back">
        <Link
          className="text-link"
          to="/exec-dashboard/requests/supervisor"
        >
          ← Back to supervisor requests
        </Link>
      </p>

      <header className="page-header">
        <div>
          <p className="eyebrow">Teacher supervisor requests</p>
          <h1>{clubName}</h1>
        </div>
        {!canMutate ? (
          <span className="badge badge--role badge--role-sac-exec">
            Read only
          </span>
        ) : null}
      </header>

      {error ? <ErrorMessage>{error}</ErrorMessage> : null}
      {actionError ? <ErrorMessage>{actionError}</ErrorMessage> : null}
      {success ? (
        <div className="alert alert--success" role="status">
          {success}
        </div>
      ) : null}

      {requests.length === 0 ? (
        <EmptyState
          title="No supervisor requests"
          description="This club has no supervisor request history."
        />
      ) : (
        <div className="stack">
          {requests.map((request) => (
            <article
              key={request.id}
              className="club-supervisor-request-card"
            >
              <div className="club-supervisor-request-card__header">
                <strong>Submitted {formatDate(request.submitted_at)}</strong>
                <StatusBadge status={request.status} />
              </div>

              <dl className="detail-list">
                <div>
                  <dt>Requesting owner</dt>
                  <dd>
                    {request.submitter?.full_name ||
                      request.submitter?.email ||
                      "Unknown owner"}
                  </dd>
                </div>
                {(request.club_supervisor_request_supervisors || []).map(
                  (supervisor) => (
                    <div key={supervisor.id || supervisor.supervisor_email}>
                      <dt>Teacher</dt>
                      <dd>
                        {supervisor.supervisor_name}
                        <br />
                        <span className="muted">
                          {supervisor.supervisor_email}
                        </span>
                      </dd>
                    </div>
                  ),
                )}
                {request.review_notes ? (
                  <div>
                    <dt>Review notes</dt>
                    <dd>{request.review_notes}</dd>
                  </div>
                ) : null}
              </dl>

              {(request.club_supervisor_request_attachments || []).map(
                (attachment) => (
                  <AttachmentPreview
                    key={attachment.id}
                    path={attachment.storage_path}
                    getSignedUrl={createSignedSupervisorDocumentUrl}
                    mimeType={attachment.mime_type}
                    filename={attachment.original_filename}
                    alt={
                      attachment.original_filename ||
                      "Teacher signature attachment"
                    }
                  />
                ),
              )}

              {canMutate && OPEN_STATUSES.includes(request.status) ? (
                <>
                  <TextArea
                    id={`supervisor-notes-${request.id}`}
                    label="Review notes"
                    value={notesById[request.id] || ""}
                    onChange={(event) =>
                      setNotesById((current) => ({
                        ...current,
                        [request.id]: event.target.value,
                      }))
                    }
                    hint="Required when rejecting. Optional when approving."
                  />
                  <div className="button-row">
                    <button
                      type="button"
                      className="button"
                      disabled={busyId === request.id}
                      onClick={() =>
                        setConfirmAction({ request, action: "APPROVED" })
                      }
                    >
                      Approve
                    </button>
                    <button
                      type="button"
                      className="button button--danger"
                      disabled={busyId === request.id}
                      onClick={() => {
                        if (!(notesById[request.id] || "").trim()) {
                          setActionError(
                            "Review notes are required when rejecting.",
                          );
                          return;
                        }
                        setConfirmAction({ request, action: "REJECTED" });
                      }}
                    >
                      Reject
                    </button>
                    {busyId === request.id ? <Spinner /> : null}
                  </div>
                </>
              ) : null}
            </article>
          ))}
        </div>
      )}

      <ConfirmDialog
        open={Boolean(confirmAction)}
        title={
          confirmAction?.action === "APPROVED"
            ? "Approve supervisor request?"
            : "Reject supervisor request?"
        }
        confirmLabel={
          confirmAction?.action === "APPROVED" ? "Approve" : "Reject"
        }
        destructive={confirmAction?.action === "REJECTED"}
        busy={busyId === confirmAction?.request?.id}
        onCancel={() => {
          if (!busyId) setConfirmAction(null);
        }}
        onConfirm={() => {
          if (confirmAction) {
            void runAction(confirmAction.request, confirmAction.action);
          }
        }}
      >
        <p>
          {confirmAction?.action === "APPROVED"
            ? `Approve the teacher supervisor request for ${clubName}?`
            : `Reject the supervisor request for ${clubName}? Review notes are required.`}
        </p>
      </ConfirmDialog>
    </div>
  );
}
