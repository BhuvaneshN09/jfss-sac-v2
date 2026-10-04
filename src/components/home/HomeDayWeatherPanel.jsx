import { buildDaySchedule, formatBellTime } from "../../utils/schoolSchedule";

function WeatherGlyph({ iconKey }) {
  const common = {
    viewBox: "0 0 24 24",
    width: "1.75rem",
    height: "1.75rem",
    fill: "none",
    stroke: "currentColor",
    strokeWidth: "1.75",
    strokeLinecap: "round",
    strokeLinejoin: "round",
    "aria-hidden": true,
    focusable: "false",
  };

  switch (iconKey) {
    case "clear":
      return (
        <svg {...common}>
          <circle cx="12" cy="12" r="4" />
          <path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" />
        </svg>
      );
    case "rain":
      return (
        <svg {...common}>
          <path d="M7 16a5 5 0 1 1 3.5-8.6A6 6 0 0 1 20 11a4 4 0 0 1-1 7H8" />
          <path d="M8 19v2M12 18v2M16 19v2" />
        </svg>
      );
    case "snow":
      return (
        <svg {...common}>
          <path d="M12 3v18M5 7l14 10M19 7 5 17" />
        </svg>
      );
    case "storm":
      return (
        <svg {...common}>
          <path d="M7 16a5 5 0 1 1 3.5-8.6A6 6 0 0 1 20 11a4 4 0 0 1-1 7H8" />
          <path d="m13 14-3 5h4l-2 4" />
        </svg>
      );
    case "fog":
      return (
        <svg {...common}>
          <path d="M4 9h16M3 13h18M6 17h12" />
        </svg>
      );
    case "cloudy":
    default:
      return (
        <svg {...common}>
          <path d="M7 17a5 5 0 1 1 3.5-8.6A6 6 0 0 1 20 12a4 4 0 0 1-1 7H8" />
        </svg>
      );
  }
}

function CalendarGlyph() {
  return (
    <svg
      viewBox="0 0 24 24"
      width="1.75rem"
      height="1.75rem"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.75"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      focusable="false"
    >
      <rect x="3" y="5" width="18" height="16" rx="2" />
      <path d="M8 3v4M16 3v4M3 11h18" />
    </svg>
  );
}

/**
 * Homepage strip: effective school day + Mississauga weather.
 */
export function HomeDayWeatherPanel({
  schoolDay,
  schoolDayLoading,
  schoolDayError,
  weather,
  weatherLoading,
  weatherError,
}) {
  const dayLabel =
    schoolDay?.effective_day === "DAY_1"
      ? "Day 1"
      : schoolDay?.effective_day === "DAY_2"
        ? "Day 2"
        : null;

  const isHalfDay = Boolean(
    schoolDay?.is_half_day || schoolDay?.schedule_override_active,
  );

  const periods =
    schoolDay?.effective_day
      ? buildDaySchedule(schoolDay.effective_day, { halfDay: isHalfDay })
      : [];

  return (
    <section
      className="home-info-strip"
      aria-label="School day and Mississauga weather"
    >
      <article className="home-info-card home-info-card--school-day" aria-live="polite">
        {schoolDayLoading && !schoolDay ? (
          <>
            <div className="home-info-card__icon" aria-hidden="true">
              <CalendarGlyph />
            </div>
            <div className="home-info-card__body">
              <p className="home-info-card__eyebrow">School day</p>
              <p className="muted">Loading school day…</p>
            </div>
          </>
        ) : schoolDayError && !schoolDay ? (
          <>
            <div className="home-info-card__icon" aria-hidden="true">
              <CalendarGlyph />
            </div>
            <div className="home-info-card__body">
              <p className="home-info-card__eyebrow">School day</p>
              <p className="form-error" role="status">
                School day unavailable
              </p>
            </div>
          </>
        ) : (
          <>
            <div className="home-info-card__school-main">
              <div className="home-info-card__icon" aria-hidden="true">
                <CalendarGlyph />
              </div>
              <div className="home-info-card__body">
                <p className="home-info-card__eyebrow">School day</p>
                <p className="home-info-card__value">
                  {dayLabel}
                  {isHalfDay ? (
                    <span className="home-info-card__condition">Half day</span>
                  ) : null}
                </p>
                <p className="home-info-card__meta">
                  {schoolDay?.override_active
                    ? "Manual day override"
                    : "Automatic schedule"}
                </p>
              </div>
            </div>

            {periods.length > 0 ? (
              <ol className="home-info-card__periods" aria-label="Period times">
                {periods.map((period) => (
                  <li key={`${period.label}-${period.start}`}>
                    <span className="home-info-card__period-label">
                      {period.label}
                    </span>
                    <span className="home-info-card__period-time">
                      {formatBellTime(period.start)} – {formatBellTime(period.end)}
                    </span>
                  </li>
                ))}
              </ol>
            ) : null}
          </>
        )}
      </article>

      <article className="home-info-card" aria-live="polite">
        <div className="home-info-card__icon" aria-hidden="true">
          {weather ? (
            <WeatherGlyph iconKey={weather.iconKey} />
          ) : (
            <WeatherGlyph iconKey="cloudy" />
          )}
        </div>
        <div className="home-info-card__body">
          <p className="home-info-card__eyebrow">Mississauga weather</p>
          {weatherLoading && !weather ? (
            <p className="muted">Loading weather…</p>
          ) : weatherError && !weather ? (
            <p className="form-error" role="status">
              Weather unavailable
            </p>
          ) : weather ? (
            <>
              <p className="home-info-card__value">
                <span aria-label={`${weather.temperatureC} degrees Celsius`}>
                  {weather.temperatureC}°C
                </span>
                <span className="home-info-card__condition">
                  {weather.condition}
                </span>
              </p>
              <dl className="home-info-card__stats">
                <div>
                  <dt>High</dt>
                  <dd>{weather.highC}°C</dd>
                </div>
                <div>
                  <dt>Low</dt>
                  <dd>{weather.lowC}°C</dd>
                </div>
                <div>
                  <dt>Precipitation chance</dt>
                  <dd>{weather.precipChance}%</dd>
                </div>
              </dl>
              {weather.stale ? (
                <p className="form-hint" role="status">
                  Showing last known weather — live update failed.
                </p>
              ) : null}
            </>
          ) : null}
        </div>
      </article>
    </section>
  );
}
