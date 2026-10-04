import { useEffect, useMemo, useState } from "react";
import { Link, Navigate, useOutletContext } from "react-router-dom";
import { EmptyState } from "../components/ui/EmptyState";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { LoadingScreen } from "../components/ui/LoadingScreen";
import { StatusBadge } from "../components/ui/StatusBadge";
import { getClubAnnualState } from "../services/clubs";
import { getMySupervisorRequestsForClubs } from "../services/clubSupervisors";
import { isClubOwner } from "../utils/clubPermissions";
import { formatDate } from "../utils/format";
import { getErrorMessage } from "../utils/errors";

export function MySupervisorRequestsPage() {
  const { memberships = [], tabs = [] } = useOutletContext() || {};
  const canView = tabs.some((tab) => tab.id === "supervisor");

  const ownedClubs = useMemo(
    () =>
      (memberships || [])
        .filter(
          (membership) =>
            membership.status === "ACTIVE" &&
            isClubOwner(membership.role) &&
            membership.clubs &&
            membership.clubs.status === "APPROVED" &&
            !membership.clubs.deleted_at,
        )
        .map((membership) => membership.clubs),
    [memberships],
  );

  const ownedClubIds = useMemo(
    () => ownedClubs.map((club) => club.id).join(","),
    [ownedClubs],
  );

  const [requests, setRequests] = useState([]);
  const [annualByClubId, setAnnualByClubId] = useState({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    let active = true;

    async function load() {
      if (!canView) return;
      setLoading(true);
      setError("");

      try {
        const clubIds = ownedClubIds
          ? ownedClubIds.split(",").filter(Boolean)
          : [];
        const [rows, annualEntries] = await Promise.all([
          getMySupervisorRequestsForClubs(clubIds),
          Promise.all(
            clubIds.map(async (clubId) => {
              try {
                const annual = await getClubAnnualState(clubId);
                return [clubId, annual?.status ?? null];
              } catch {
                return [clubId, null];
              }
            }),
          ),
        ]);
        if (!active) return;
        setRequests(rows);
        setAnnualByClubId(Object.fromEntries(annualEntries));
      } catch (loadError) {
        if (!active) return;
        setError(
          getErrorMessage(loadError, "Could not load supervisor requests."),
        );
      } finally {
        if (active) setLoading(false);
      }
    }

    load();
    return () => {
      active = false;
    };
  }, [canView, ownedClubIds]);

  if (!canView) {
    return <Navigate to="/my-requests/applications" replace />;
  }

  if (loading) {
    return <LoadingScreen message="Loading supervisor requests…" />;
  }

  const submitTargets = ownedClubs.filter((club) => {
    const annualStatus = annualByClubId[club.id];
    return (
      annualStatus === "PENDING_SUPERVISOR" || annualStatus === "ACTIVE"
    );
  });

  return (
    <div className="stack">
      {error ? <ErrorMessage>{error}</ErrorMessage> : null}

      {submitTargets.length > 0 ? (
        <section className="panel">
          <h2>Submit or update</h2>
          <p className="muted">
            Teacher supervisor details are submitted from Manage Club for clubs
            you own.
          </p>
          <ul className="stack">
            {submitTargets.map((club) => (
              <li key={club.id}>
                <Link
                  className="text-link"
                  to={`/clubs/${club.slug}/manage`}
                >
                  {club.name}
                </Link>
                <span className="muted">
                  {" "}
                  · {annualByClubId[club.id] === "PENDING_SUPERVISOR"
                    ? "Supervisor info required"
                    : "Can update supervisors"}
                </span>
              </li>
            ))}
          </ul>
        </section>
      ) : null}

      {!error && requests.length === 0 ? (
        <EmptyState title="No supervisor requests yet">
          {submitTargets.length > 0
            ? "Open Manage Club to submit teacher supervisor information."
            : "When you own an approved club that needs supervisors, requests will appear here."}
        </EmptyState>
      ) : null}

      {requests.map((request) => {
        const supervisors =
          request.club_supervisor_request_supervisors || [];
        return (
          <article key={request.id} className="panel">
            <div className="section-heading">
              <div>
                <div className="request-card__labels">
                  <span className="submission-type">Supervisor request</span>
                  <StatusBadge status={request.status} prefix="Status: " />
                </div>
                <h3>{request.clubs?.name || "Club"}</h3>
              </div>
              <div className="request-card__aside">
                <time
                  className="request-card__date"
                  dateTime={request.submitted_at || request.created_at || undefined}
                >
                  Submitted {formatDate(request.submitted_at || request.created_at)}
                </time>
                {request.clubs?.slug ? (
                  <Link
                    className="text-link"
                    to={`/clubs/${request.clubs.slug}/manage`}
                  >
                    Manage club
                  </Link>
                ) : null}
              </div>
            </div>
            {supervisors.length > 0 ? (
              <p>
                <strong>Supervisors:</strong>{" "}
                {supervisors
                  .map(
                    (person) =>
                      `${person.supervisor_name} (${person.supervisor_email})`,
                  )
                  .join("; ")}
              </p>
            ) : null}
            {request.review_notes ? (
              <p>
                <strong>Review notes:</strong> {request.review_notes}
              </p>
            ) : null}
          </article>
        );
      })}
    </div>
  );
}
