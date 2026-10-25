import { useCallback, useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { getPublishedClubEvents } from "../../services/clubEvents";
import {
  diffCalendarDaysYmd,
  formatDateOnly,
  getTorontoTodayYmd,
  msUntilNextTorontoMidnight,
} from "../../utils/torontoDate";

const UPCOMING_WINDOW_DAYS = 15;
const CLUB_LOGO_URL = "/images/upcoming-event-club-logo.webp";

function getEventDateRange(event) {
  if (!event) return "";
  return event.event_date === event.event_end_date
    ? formatDateOnly(event.event_date)
    : `${formatDateOnly(event.event_date)} - ${formatDateOnly(event.event_end_date)}`;
}

function getUpcomingEvent(events, today) {
  const upcomingEvents = (events ?? [])
    .filter((event) => event.event_end_date >= today)
    .sort((first, second) =>
      first.event_date.localeCompare(second.event_date),
    );

  const nextEvent = upcomingEvents[0];
  const daysAway = diffCalendarDaysYmd(today, nextEvent?.event_date);

  if (daysAway == null || daysAway > UPCOMING_WINDOW_DAYS) {
    return null;
  }

  return {
    event: nextEvent,
    daysAway,
  };
}

export function HomeUpcomingEvent() {
  const [events, setEvents] = useState([]);
  const [today, setToday] = useState(() => getTorontoTodayYmd());

  const loadUpcomingEvent = useCallback(async () => {
    try {
      setEvents(await getPublishedClubEvents());
    } catch {
      setEvents([]);
    }
  }, []);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- intentional async event fetch
    loadUpcomingEvent();
  }, [loadUpcomingEvent]);

  useEffect(() => {
    let midnightTimer = null;
    let pollTimer = null;

    function refreshToday() {
      setToday(getTorontoTodayYmd());
    }

    function scheduleMidnightRefresh() {
      window.clearTimeout(midnightTimer);
      midnightTimer = window.setTimeout(() => {
        refreshToday();
        scheduleMidnightRefresh();
      }, msUntilNextTorontoMidnight());
    }

    scheduleMidnightRefresh();
    pollTimer = window.setInterval(refreshToday, 60_000);

    return () => {
      window.clearTimeout(midnightTimer);
      window.clearInterval(pollTimer);
    };
  }, []);

  const spotlight = getUpcomingEvent(events, today);

  if (!spotlight) return null;

  const { event, daysAway } = spotlight;
  const clubNames = event.club_names?.length
    ? event.club_names
    : [event.clubs?.name || event.club_name].filter(Boolean);
  const clubLogoUrl = event.club_logo_url || event.clubs?.logo_url || null;

  return (
    <section
      className="home-upcoming"
      aria-label="Upcoming event"
    >
      <div className="home-upcoming__inner">
        <div className="home-upcoming__event">
          <p className="home-upcoming__title-line">
            <span>{event.event_name}</span>
          </p>
          <p className="home-upcoming__countdown">
            <span>{daysAway} days away</span>
          </p>
        </div>
        <div className="home-upcoming__details">
          <div className="home-upcoming__clubs" aria-label="Hosting clubs">
            {clubNames.map((name) => (
              <span className="home-upcoming__club" key={name}>
                {name === event.club_name && clubLogoUrl ? (
                  <img
                    className="home-upcoming__club-logo"
                    src={clubLogoUrl}
                    alt=""
                    aria-hidden="true"
                  />
                ) : (
                  <span className="home-upcoming__club-logo home-upcoming__club-logo--letter">
                    {name.slice(0, 1).toUpperCase()}
                  </span>
                )}
                <span>{name}</span>
              </span>
            ))}
          </div>
          <div className="home-upcoming__date">
            <span className="home-upcoming__date-label">Date</span>
            <span>{getEventDateRange(event)}</span>
          </div>
          <Link className="home-upcoming__button" to="/events">
            View event
          </Link>
        </div>
      </div>
    </section>
  );
}
