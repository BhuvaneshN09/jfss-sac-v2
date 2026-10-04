import { useCallback, useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { ConfirmDialog } from "../components/ui/ConfirmDialog";
import { EmptyState } from "../components/ui/EmptyState";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { LoadingScreen } from "../components/ui/LoadingScreen";
import { PermissionNotice } from "../components/ui/PermissionNotice";
import { TextArea } from "../components/ui/TextArea";
import { TextInput } from "../components/ui/TextInput";
import { Spinner } from "../components/ui/Spinner";
import {
  adminRejectPendingSupervisorClub,
  defaultSupervisorDeadlineLocalValue,
  extendClubSupervisorDeadline,
  getAdminSupervisorRequestQueue,
  listSupervisorWatchClubs,
  localDateTimeValueToIso,
} from "../services/clubSupervisors";
import { formatDeadlineRelative } from "../utils/format";
import { getErrorMessage } from "../utils/errors";

function sortPendingClubs(rows) {
  return [...(rows || [])].sort((a, b) => {
    const aDue = a.supervisor_due_at
      ? new Date(a.supervisor_due_at).getTime()
      : Number.POSITIVE_INFINITY;
    const bDue = b.supervisor_due_at
      ? new Date(b.supervisor_due_at).getTime()
      : Number.POSITIVE_INFINITY;
    if (aDue !== bDue) return aDue - bDue;
    return String(a.name || "").localeCompare(String(b.name || ""));
  });
}

export function AdminSupervisorRequestsPage({ embedded = false }) {
  const { isSacAdmin, isSacExec } = useAuth();
  const canView = isSacAdmin || isSacExec;
  const canMutate = isSacAdmin;
  const [requests, setRequests] = useState([]);
  const [pendingClubs, setPendingClubs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [busyId, setBusyId] = useState(null);
  const [extendTarget, setExtendTarget] = useState(null);
  const [rejectTarget, setRejectTarget] = useState(null);
  const [dueLocal, setDueLocal] = useState(defaultSupervisorDeadlineLocalValue());
  const [rejectNotes, setRejectNotes] = useState("");
  const [nowMs] = useState(() => Date.now());

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const [queue, pending] = await Promise.all([
        getAdminSupervisorRequestQueue({ status: "ALL" }),
        listSupervisorWatchClubs("PENDING"),
      ]);
      setRequests(queue);
      setPendingClubs(sortPendingClubs(pending));
    } catch (loadError) {
      setError(
        getErrorMessage(loadError, "Could not load supervisor requests."),
      );
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (!canView) return;
    // eslint-disable-next-line react-hooks/set-state-in-effect -- intentional async queue fetch
    load();
  }, [canView, load]);

  const sortedPending = useMemo(() => {
    const clubsWithOpenRequests = new Set(
      (requests || [])
        .filter((row) =>
          ["SUBMITTED", "UNDER_REVIEW", "CHANGES_REQUESTED"].includes(
            row.status,
          ),
        )
        .map((row) => row.club_id)
        .filter(Boolean),
    );

    return sortPendingClubs(pendingClubs).filter((row) => {
      if (clubsWithOpenRequests.has(row.club_id)) return false;
      // Also hide when the watch list reports an open package, even if the
      // request queue query lags or filters differently.
      return !["SUBMITTED", "UNDER_REVIEW", "CHANGES_REQUESTED"].includes(
        row.supervisor_request_status,
      );
    });
  }, [pendingClubs, requests]);

  const requestClubs = useMemo(() => {
    const clubs = new Map();
    for (const request of requests) {
      if (!request.club_id || clubs.has(request.club_id)) continue;
      clubs.set(request.club_id, {
        id: request.club_id,
        name: request.clubs?.name || "Club",
      });
    }
    return [...clubs.values()].sort((a, b) =>
      a.name.localeCompare(b.name),
    );
  }, [requests]);

  if (!canView) {
    return (
      <PermissionNotice title="Exec access required">
        Supervisor request review is limited to SAC administrators and
        executives.
      </PermissionNotice>
    );
  }

  async function confirmExtend() {
    if (!extendTarget) return;
    const iso = localDateTimeValueToIso(dueLocal);
    if (!iso) {
      setError("Choose a valid future deadline.");
      return;
    }
    setBusyId(extendTarget.club_id);
    setError("");
    setSuccess("");
    try {
      await extendClubSupervisorDeadline({
        clubId: extendTarget.club_id,
        newDueAt: iso,
      });
      setSuccess(`Deadline extended for ${extendTarget.name}.`);
      setExtendTarget(null);
      await load();
    } catch (actionError) {
      setError(getErrorMessage(actionError, "Could not change deadline."));
    } finally {
      setBusyId(null);
    }
  }

  async function confirmRejectPending() {
    if (!rejectTarget) return;
    const notes = rejectNotes.trim();
    if (!notes) {
      setError("Review notes are required when rejecting.");
      return;
    }
    setBusyId(rejectTarget.club_id);
    setError("");
    setSuccess("");
    try {
      await adminRejectPendingSupervisorClub({
        clubId: rejectTarget.club_id,
        reviewNotes: notes,
      });
      setSuccess(
        `${rejectTarget.name} was rejected and returned to inactive / reapply-eligible.`,
      );
      setRejectTarget(null);
      setRejectNotes("");
      await load();
    } catch (actionError) {
      setError(getErrorMessage(actionError, "Could not reject this club."));
    } finally {
      setBusyId(null);
    }
  }

  if (loading && requests.length === 0 && pendingClubs.length === 0) {
    return <LoadingScreen message="Loading supervisor requests…" />;
  }

  return (
    <div className={embedded ? "exec-section" : "page"}>
      {!embedded ? (
        <header className="page-header">
          <h1>Supervisor Requests</h1>
        </header>
      ) : (
        <div className="section-heading-row">
          <h2>Supervisor Requests</h2>
          {!canMutate ? (
            <span className="badge badge--role badge--role-sac-exec">
              Read only
            </span>
          ) : null}
        </div>
      )}

      {error ? <ErrorMessage>{error}</ErrorMessage> : null}
      {success ? (
        <div className="alert alert--success" role="status">
          {success}
        </div>
      ) : null}

      <div className="supervisor-split">
        <header className="supervisor-split__intro supervisor-split__intro--requests">
          <h3 id="supervisor-requests-heading">Requests</h3>
          <p className="muted">
            Teacher supervisor packages submitted by club owners for SAC review.
          </p>
        </header>

        <header className="supervisor-split__intro supervisor-split__intro--pending">
          <h3 id="supervisor-pending-heading">Pending</h3>
          <p className="muted">
            Clubs with annual status Pending Supervisor. Sorted by deadline
            (most overdue first; missing deadlines last).
          </p>
        </header>

        <section
          className="stack supervisor-split__body supervisor-split__body--requests"
          aria-labelledby="supervisor-requests-heading"
        >
          {requestClubs.length === 0 ? (
            <EmptyState
              title="No supervisor requests"
              description="Owner-submitted teacher supervisor packages appear here."
            />
          ) : (
            <div className="exec-queue-list">
              {requestClubs.map((club) => (
                <Link
                  key={club.id}
                  className="exec-queue-card"
                  to={`/exec-dashboard/requests/supervisor/${club.id}`}
                >
                  <div className="exec-queue-card__main">
                    <h3 className="exec-queue-card__title">{club.name}</h3>
                  </div>
                </Link>
              ))}
            </div>
          )}
        </section>

        <section
          className="stack supervisor-split__body supervisor-split__body--pending"
          aria-labelledby="supervisor-pending-heading"
        >
          {sortedPending.length === 0 ? (
            <EmptyState
              title="No pending supervisor clubs"
              description="Clubs waiting on a teacher supervisor appear here."
            />
          ) : (
            <ul className="stack card-list">
              {sortedPending.map((row) => {
                const relative = formatDeadlineRelative(
                  row.supervisor_due_at,
                  nowMs,
                );
                return (
                  <li
                    key={row.club_id}
                    className="pending-supervisor-card"
                  >
                    <div className="pending-supervisor-card__header">
                      <Link
                        className="pending-supervisor-card__club"
                        to={`/clubs/${row.slug}`}
                      >
                        <h3>{row.name}</h3>
                      </Link>
                      <span
                        className={`badge ${
                          row.is_overdue ? "badge--warning" : "badge--info"
                        }`}
                      >
                        {relative}
                      </span>
                    </div>
                    {canMutate ? (
                      <div className="button-row">
                        <button
                          type="button"
                          className="button button--secondary"
                          disabled={busyId === row.club_id}
                          onClick={() => {
                            setDueLocal(
                              defaultSupervisorDeadlineLocalValue(
                                row.supervisor_due_at
                                  ? new Date(row.supervisor_due_at)
                                  : new Date(),
                              ),
                            );
                            setExtendTarget(row);
                          }}
                        >
                          Change Deadline
                        </button>
                        <button
                          type="button"
                          className="button button--danger"
                          disabled={busyId === row.club_id}
                          onClick={() => {
                            setRejectNotes("");
                            setRejectTarget(row);
                          }}
                        >
                          Reject Club
                        </button>
                        {busyId === row.club_id ? <Spinner /> : null}
                      </div>
                    ) : null}
                  </li>
                );
              })}
            </ul>
          )}
        </section>
      </div>

      <ConfirmDialog
        open={Boolean(extendTarget)}
        title="Extend supervisor deadline"
        confirmLabel="Change deadline"
        busy={busyId === extendTarget?.club_id}
        onCancel={() => setExtendTarget(null)}
        onConfirm={confirmExtend}
      >
        <p>
          Extend the teacher supervisor deadline for{" "}
          <strong>{extendTarget?.name}</strong>.
        </p>
        <TextInput
          id="extend-due-at"
          label="New deadline"
          type="datetime-local"
          value={dueLocal}
          onChange={(event) => setDueLocal(event.target.value)}
          required
        />
      </ConfirmDialog>

      <ConfirmDialog
        open={Boolean(rejectTarget)}
        title="Reject pending club?"
        confirmLabel="Reject club"
        destructive
        busy={busyId === rejectTarget?.club_id}
        confirmDisabled={!rejectNotes.trim()}
        onCancel={() => setRejectTarget(null)}
        onConfirm={confirmRejectPending}
      >
        <p>
          This returns <strong>{rejectTarget?.name}</strong> to inactive status,
          rejects the approved re-application, and clears active memberships.
          History is preserved and the club stays available for future
          re-application.
        </p>
        <TextArea
          id="reject-notes"
          label="Review notes"
          value={rejectNotes}
          onChange={(event) => setRejectNotes(event.target.value)}
          required
          hint="Required when rejecting."
        />
      </ConfirmDialog>
    </div>
  );
}
