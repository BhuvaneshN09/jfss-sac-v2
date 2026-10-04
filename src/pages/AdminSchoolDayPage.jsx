import { useCallback, useEffect, useState } from "react";
import { useAuth } from "../context/AuthContext";
import { EmptyState } from "../components/ui/EmptyState";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { LoadingScreen } from "../components/ui/LoadingScreen";
import { PermissionNotice } from "../components/ui/PermissionNotice";
import { Spinner } from "../components/ui/Spinner";
import {
  clearSchoolDayOverride,
  clearSchoolScheduleOverride,
  getEffectiveSchoolDay,
  setHalfDayOverride,
  setSchoolDayOverride,
} from "../services/schoolDay";
import { formatDate } from "../utils/format";
import { formatDateOnly, schoolDayLabel } from "../utils/torontoDate";
import { getErrorMessage } from "../utils/errors";

export function AdminSchoolDayPage({ embedded = false }) {
  const { isSacAdmin, isSacExec } = useAuth();
  const canView = isSacAdmin || isSacExec;
  const canMutate = canView;

  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const next = await getEffectiveSchoolDay();
      setData(next);
    } catch (loadError) {
      setError(getErrorMessage(loadError, "Could not load school day."));
      setData(null);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (!canView) return;
    // eslint-disable-next-line react-hooks/set-state-in-effect -- intentional async page fetch
    load();
  }, [canView, load]);

  async function applyDay(dayValue) {
    if (!canMutate || busy) return;
    setBusy(true);
    setError("");
    setSuccess("");
    try {
      const next = await setSchoolDayOverride(dayValue);
      setData(next);
      setSuccess(`Today is now overridden to ${schoolDayLabel(dayValue)}.`);
    } catch (actionError) {
      setError(
        getErrorMessage(
          actionError,
          "Could not update the school day override.",
        ),
      );
    } finally {
      setBusy(false);
    }
  }

  async function clearDayOverride() {
    if (!canMutate || busy) return;
    setBusy(true);
    setError("");
    setSuccess("");
    try {
      const next = await clearSchoolDayOverride();
      setData(next);
      setSuccess("Day override cleared. Automatic day is in effect again.");
    } catch (actionError) {
      setError(
        getErrorMessage(
          actionError,
          "Could not clear the school day override.",
        ),
      );
    } finally {
      setBusy(false);
    }
  }

  async function applyHalfDay() {
    if (!canMutate || busy) return;
    setBusy(true);
    setError("");
    setSuccess("");
    try {
      const next = await setHalfDayOverride();
      setData(next);
      setSuccess("Half-day schedule is active for today.");
    } catch (actionError) {
      setError(
        getErrorMessage(actionError, "Could not set the half-day schedule."),
      );
    } finally {
      setBusy(false);
    }
  }

  async function clearHalfDay() {
    if (!canMutate || busy) return;
    setBusy(true);
    setError("");
    setSuccess("");
    try {
      const next = await clearSchoolScheduleOverride();
      setData(next);
      setSuccess("Half-day cleared. Regular period times are in effect.");
    } catch (actionError) {
      setError(
        getErrorMessage(actionError, "Could not clear the half-day schedule."),
      );
    } finally {
      setBusy(false);
    }
  }

  if (!canView) {
    return (
      <PermissionNotice title="Exec access required">
        School day overrides are limited to SAC administrators and SAC
        executives.
      </PermissionNotice>
    );
  }

  if (loading && !data) {
    return <LoadingScreen message="Loading school day…" />;
  }

  const automaticLabel = schoolDayLabel(data?.automatic_day);
  const effectiveLabel = schoolDayLabel(data?.effective_day);
  const isHalfDay = Boolean(
    data?.is_half_day || data?.schedule_override_active,
  );

  return (
    <div className={embedded ? "exec-section" : "page"}>
      {!embedded ? (
        <header className="page-header">
          <h1>School day</h1>
        </header>
      ) : (
        <h2 className="exec-section__title">School Day Override</h2>
      )}
      {isSacExec && !isSacAdmin ? (
        <PermissionNotice title="Limited exception">
          SAC Executives may change today&apos;s school day and half-day
          overrides only. All other Exec Dashboard mutations remain read-only.
        </PermissionNotice>
      ) : null}

      {error ? <ErrorMessage>{error}</ErrorMessage> : null}
      {success ? (
        <div className="alert alert--success" role="status">
          <strong>Success</strong>
          <p>{success}</p>
        </div>
      ) : null}

      {!data ? (
        <EmptyState title="School day unavailable">
          Try refreshing this page.
        </EmptyState>
      ) : (
        <section className="panel stack">
          <dl className="meta-list">
            <div>
              <dt>Date</dt>
              <dd>{formatDateOnly(data.toronto_date)}</dd>
            </div>
            <div>
              <dt>Automatic day</dt>
              <dd>{automaticLabel}</dd>
            </div>
            <div>
              <dt>Effective day</dt>
              <dd>
                <strong>{effectiveLabel}</strong>
              </dd>
            </div>
            <div>
              <dt>Day override</dt>
              <dd>
                {data.override_active
                  ? `Active (${schoolDayLabel(data.override_day)})`
                  : "Not active — using automatic day"}
              </dd>
            </div>
            <div>
              <dt>Schedule</dt>
              <dd>{isHalfDay ? "Half day" : "Regular day"}</dd>
            </div>
            {data.updated_at ? (
              <div>
                <dt>Day last changed</dt>
                <dd>{formatDate(data.updated_at)}</dd>
              </div>
            ) : null}
            {data.schedule_updated_at ? (
              <div>
                <dt>Schedule last changed</dt>
                <dd>{formatDate(data.schedule_updated_at)}</dd>
              </div>
            ) : null}
          </dl>

          <div className="button-row">
            <button
              type="button"
              className="button button--primary"
              disabled={
                busy || (data.override_active && data.override_day === "DAY_1")
              }
              onClick={() => applyDay("DAY_1")}
            >
              {busy ? <Spinner size="sm" /> : null}
              Set Day 1
            </button>
            <button
              type="button"
              className="button button--primary"
              disabled={
                busy || (data.override_active && data.override_day === "DAY_2")
              }
              onClick={() => applyDay("DAY_2")}
            >
              {busy ? <Spinner size="sm" /> : null}
              Set Day 2
            </button>
            <button
              type="button"
              className="button button--secondary"
              disabled={busy || !data.override_active}
              onClick={clearDayOverride}
            >
              Clear today&apos;s day override
            </button>
          </div>

          <div className="button-row">
            <button
              type="button"
              className="button button--primary"
              disabled={busy || isHalfDay}
              onClick={applyHalfDay}
            >
              {busy ? <Spinner size="sm" /> : null}
              Set half day
            </button>
            <button
              type="button"
              className="button button--secondary"
              disabled={busy || !isHalfDay}
              onClick={clearHalfDay}
            >
              Clear half day
            </button>
          </div>
        </section>
      )}
    </div>
  );
}
