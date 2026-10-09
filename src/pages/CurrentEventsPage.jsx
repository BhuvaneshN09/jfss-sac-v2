import { useCallback, useEffect, useState } from "react";
import { EventCard } from "../components/events/EventCard";
import { EmptyState } from "../components/ui/EmptyState";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { LoadingScreen } from "../components/ui/LoadingScreen";
import { getPublishedClubEvents } from "../services/clubEvents";
import { formatDateOnly, getTorontoTodayYmd } from "../utils/torontoDate";
import { getErrorMessage } from "../utils/errors";

function formatEventDateRange(startDate, endDate) {
  const startLabel = formatDateOnly(startDate);
  return startDate === endDate
    ? startLabel
    : `${startLabel} – ${formatDateOnly(endDate)}`;
}

export function CurrentEventsPage() {
  const [events, setEvents] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [activeTab, setActiveTab] = useState("upcoming");

  const loadEvents = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      setEvents(await getPublishedClubEvents());
    } catch (loadError) {
      setError(getErrorMessage(loadError, "Could not load events."));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- intentional async event fetch
    loadEvents();
  }, [loadEvents]);

  if (loading) {
    return <LoadingScreen message="Loading events…" />;
  }

  const today = getTorontoTodayYmd();
  const upcomingEvents = events.filter(
    (event) => event.event_end_date >= today,
  );
  const pastEvents = events.filter((event) => event.event_end_date < today);
  const visibleEvents =
    activeTab === "upcoming" ? upcomingEvents : pastEvents;

  return (
    <div className="team-page">
      <div className="team-header">
        <h1 className="team-title">Events</h1>
        <p className="team-subtitle">
          Discover events organized by clubs at John Fraser.
        </p>
      </div>

      {error ? <ErrorMessage>{error}</ErrorMessage> : null}
      <nav
        className="subtabs event-tabs"
        aria-label="Event categories"
        role="tablist"
      >
        <button
          type="button"
          role="tab"
          aria-selected={activeTab === "upcoming"}
          aria-controls="upcoming-events-panel"
          className={
            activeTab === "upcoming" ? "subtab subtab--active" : "subtab"
          }
          onClick={() => setActiveTab("upcoming")}
        >
          Upcoming
        </button>
        <button
          type="button"
          role="tab"
          aria-selected={activeTab === "past"}
          aria-controls="past-events-panel"
          className={activeTab === "past" ? "subtab subtab--active" : "subtab"}
          onClick={() => setActiveTab("past")}
        >
          Past
        </button>
      </nav>

      {!error && visibleEvents.length === 0 ? (
        <EmptyState
          title={`No ${activeTab} events`}
          description={`Approved ${activeTab} events will appear here.`}
        />
      ) : (
        <div
          id={`${activeTab}-events-panel`}
          className="event-list"
          role="tabpanel"
          aria-label={`${activeTab} events`}
        >
          {visibleEvents.map((event) => (
            <EventCard
              key={event.id}
              event={{
                date: formatEventDateRange(
                  event.event_date,
                  event.event_end_date,
                ),
                title: event.event_name,
                description: event.event_description,
                photo: event.photo_url,
                clubName: event.clubs?.name,
                clubNames: event.club_names,
              }}
            />
          ))}
        </div>
      )}
    </div>
  );
}
