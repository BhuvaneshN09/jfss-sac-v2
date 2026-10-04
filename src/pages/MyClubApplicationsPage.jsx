import { useCallback, useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { EmptyState } from "../components/ui/EmptyState";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { LoadingScreen } from "../components/ui/LoadingScreen";
import { RequestCard } from "../components/clubs/RequestCard";
import {
  getMyClubRequests,
} from "../services/clubRequests";
import { getClubById } from "../services/clubs";
import { getErrorMessage } from "../utils/errors";

const PAGE_SIZE = 5;

export function MyClubApplicationsPage() {
  const { user } = useAuth();
  const [requests, setRequests] = useState([]);
  const [clubSlugs, setClubSlugs] = useState({});
  const [missingClubs, setMissingClubs] = useState({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [visibleCount, setVisibleCount] = useState(PAGE_SIZE);

  const loadRequests = useCallback(async () => {
    setLoading(true);
    setError("");

    try {
      const data = await getMyClubRequests(user.id);
      setRequests(data);
      setVisibleCount(PAGE_SIZE);

      const approved = data.filter((request) => request.created_club_id);
      const slugEntries = await Promise.all(
        approved.map(async (request) => {
          try {
            const club = await getClubById(request.created_club_id);
            return [request.created_club_id, club?.slug ?? null, !club];
          } catch {
            return [request.created_club_id, null, true];
          }
        }),
      );
      setClubSlugs(
        Object.fromEntries(slugEntries.map(([id, slug]) => [id, slug])),
      );
      setMissingClubs(
        Object.fromEntries(
          slugEntries.map(([id, , missing]) => [id, Boolean(missing)]),
        ),
      );
    } catch (loadError) {
      setError(
        getErrorMessage(loadError, "Could not load your club applications."),
      );
    } finally {
      setLoading(false);
    }
  }, [user.id]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- load request data on mount
    loadRequests();
  }, [loadRequests]);

  if (loading) {
    return <LoadingScreen message="Loading club applications…" />;
  }

  const visible = requests.slice(0, visibleCount);
  const hasMore = visibleCount < requests.length;

  return (
    <div className="stack">
      <header className="page-header">
        <Link className="button button--secondary" to="/clubs/apply">
          Create a new club
        </Link>
      </header>

      {error ? <ErrorMessage>{error}</ErrorMessage> : null}

      {!error && requests.length === 0 ? (
        <EmptyState title="No club applications yet">
          Start a new club application to see it tracked here.
        </EmptyState>
      ) : null}

      {visible.map((request) => {
        return (
          <RequestCard
            key={request.id}
            request={request}
            createdClubSlug={clubSlugs[request.created_club_id]}
            createdClubMissing={
              !request.created_club_id ||
              Boolean(missingClubs[request.created_club_id])
            }
          />
        );
      })}

      {hasMore ? (
        <div className="button-row">
          <button
            type="button"
            className="button button--secondary"
            onClick={() => setVisibleCount((current) => current + PAGE_SIZE)}
          >
            View more
          </button>
        </div>
      ) : null}
    </div>
  );
}
