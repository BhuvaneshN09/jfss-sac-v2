/* eslint-disable react-hooks/set-state-in-effect */
import { useEffect, useState } from "react";
import { Link, Navigate, useLocation } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { AnnouncementCard } from "../components/announcements/AnnouncementCard";
import { EmptyState } from "../components/ui/EmptyState";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { LoadingScreen } from "../components/ui/LoadingScreen";
import { Select } from "../components/ui/Select";
import { getMyAnnouncements } from "../services/announcements";
import { canEditAnnouncement } from "../utils/announcementPermissions";
import { getErrorMessage } from "../utils/errors";

export function MyAnnouncementsPage({ embedded = false }) {
  const location = useLocation();
  const {
    user,
    isSacAdmin,
    isFacultyAdvisor,
    ownedClubs,
    canCreateAnnouncements,
  } = useAuth();
  const [announcements, setAnnouncements] = useState([]);
  const [status, setStatus] = useState("ALL");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState(location.state?.notice || "");

  useEffect(() => {
    if (location.state?.notice) {
      setNotice(location.state.notice);
      window.history.replaceState({}, document.title);
    }
  }, [location.state]);

  useEffect(() => {
    let active = true;

    async function load() {
      setLoading(true);
      setError("");

      try {
        const data = await getMyAnnouncements(user.id, { status });
        if (!active) return;
        setAnnouncements(data);
      } catch (loadError) {
        if (!active) return;
        setError(
          getErrorMessage(loadError, "Could not load your announcements."),
        );
      } finally {
        if (active) setLoading(false);
      }
    }

    load();
    return () => {
      active = false;
    };
  }, [user.id, status]);

  if (embedded && !canCreateAnnouncements) {
    return <Navigate to="/my-requests/applications" replace />;
  }

  if (loading) {
    return <LoadingScreen message="Loading your announcements…" />;
  }

  return (
    <div className={embedded ? "stack" : "page"}>
      {canCreateAnnouncements ? (
        <header className="page-header">
          <Link className="button button--primary" to="/announcements/new">
            Create Announcement
          </Link>
        </header>
      ) : null}

      {notice ? (
        <div className="alert alert--success" role="status">
          <strong>Success</strong>
          <p>{notice}</p>
        </div>
      ) : null}

      <div className="toolbar">
        <Select
          id="my-announcement-status"
          label="Filter by status"
          value={status}
          onChange={(event) => setStatus(event.target.value)}
        >
          <option value="ALL">All statuses</option>
          <option value="DRAFT">Draft</option>
          <option value="SUBMITTED">Submitted</option>
          <option value="UNDER_REVIEW">Under review</option>
          <option value="CHANGES_REQUESTED">Changes requested</option>
          <option value="PUBLISHED">Published</option>
          <option value="REJECTED">Rejected</option>
          <option value="CANCELLED">Cancelled</option>
          <option value="ARCHIVED">Archived</option>
        </Select>
      </div>

      {error ? <ErrorMessage>{error}</ErrorMessage> : null}

      {!error && announcements.length === 0 ? (
        <EmptyState title="No announcements yet">
          {canCreateAnnouncements
            ? "Submit a club announcement for review."
            : "You have not created any announcements."}
        </EmptyState>
      ) : (
        <div className="announcement-grid">
          {announcements.map((announcement) => {
            const canEdit = canEditAnnouncement({
              announcement,
              userId: user.id,
              isSacAdmin,
              isFacultyAdvisor,
              ownedClubs,
            });

            return (
              <AnnouncementCard
                key={announcement.id}
                announcement={announcement}
                showStatus
                actions={
                  canEdit ? (
                    <Link
                      className="text-link"
                      to={`/announcements/${announcement.id}/edit`}
                    >
                      Edit
                    </Link>
                  ) : null
                }
              />
            );
          })}
        </div>
      )}
    </div>
  );
}
