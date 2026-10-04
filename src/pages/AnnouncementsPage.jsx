import { useEffect, useRef, useState } from "react";
import { Link } from "react-router-dom";
import { AnnouncementCard } from "../components/announcements/AnnouncementCard";
import { EmptyState } from "../components/ui/EmptyState";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { LoadingScreen } from "../components/ui/LoadingScreen";
import { Select } from "../components/ui/Select";
import { getPublishedAnnouncements } from "../services/announcements";
import { getErrorMessage } from "../utils/errors";

const PAGE_SIZE = 5;

export function AnnouncementsPage() {
  const [announcements, setAnnouncements] = useState([]);
  const [type, setType] = useState("ALL");
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState("");
  const [hasMore, setHasMore] = useState(false);
  const requestGenerationRef = useRef(0);

  useEffect(() => {
    let active = true;
    const generation = ++requestGenerationRef.current;
    // eslint-disable-next-line react-hooks/set-state-in-effect -- reset pagination state when the filter changes
    setLoadingMore(false);

    async function load() {
      setLoading(true);
      setError("");

      try {
        const data = await getPublishedAnnouncements({
          type,
          limit: PAGE_SIZE,
          offset: 0,
        });
        if (!active || requestGenerationRef.current !== generation) return;
        setAnnouncements(data);
        setHasMore(data.length === PAGE_SIZE);
      } catch (loadError) {
        if (!active || requestGenerationRef.current !== generation) return;
        setError(getErrorMessage(loadError, "Could not load announcements."));
      } finally {
        if (active) setLoading(false);
      }
    }

    load();
    return () => {
      active = false;
    };
  }, [type]);

  async function loadMore() {
    const generation = requestGenerationRef.current;
    setLoadingMore(true);
    setError("");

    try {
      const data = await getPublishedAnnouncements({
        type,
        limit: PAGE_SIZE,
        offset: announcements.length,
      });
      if (requestGenerationRef.current !== generation) return;
      setAnnouncements((current) => [...current, ...data]);
      setHasMore(data.length === PAGE_SIZE);
    } catch (loadError) {
      if (requestGenerationRef.current === generation) {
        setError(getErrorMessage(loadError, "Could not load more announcements."));
      }
    } finally {
      if (requestGenerationRef.current === generation) setLoadingMore(false);
    }
  }

  if (loading) {
    return <LoadingScreen message="Loading announcements…" />;
  }

  return (
    <div className="page">
      <div className="toolbar">
        <Select
          id="announcement-type-filter"
          label="Filter by type"
          value={type}
          onChange={(event) => setType(event.target.value)}
        >
          <option value="ALL">All</option>
          <option value="PUBLIC">Public</option>
          <option value="CLUB">Club</option>
        </Select>
      </div>

      {error ? <ErrorMessage>{error}</ErrorMessage> : null}

      {!error && announcements.length === 0 ? (
        <EmptyState title="No announcements yet">
          There are no published announcements to show right now.
        </EmptyState>
      ) : (
        <div className="announcement-grid">
          {announcements.map((announcement) => (
            <AnnouncementCard
              key={announcement.id}
              announcement={announcement}
            />
          ))}
        </div>
      )}

      {hasMore ? (
        <div className="button-row">
          <button
            type="button"
            className="button button--secondary"
            onClick={loadMore}
            disabled={loadingMore}
          >
            {loadingMore ? "Loading…" : "See more"}
          </button>
        </div>
      ) : null}

      <p className="note">
        Looking for clubs?{" "}
        <Link className="text-link" to="/clubs">
          Browse approved clubs
        </Link>
        .
      </p>
    </div>
  );
}
