import { useEffect, useState } from "react";
import { useAuth } from "../../context/AuthContext";
import { AttachmentPreview } from "../ui/AttachmentPreview";
import { LocalFilePreview } from "../ui/LocalFilePreview";
import { FilePicker } from "../ui/FilePicker";
import { TextInput } from "../ui/TextInput";
import { ErrorMessage } from "../ui/ErrorMessage";
import { StatusBadge } from "../ui/StatusBadge";
import { Spinner } from "../ui/Spinner";
import {
  getClubSupervisorRequests,
  submitClubSupervisorRequest,
  uploadSupervisorDocument,
  deleteSupervisorDocument,
  validateSupervisorAttachmentFile,
  createSignedSupervisorDocumentUrl,
} from "../../services/clubSupervisors";
import { isValidPdsbEmail, normalizePdsbEmail } from "../../utils/clubPermissions";
import { formatDate } from "../../utils/format";
import { getErrorMessage } from "../../utils/errors";

export function ClubSupervisorSubmitForm({
  club,
  canSubmit = true,
  canView = false,
  onSubmitted,
}) {
  const { user } = useAuth();
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [signatureFile, setSignatureFile] = useState(null);
  const [history, setHistory] = useState([]);
  const [loadingHistory, setLoadingHistory] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");

  async function loadHistory() {
    if (!club?.id) return;
    setLoadingHistory(true);
    try {
      const rows = await getClubSupervisorRequests(club.id);
      setHistory(rows);
    } catch {
      setHistory([]);
    } finally {
      setLoadingHistory(false);
    }
  }

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- intentional async history fetch
    void loadHistory();
    // eslint-disable-next-line react-hooks/exhaustive-deps -- reload when club changes
  }, [club?.id]);

  async function handleSubmit(event) {
    event.preventDefault();
    if (busy || !canSubmit) return;

    setError("");
    setSuccess("");

    const trimmedName = String(name ?? "").trim();
    const normalizedEmail = normalizePdsbEmail(email);

    if (trimmedName.length < 2) {
      setError("Enter the teacher’s full name.");
      return;
    }

    if (!normalizedEmail || !isValidPdsbEmail(normalizedEmail)) {
      setError("Enter an exact @pdsb.net teacher email address.");
      return;
    }

    if (!signatureFile) {
      setError(
        "Attach the teacher signature document (JPEG, PNG, WebP, or PDF).",
      );
      return;
    }

    const fileError = validateSupervisorAttachmentFile(signatureFile);
    if (fileError) {
      setError(fileError);
      return;
    }

    if (!user?.id) {
      setError("You must be signed in to submit a supervisor request.");
      return;
    }

    setBusy(true);
    const requestId = crypto.randomUUID();
    let uploadedAttachmentPath = null;

    try {
      const attachment = await uploadSupervisorDocument({
        userId: user.id,
        requestId,
        file: signatureFile,
      });
      uploadedAttachmentPath = attachment.storage_path;

      await submitClubSupervisorRequest({
        requestId,
        clubId: club.id,
        supervisors: [{ name: trimmedName, email: normalizedEmail }],
        attachments: [attachment],
      });

      setSuccess(
        "Teacher supervisor request submitted for SAC admin review. It is not approved yet.",
      );
      setName("");
      setEmail("");
      setSignatureFile(null);
      await loadHistory();
      onSubmitted?.();
    } catch (submitError) {
      await deleteSupervisorDocument(uploadedAttachmentPath);
      setError(
        getErrorMessage(submitError, "Could not submit supervisor request."),
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="panel" aria-labelledby="supervisor-info-title">
      <h2 id="supervisor-info-title">Teacher supervisor request</h2>
      <p className="lede">
        Submit the teacher’s name, @pdsb.net email, and signature attachment for
        SAC approval. Teachers do not need a portal account.
      </p>

      {error ? <ErrorMessage>{error}</ErrorMessage> : null}
      {success ? (
        <div className="alert alert--success" role="status">
          <strong>Success</strong>
          <p>{success}</p>
        </div>
      ) : null}

      {canSubmit || canView ? (
        <form className="stack" onSubmit={handleSubmit} noValidate>
          {!canSubmit ? (
            <p className="alert alert--warning" role="status">
              You can view this form, but only an active owner of this club can
              submit teacher supervisor requests.
            </p>
          ) : null}
          <TextInput
            id="teacher-full-name"
            label="Teacher full name"
            value={name}
            onChange={(event) => setName(event.target.value)}
            required
            disabled={busy || !canSubmit}
            autoComplete="name"
          />
          <TextInput
            id="teacher-email"
            label="Teacher email"
            type="email"
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            required
            disabled={busy || !canSubmit}
            placeholder="p#######@pdsb.net"
            hint="Must be an exact @pdsb.net address."
            autoComplete="off"
          />

          <FilePicker
            id="teacher-signature"
            label="Teacher signature attachment"
            accept="image/jpeg,image/png,image/webp,application/pdf"
            required
            disabled={busy || !canSubmit}
            files={signatureFile}
            buttonLabel="Choose attachment"
            emptyLabel="No attachment chosen"
            hint="Required. Upload a JPEG, PNG, WebP, or PDF of the teacher signature (max 10 MB)."
            onChange={(next) => setSignatureFile(next)}
          />
          {signatureFile ? (
            <LocalFilePreview
              file={signatureFile}
              disabled={busy || !canSubmit}
              alt="Selected teacher signature"
              removeLabel="Remove attachment"
              onRemove={() => setSignatureFile(null)}
            />
          ) : null}

          {canSubmit ? (
            <div className="button-row">
              <button
                type="submit"
                className="button button--primary"
                disabled={busy}
              >
                {busy ? <Spinner size="sm" label="Submitting" /> : null}
                {busy ? "Submitting…" : "Submit supervisor request"}
              </button>
            </div>
          ) : null}
        </form>
      ) : (
        <p className="muted">
          Only active club owners can submit teacher supervisor requests.
        </p>
      )}

      <div className="stack" style={{ marginTop: "1.5rem" }}>
        <h3>Request status</h3>
        {loadingHistory ? (
          <p className="muted">Loading supervisor requests…</p>
        ) : history.length === 0 ? (
          <p className="muted">No supervisor requests yet.</p>
        ) : (
          <ul className="stack card-list">
            {history.map((row) => (
              <li key={row.id} className="club-supervisor-request-card">
                <div className="club-supervisor-request-card__header">
                  <strong>
                    Submitted {formatDate(row.submitted_at)}
                  </strong>
                  <StatusBadge status={row.status} />
                </div>
                <p>
                  {(row.club_supervisor_request_supervisors || [])
                    .map(
                      (supervisor) =>
                        `${supervisor.supervisor_name} <${supervisor.supervisor_email}>`,
                    )
                    .join("; ")}
                </p>
                {(row.club_supervisor_request_attachments || []).length > 0 ? (
                  <div className="stack">
                    {(row.club_supervisor_request_attachments || []).map(
                      (att) => (
                        <AttachmentPreview
                          key={att.id}
                          path={att.storage_path}
                          getSignedUrl={createSignedSupervisorDocumentUrl}
                          mimeType={att.mime_type}
                          filename={att.original_filename}
                          alt={
                            att.original_filename ||
                            "Teacher signature attachment"
                          }
                        />
                      ),
                    )}
                  </div>
                ) : (
                  <p className="muted">No signature attachment on file.</p>
                )}
                {row.review_notes ? (
                  <p>
                    <strong>Notes:</strong> {row.review_notes}
                  </p>
                ) : null}
              </li>
            ))}
          </ul>
        )}
      </div>
    </section>
  );
}
