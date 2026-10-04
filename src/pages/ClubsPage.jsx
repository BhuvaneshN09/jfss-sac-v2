import { useCallback, useEffect, useMemo, useState } from "react";
import { Link, useLocation } from "react-router-dom";
import { ClubCard } from "../components/clubs/ClubCard";
import { ClubGridSkeleton } from "../components/clubs/ClubGridSkeleton";
import { EmptyState } from "../components/ui/EmptyState";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { TextInput } from "../components/ui/TextInput";
import { getApprovedClubs } from "../services/clubs";
import { getConfirmedClubPromoLunchClubIds } from "../services/clubPromoLunch";
import {
  CLUB_EXPLORE_LOAD_MORE_COUNT,
  CLUB_EXPLORE_MOBILE_QUERY,
  getClubExploreInitialCount,
} from "../utils/clubExplore";
import { getErrorMessage } from "../utils/errors";

function readClubExploreInitialCount() {
  if (typeof window === "undefined") {
    return getClubExploreInitialCount(false);
  }
  return getClubExploreInitialCount(
    window.matchMedia(CLUB_EXPLORE_MOBILE_QUERY).matches,
  );
}

function formatCurrentlyActiveClubsNoun(count) {
  return count === 1 ? "club currently active" : "clubs currently active";
}

export function ClubsPage() {
  const location = useLocation();
  const [clubs, setClubs] = useState([]);
  const [search, setSearch] = useState("");
  const [promoLunchOnly, setPromoLunchOnly] = useState(false);
  const [promoLunchClubIds, setPromoLunchClubIds] = useState(() => new Set());
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState(location.state?.notice || "");
  const [initialCount, setInitialCount] = useState(readClubExploreInitialCount);
  const [visibleByFilter, setVisibleByFilter] = useState(() => ({
    key: "",
    count: readClubExploreInitialCount(),
  }));

  useEffect(() => {
    if (location.state?.notice) {
      // eslint-disable-next-line react-hooks/set-state-in-effect -- consume navigation feedback
      setNotice(location.state.notice);
      window.history.replaceState({}, document.title);
    }
  }, [location.state]);

  useEffect(() => {
    const media = window.matchMedia(CLUB_EXPLORE_MOBILE_QUERY);
    function syncInitialCount() {
      setInitialCount(getClubExploreInitialCount(media.matches));
    }
    syncInitialCount();
    media.addEventListener("change", syncInitialCount);
    return () => media.removeEventListener("change", syncInitialCount);
  }, []);

  const loadClubs = useCallback(async () => {
    setLoading(true);
    setError("");

    try {
      const [clubsResult, promoResult] = await Promise.allSettled([
        getApprovedClubs(),
        getConfirmedClubPromoLunchClubIds(),
      ]);
      if (clubsResult.status === "rejected") {
        throw clubsResult.reason;
      }
      setClubs(clubsResult.value);
      setPromoLunchClubIds(
        promoResult.status === "fulfilled"
          ? promoResult.value
          : new Set(),
      );
    } catch (loadError) {
      setError(getErrorMessage(loadError, "Could not load clubs."));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- intentional async clubs fetch
    loadClubs();
  }, [loadClubs]);

  const filtered = useMemo(() => {
    const query = search.trim().toLowerCase();
    return clubs.filter((club) => {
      if (promoLunchOnly && !promoLunchClubIds.has(club.id)) return false;
      if (!query) return true;
      const haystack = [
        club.name,
        club.description,
        club.short_description,
        club.instagram_handle,
        club.contact_email,
        club.meeting_location,
        club.meeting_schedule,
      ]
        .filter(Boolean)
        .join(" ")
        .toLowerCase();
      return haystack.includes(query);
    });
  }, [clubs, promoLunchClubIds, promoLunchOnly, search]);

  const filterKey = `${promoLunchOnly ? "1" : "0"}:${search}:${initialCount}`;
  if (visibleByFilter.key !== filterKey) {
    setVisibleByFilter({ key: filterKey, count: initialCount });
  }

  const visibleCount =
    visibleByFilter.key === filterKey ? visibleByFilter.count : initialCount;
  const visibleClubs = filtered.slice(0, visibleCount);
  const hasMore = visibleCount < filtered.length;

  const loadMore = useCallback(() => {
    setVisibleByFilter((current) => ({
      key: filterKey,
      count:
        current.key === filterKey
          ? current.count + CLUB_EXPLORE_LOAD_MORE_COUNT
          : initialCount + CLUB_EXPLORE_LOAD_MORE_COUNT,
    }));
  }, [filterKey, initialCount]);

  const activeClubCount = clubs.length;

  return (
    <div className="page">
      <div className="clubs-explore-controls">
        <div className="toolbar clubs-toolbar">
          <button
            type="button"
            className={`promo-lunch-filter${promoLunchOnly ? " promo-lunch-filter--active" : ""}`}
            aria-pressed={promoLunchOnly}
            disabled={loading}
            onClick={() => setPromoLunchOnly((active) => !active)}
          >
            {promoLunchOnly
              ? "Clubs confirmed for Club Promo Lunch"
              : "See clubs confirmed for Club Promo Lunch"}
          </button>
          <TextInput
            id="club-search"
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="Search by club name"
            disabled={loading}
          />
        </div>

        {!loading && !error ? (
          <p className="clubs-active-count" role="status" aria-live="polite">
            <span className="clubs-active-count__number">{activeClubCount}</span>
            <span className="clubs-active-count__label">
              {formatCurrentlyActiveClubsNoun(activeClubCount)}
            </span>
          </p>
        ) : null}
      </div>

      {notice ? (
        <div className="alert alert--success" role="status">
          <strong>Success</strong>
          <p>{notice}</p>
        </div>
      ) : null}

      {error ? (
        <div className="stack">
          <ErrorMessage>{error}</ErrorMessage>
          <button
            type="button"
            className="button button--secondary"
            onClick={loadClubs}
          >
            Retry
          </button>
        </div>
      ) : null}

      {loading ? <ClubGridSkeleton count={initialCount} /> : null}

      {!loading && !error && filtered.length === 0 ? (
        <EmptyState
          title="No clubs are currently available."
          action={
            <Link className="text-link" to="/">
              Back to home
            </Link>
          }
        >
          {search.trim()
            ? "No approved clubs match your search. Try a different name or clear the search."
            : promoLunchOnly
              ? "No clubs have been confirmed for Club Promo Lunch yet."
              : "There are no publicly active clubs to show right now. Check back after clubs are approved for this school year."}
        </EmptyState>
      ) : null}

      {!loading && !error && filtered.length > 0 ? (
        <>
          <div className="club-grid">
            {visibleClubs.map((club) => (
              <ClubCard key={club.id} club={club} />
            ))}
          </div>
          {hasMore ? (
            <div className="club-explore-more">
              <button
                type="button"
                className="button button--secondary"
                onClick={loadMore}
              >
                Load six more
              </button>
            </div>
          ) : null}
        </>
      ) : null}
    </div>
  );
}
