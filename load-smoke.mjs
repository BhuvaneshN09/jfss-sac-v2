const baseUrl = process.env.LOAD_TEST_URL || "http://localhost:5173";
const users = Math.max(1, Number(process.env.LOAD_TEST_USERS || 50));
const paths = ["/", "/clubs", "/sports", "/events", "/announcements"];

const requests = Array.from({ length: users }, (_, userIndex) =>
  Promise.all(
    paths.map(async (path) => {
      const startedAt = performance.now();
      try {
        const response = await fetch(new URL(path, baseUrl));
        return {
          userIndex,
          path,
          status: response.status,
          durationMs: Math.round(performance.now() - startedAt),
        };
      } catch (error) {
        return {
          userIndex,
          path,
          status: 0,
          durationMs: Math.round(performance.now() - startedAt),
          error: error.message,
        };
      }
    }),
  ),
);

const results = (await Promise.all(requests)).flat();
const failures = results.filter((result) => result.status < 200 || result.status >= 400);
const durations = results.map((result) => result.durationMs).sort((a, b) => a - b);
const percentile = (value) =>
  durations[Math.min(durations.length - 1, Math.ceil(durations.length * value) - 1)];

console.log(
  JSON.stringify(
    {
      baseUrl,
      simulatedUsers: users,
      requests: results.length,
      failures: failures.length,
      p50Ms: percentile(0.5),
      p95Ms: percentile(0.95),
      p99Ms: percentile(0.99),
    },
    null,
    2,
  ),
);

if (failures.length > 0) {
  console.error(JSON.stringify(failures.slice(0, 10), null, 2));
  process.exitCode = 1;
}
