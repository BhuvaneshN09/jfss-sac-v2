import { useCallback, useEffect, useState } from "react";
import { useAuth } from "../context/AuthContext";
import { ArchiveItemCard } from "../components/ui/ArchiveItemCard";
import { EmptyState } from "../components/ui/EmptyState";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { LoadingScreen } from "../components/ui/LoadingScreen";
import { PermissionNotice } from "../components/ui/PermissionNotice";
import { TextInput } from "../components/ui/TextInput";
import { listArchivedClubs } from "../services/clubs";
import { getErrorMessage } from "../utils/errors";

export function AdminArchivedClubsPage({ embedded = false }) {
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
      const data = await listArchivedClubs(search);
      setRows(data);
    } catch (loadError) {
      setError(getErrorMessage(loadError, "Could not load archived clubs."));
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
        Archived clubs are limited to SAC administrators and executives.
      </PermissionNotice>
    );
  }

  if (loading && rows.length === 0) {
    return <LoadingScreen message="Loading archived clubs…" />;
  }

  return (
    <div className={embedded ? "exec-section" : "page"}>
      {!embedded ? (
        <header className="page-header">
          <h1>Archived Clubs</h1>
        </header>
      ) : (
        <h2 className="exec-section__title">Archived Clubs</h2>
      )}

      {error ? <ErrorMessage>{error}</ErrorMessage> : null}

      <div className="toolbar">
        <TextInput
          id="archived-club-search"
          label="Search archived clubs"
          value={search}
          onChange={(event) => setSearch(event.target.value)}
        />
      </div>

      {rows.length === 0 ? (
        <EmptyState title="No archived clubs">
          Archived clubs appear here with their history preserved.
        </EmptyState>
      ) : (
        <div className="announcement-grid">
          {rows.map((row) => (
            <ArchiveItemCard
              key={row.club_id}
              title={row.name}
              description={row.description || row.short_description || ""}
              archivedAt={row.archived_at}
              detailTo={row.slug ? `/clubs/${row.slug}` : undefined}
            />
          ))}
        </div>
      )}
    </div>
  );
}
