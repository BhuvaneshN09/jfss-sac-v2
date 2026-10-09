/* eslint-disable react-hooks/set-state-in-effect */
import { useCallback, useEffect, useState } from "react";
import { HomeBanner } from "../components/home/HomeBanner";
import { HomeDayWeatherPanel } from "../components/home/HomeDayWeatherPanel";
import { HomeUpcomingEvent } from "../components/home/HomeUpcomingEvent";
import { HomepageAnnouncements } from "../components/announcements/HomepageAnnouncements";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { useAuth } from "../context/AuthContext";
import { getEffectiveSchoolDay } from "../services/schoolDay";
import { getMississaugaWeather } from "../services/weather";
import { getErrorMessage } from "../utils/errors";
import {
  getTorontoTodayYmd,
  msUntilNextTorontoMidnight,
} from "../utils/torontoDate";
import { HomeWhoWeAre } from "./WhoWeAreHomePage";

export function HomePage() {
  const { accessDenied, authError } = useAuth();

  const [schoolDay, setSchoolDay] = useState(null);
  const [schoolDayLoading, setSchoolDayLoading] = useState(true);
  const [schoolDayError, setSchoolDayError] = useState("");
  const [torontoDateKey, setTorontoDateKey] = useState(() =>
    getTorontoTodayYmd(),
  );

  const [weather, setWeather] = useState(null);
  const [weatherLoading, setWeatherLoading] = useState(true);
  const [weatherError, setWeatherError] = useState("");

  const loadSchoolDay = useCallback(async () => {
    setSchoolDayLoading(true);
    setSchoolDayError("");
    try {
      const data = await getEffectiveSchoolDay();
      setSchoolDay(data);
      if (data?.toronto_date) {
        setTorontoDateKey(data.toronto_date);
      }
    } catch (error) {
      setSchoolDayError(
        getErrorMessage(error, "Could not load today’s school day."),
      );
      setSchoolDay(null);
    } finally {
      setSchoolDayLoading(false);
    }
  }, []);

  const loadWeather = useCallback(async ({ force = false } = {}) => {
    setWeatherLoading(true);
    setWeatherError("");
    try {
      const data = await getMississaugaWeather({ force });
      setWeather(data);
      if (data.stale) {
        setWeatherError(data.staleError || "Weather refresh failed.");
      }
    } catch (error) {
      setWeather(null);
      setWeatherError(getErrorMessage(error, "Weather unavailable."));
    } finally {
      setWeatherLoading(false);
    }
  }, []);

  useEffect(() => {
    loadSchoolDay();
  }, [loadSchoolDay, torontoDateKey]);

  useEffect(() => {
    loadWeather();
  }, [loadWeather]);

  useEffect(() => {
    let midnightTimer = null;
    let pollTimer = null;

    function scheduleMidnightRefresh() {
      window.clearTimeout(midnightTimer);
      midnightTimer = window.setTimeout(() => {
        setTorontoDateKey(getTorontoTodayYmd());
        scheduleMidnightRefresh();
      }, msUntilNextTorontoMidnight());
    }

    scheduleMidnightRefresh();
    pollTimer = window.setInterval(() => {
      const today = getTorontoTodayYmd();
      setTorontoDateKey((current) => (current === today ? current : today));
    }, 60_000);

    return () => {
      window.clearTimeout(midnightTimer);
      window.clearInterval(pollTimer);
    };
  }, []);

  useEffect(() => {
    const interval = window.setInterval(() => {
      loadWeather({ force: true });
    }, 20 * 60 * 1000);

    function handleFocus() {
      loadWeather({ force: false });
    }

    function handleVisibility() {
      if (document.visibilityState === "visible") handleFocus();
    }

    window.addEventListener("focus", handleFocus);
    document.addEventListener("visibilitychange", handleVisibility);

    return () => {
      window.clearInterval(interval);
      window.removeEventListener("focus", handleFocus);
      document.removeEventListener("visibilitychange", handleVisibility);
    };
  }, [loadWeather]);

  return (
    <div className="page home-page">
      <HomeUpcomingEvent />

      <HomeBanner />

      {accessDenied && authError ? (
        <ErrorMessage title="Access denied">{authError}</ErrorMessage>
      ) : null}

      <HomeDayWeatherPanel
        schoolDay={schoolDay}
        schoolDayLoading={schoolDayLoading}
        schoolDayError={schoolDayError}
        weather={weather}
        weatherLoading={weatherLoading}
        weatherError={weatherError}
      />

      <HomeWhoWeAre />

      <HomepageAnnouncements limit={5} />
    </div>
  );
}
