/**
 * Mississauga weather via Open-Meteo (no API key required).
 * Responses are cached in-memory for ~20 minutes.
 */

const MISSISSAUGA = {
  latitude: 43.589,
  longitude: -79.644,
  label: "Mississauga, ON",
};

const CACHE_TTL_MS = 20 * 60 * 1000;
const OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast";
const WEATHER_REQUEST_TIMEOUT_MS = 10000;

let memoryCache = null;

const WEATHER_CODE_LABELS = {
  0: "Clear sky",
  1: "Mainly clear",
  2: "Partly cloudy",
  3: "Overcast",
  45: "Fog",
  48: "Depositing rime fog",
  51: "Light drizzle",
  53: "Moderate drizzle",
  55: "Dense drizzle",
  56: "Light freezing drizzle",
  57: "Dense freezing drizzle",
  61: "Slight rain",
  63: "Moderate rain",
  65: "Heavy rain",
  66: "Light freezing rain",
  67: "Heavy freezing rain",
  71: "Slight snow",
  73: "Moderate snow",
  75: "Heavy snow",
  77: "Snow grains",
  80: "Slight rain showers",
  81: "Moderate rain showers",
  82: "Violent rain showers",
  85: "Slight snow showers",
  86: "Heavy snow showers",
  95: "Thunderstorm",
  96: "Thunderstorm with slight hail",
  99: "Thunderstorm with heavy hail",
};

export function weatherConditionLabel(code) {
  if (code == null || Number.isNaN(Number(code))) return "Unknown";
  return WEATHER_CODE_LABELS[Number(code)] || "Unknown conditions";
}

/** Coarse icon key for UI (not raw WMO code). */
export function weatherIconKey(code) {
  const n = Number(code);
  if (Number.isNaN(n)) return "unknown";
  if (n === 0 || n === 1) return "clear";
  if (n === 2 || n === 3) return "cloudy";
  if (n === 45 || n === 48) return "fog";
  if (n >= 51 && n <= 67) return "rain";
  if (n >= 71 && n <= 77) return "snow";
  if (n >= 80 && n <= 82) return "rain";
  if (n >= 85 && n <= 86) return "snow";
  if (n >= 95) return "storm";
  return "cloudy";
}

function asNumber(value) {
  if (value == null || value === "") return null;
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

function mapOpenMeteoResponse(payload) {
  const current = payload?.current;
  const daily = payload?.daily;

  const temperatureC = asNumber(current?.temperature_2m);
  const weatherCode = asNumber(current?.weather_code);
  const highC = asNumber(daily?.temperature_2m_max?.[0]);
  const lowC = asNumber(daily?.temperature_2m_min?.[0]);
  const precipChance = asNumber(daily?.precipitation_probability_max?.[0]);

  if (
    temperatureC == null ||
    weatherCode == null ||
    highC == null ||
    lowC == null ||
    precipChance == null
  ) {
    throw new Error("Weather response was incomplete.");
  }

  return {
    locationLabel: MISSISSAUGA.label,
    temperatureC: Math.round(temperatureC),
    highC: Math.round(highC),
    lowC: Math.round(lowC),
    precipChance: Math.round(precipChance),
    weatherCode: Math.round(weatherCode),
    condition: weatherConditionLabel(weatherCode),
    iconKey: weatherIconKey(weatherCode),
    fetchedAt: new Date().toISOString(),
    provider: "Open-Meteo",
  };
}

async function fetchMississaugaWeather() {
  const params = new URLSearchParams({
    latitude: String(MISSISSAUGA.latitude),
    longitude: String(MISSISSAUGA.longitude),
    current: "temperature_2m,weather_code",
    daily:
      "temperature_2m_max,temperature_2m_min,precipitation_probability_max",
    timezone: "America/Toronto",
    forecast_days: "1",
  });

  const controller = new AbortController();
  const timeoutId = window.setTimeout(
    () => controller.abort(),
    WEATHER_REQUEST_TIMEOUT_MS,
  );

  let response;
  try {
    response = await fetch(`${OPEN_METEO_URL}?${params.toString()}`, {
      signal: controller.signal,
    });
  } finally {
    window.clearTimeout(timeoutId);
  }
  if (!response.ok) {
    throw new Error(`Weather service returned HTTP ${response.status}.`);
  }

  const payload = await response.json();
  return mapOpenMeteoResponse(payload);
}

/**
 * @returns {Promise<{
 *   locationLabel: string,
 *   temperatureC: number,
 *   highC: number,
 *   lowC: number,
 *   precipChance: number,
 *   weatherCode: number,
 *   condition: string,
 *   iconKey: string,
 *   fetchedAt: string,
 *   provider: string,
 *   stale?: boolean,
 *   fromCache?: boolean,
 * }>}
 */
export async function getMississaugaWeather({ force = false } = {}) {
  const now = Date.now();
  if (
    !force &&
    memoryCache?.data &&
    now - memoryCache.fetchedAt < CACHE_TTL_MS
  ) {
    return { ...memoryCache.data, fromCache: true, stale: false };
  }

  try {
    const data = await fetchMississaugaWeather();
    memoryCache = { data, fetchedAt: now };
    return { ...data, fromCache: false, stale: false };
  } catch (error) {
    if (memoryCache?.data) {
      return {
        ...memoryCache.data,
        fromCache: true,
        stale: true,
        staleError: error?.message || "Weather refresh failed.",
      };
    }
    throw error;
  }
}

/** Test helper — clears the in-memory cache. */
export function __resetWeatherCacheForTests() {
  memoryCache = null;
}
