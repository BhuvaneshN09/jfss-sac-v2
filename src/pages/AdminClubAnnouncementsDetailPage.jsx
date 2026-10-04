import { useCallback, useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { AnnouncementStatusBadge } from "../components/announcements/AnnouncementStatusBadge";
import { AnnouncementTypeBadge } from "../components/announcements/AnnouncementTypeBadge";
import { ReviewAnnouncementDialog } from "../components/announcements/ReviewAnnouncementDialog";
import { EmptyState } from "../components/ui/EmptyState";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { LoadingScreen } from "../components/ui/LoadingScreen";
import {
  getAnnouncementReviewQueueForClub,
  reviewAnnouncement,
} from "../services/announcements";
import { formatDate } from "../utils/format";
import {
  formatDateOnly,
  getPostingUrgency,
  getTorontoTodayYmd,
} from "../utils/torontoDate";
import { getErrorMessage } from "../utils/errors";

export function AdminClubAnnouncementsDetailPage({ embedded = false }) {
  const { clubId } = useParams();
  const { canMutateReviews } = useAuth();
  const readOnly = !canMutateReviews;
  const [announcements, setAnnouncements] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [actionError, setActionError] = useState("");
  const [success, setSuccess] = useState("");
  const [busyId, setBusyId] = useState(null);
  const [reviewDialog, setReviewDialog] = useState(null);

  const loadQueue = useCallback(async () => {
    setLoading(true);
    setError("");

    try {
      const data = await getAnnouncementReviewQueueForClub(
        clubId === "general" ? null : clubId,
      );
      setAnnouncements(data);
    } catch (loadError) {
      setError(
        getErrorMessage(loadError, "Could not load announcement requests."),
      );
    } finally {
      setLoading(false);
    }
  }, [clubId]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- intentional async detail fetch
    loadQueue();
  }, [loadQueue]);

  async function confirmReview(notes) {
    if (!reviewDialog || readOnly) return;

    const { announcement, action } = reviewDialog;
    setBusyId(announcement.id);
    setActionError("");
    setSuccess("");

    try {
      await reviewAnnouncement(announcement.id, action, notes);
      setSuccess(
        action === "PUBLISH"
          ? announcement.scheduled_posting_date === getTorontoTodayYmd()
            ? `Approved “${announcement.title}”. It is live on the public board now.`
            : `Approved “${announcement.title}”. It will appear on the public board on its posting date.`
          : `Updated “${announcement.title}” to ${action}.`,
      );
      setReviewDialog(null);
      await loadQueue();
    } catch (actionErrorValue) {
      setActionError(
        getErrorMessage(actionErrorValue, "Could not review the announcement."),
      );
    } finally {
      setBusyId(null);
    }
  }

  if (loading) {
    return <LoadingScreen message="Loading announcement requests…" />;
  }

  const clubName =
    announcements[0]?.clubs?.name ||
    (clubId === "general" ? "General announcements" : "Announcement requests");

  return (
    <div className={embedded ? "exec-section" : "page"}>
      <p className="exec-detail-back">
        <Link
          className="text-link"
          to="/exec-dashboard/requests/announcements"
        >
          ← Back to announcements
        </Link>
      </p>

      <header className="page-header">
        <div>
          <p className="eyebrow">Announcement requests</p>
          <h1>{clubName}</h1>
        </div>
        {readOnly ? (
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

      {announcements.length === 0 ? (
        <EmptyState
          title="No announcement requests"
          description="This club has no announcement requests awaiting review."
        />
      ) : (
        <div className="stack">
          {announcements.map((announcement) => {
            const urgency = getPostingUrgency(
              announcement.scheduled_posting_date,
            );
            const isBusy = busyId === announcement.id;

            return (
              <article key={announcement.id} className="panel admin-request-card">
                <div className="section-heading">
                  <div>
                    <h2>{announcement.title}</h2>
                    <div className="badge-row">
                      <AnnouncementStatusBadge status={announcement.status} />
                      <AnnouncementTypeBadge club={announcement.clubs} />
                    </div>
                  </div>
                  <div className="announcement-request-card__aside">
                    {announcement.scheduled_posting_date ? (
                      <span
                        className={`urgency-text urgency-text--${urgency.tone}`}
                      >
                        {urgency.label}
                      </span>
                    ) : (
                      <span className="urgency-text urgency-text--danger">
                        Posting date required
                      </span>
                    )}
                  </div>
                </div>

                <div className="announcement-request-card__content">
                  <div className="announcement-request-card__field">
                    <strong>Description</strong>
                    <p className="prose">{announcement.body}</p>
                  </div>
                  {announcement.summary ? (
                    <div className="announcement-request-card__field">
                      <strong>Summary</strong>
                      <p className="prose">{announcement.summary}</p>
                    </div>
                  ) : null}
                </div>

                <dl className="meta-list">
                  <div>
                    <dt>Submitted by</dt>
                    <dd>{announcement.submitter?.email || "Email unavailable"}</dd>
                  </div>
                  <div>
                    <dt>Visibility</dt>
                    <dd>
                      {announcement.visibility === "CLUB_MEMBERS"
                        ? "Club members only"
                        : "Everyone"}
                    </dd>
                  </div>
                  <div>
                    <dt>Submitted</dt>
                    <dd>{formatDate(announcement.submitted_at)}</dd>
                  </div>
                </dl>

                {announcement.review_notes ? (
                  <div className="alert alert--warning" role="status">
                    <strong>Current review notes</strong>
                    <p>{announcement.review_notes}</p>
                  </div>
                ) : null}

                <div className="announcement-request-card__footer">
                  {!readOnly ? (
                    <div className="button-row">
                      <button
                        type="button"
                        className="button button--danger"
                        disabled={
                          isBusy ||
                          !["SUBMITTED", "UNDER_REVIEW"].includes(
                            announcement.status,
                          )
                        }
                        onClick={() =>
                          setReviewDialog({
                            announcement,
                            action: "REJECTED",
                            title: "Reject announcement",
                            confirmLabel: "Reject",
                            requireNotes: true,
                          })
                        }
                      >
                        Reject
                      </button>
                      <button
                        type="button"
                        className="button button--primary"
                        disabled={
                          isBusy ||
                          !["SUBMITTED", "UNDER_REVIEW"].includes(
                            announcement.status,
                          ) ||
                          !announcement.scheduled_posting_date
                        }
                        onClick={() =>
                          setReviewDialog({
                            announcement,
                            action: "PUBLISH",
                            title: "Approve announcement",
                            confirmLabel: "Approve",
                            requireNotes: false,
                          })
                        }
                      >
                        Approve
                      </button>
                    </div>
                  ) : null}
                  {announcement.scheduled_posting_date ? (
                    <time
                      className="announcement-request-card__posting-date"
                      dateTime={announcement.scheduled_posting_date}
                    >
                      <span>Posting date</span>
                      {formatDateOnly(announcement.scheduled_posting_date)}
                    </time>
                  ) : null}
                </div>
              </article>
            );
          })}
        </div>
      )}

      <ReviewAnnouncementDialog
        open={Boolean(reviewDialog)}
        title={reviewDialog?.title || ""}
        confirmLabel={reviewDialog?.confirmLabel || "Confirm"}
        requireNotes={Boolean(reviewDialog?.requireNotes)}
        onCancel={() => setReviewDialog(null)}
        onConfirm={confirmReview}
        busy={Boolean(reviewDialog && busyId === reviewDialog.announcement.id)}
      />
    </div>
  );
}
