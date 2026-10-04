import { useCallback, useEffect, useState } from "react";
import { useAuth } from "../context/AuthContext";
import { ArchiveItemCard } from "../components/ui/ArchiveItemCard";
import { EmptyState } from "../components/ui/EmptyState";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { LoadingScreen } from "../components/ui/LoadingScreen";
import { PermissionNotice } from "../components/ui/PermissionNotice";
import { TextInput } from "../components/ui/TextInput";
import { getArchivedAnnouncements } from "../services/announcements";
import { getErrorMessage } from "../utils/errors";

export function AdminArchivedAnnouncementsPage({ embedded = false }) {
  const { isSacAdmin, isSacExec } = useAuth();
  const canView = isSacAdmin || isSacExec;
  const [rows, setRows] = useState([]);
  const [search, setSearch] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const data = await getArchivedAnnouncements({ search });
      setRows(data);
    } catch (loadError) {
      setError(
        getErrorMessage(loadError, "Could not load archived announcements."),
      );
    } finally {
      setLoading(false);
    }
  }, [search]);

  useEffect(() => {
    if (!canView) return;
    const timer = setTimeout(() => {
      load();
    }, search ? 250 : 0);
    return () => clearTimeout(timer);
  }, [canView, load, search]);

  if (!canView) {
    return (
      <PermissionNotice title="Exec access required">
        Archived announcements are limited to SAC administrators and executives.
      </PermissionNotice>
    );
  }

  if (loading && rows.length === 0) {
    return <LoadingScreen message="Loading archived announcements…" />;
  }

  return (
    <div className={embedded ? "exec-section" : "page"}>
      {!embedded ? (
        <header className="page-header">
          <h1>Archived Announcements</h1>
        </header>
      ) : (
        <h2 className="exec-section__title">Archived Announcements</h2>
      )}

      {error ? <ErrorMessage>{error}</ErrorMessage> : null}

      <div className="toolbar">
        <TextInput
          id="archived-announcement-search"
          label="Search archived announcements"
          value={search}
          onChange={(event) => setSearch(event.target.value)}
        />
      </div>

      {!error && rows.length === 0 ? (
        <EmptyState title="No archived announcements">
          Completed posts will appear here after their posting day ends.
        </EmptyState>
      ) : (
        <div className="announcement-grid">
          {rows.map((announcement) => (
            <ArchiveItemCard
              key={announcement.id}
              title={announcement.title}
              description={
                announcement.body?.trim() ||
                announcement.summary?.trim() ||
                ""
              }
              archivedAt={announcement.archived_at}
            />
          ))}
        </div>
      )}
    </div>
  );
}
