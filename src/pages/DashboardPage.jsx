import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { ClubRoleBadge } from "../components/clubs/ClubRoleBadge";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { LoadingScreen } from "../components/ui/LoadingScreen";
import { RoleBadge } from "../components/ui/RoleBadge";
import { StatusBadge } from "../components/ui/StatusBadge";
import { getMyClubMemberships } from "../services/memberships";
import { formatClubScopedRole } from "../utils/clubPermissions";
import { displayName, formatDate } from "../utils/format";
import { getErrorMessage } from "../utils/errors";

export function DashboardPage() {
  const {
    user,
    profile,
    systemRoles,
    canAccessExecDashboard,
    authError,
    refreshProfile,
    refreshRoles,
    signOut,
  } = useAuth();
  const [memberships, setMemberships] = useState([]);
  const [membershipsError, setMembershipsError] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [signingOut, setSigningOut] = useState(false);

  useEffect(() => {
    let active = true;

    async function load() {
      setLoading(true);
      setError("");
      setMembershipsError("");

      try {
        await Promise.all([
          refreshProfile(user.id).catch(() => null),
          refreshRoles(user.id).catch(() => null),
        ]);

        const nextMemberships = await getMyClubMemberships(user.id).catch(
          (membershipError) => {
            setMembershipsError(
              getErrorMessage(
                membershipError,
                "Could not load your club roles.",
              ),
            );
            return [];
          },
        );

        if (!active) return;
        setMemberships(nextMemberships);
      } catch (loadError) {
        if (!active) return;
        setError(getErrorMessage(loadError, "Could not load your dashboard."));
      } finally {
        if (active) setLoading(false);
      }
    }

    load();

    return () => {
      active = false;
    };
  }, [user.id, refreshProfile, refreshRoles]);

  if (loading) {
    return <LoadingScreen message="Loading dashboard…" />;
  }

  async function handleSignOut() {
    if (signingOut) return;
    setSigningOut(true);
    try {
      await signOut();
    } catch (signOutError) {
      setError(getErrorMessage(signOutError, "Sign out failed."));
      setSigningOut(false);
    }
  }

  return (
    <div className="page">
      <header className="page-header">
        <div>
          <h1 className="page-header__name">{displayName(profile, user)}</h1>
          <p className="lede">Your profile and roles.</p>
        </div>
        <button
          type="button"
          className="button button--secondary"
          onClick={handleSignOut}
          disabled={signingOut}
        >
          {signingOut ? "Signing out…" : "Sign out"}
        </button>
      </header>

      {authError ? <ErrorMessage>{authError}</ErrorMessage> : null}
      {error ? <ErrorMessage>{error}</ErrorMessage> : null}

      <section className="panel">
        <h2>Profile summary</h2>
        <dl className="meta-list">
          <div>
            <dt>Email</dt>
            <dd>{profile?.email || user.email}</dd>
          </div>
          <div>
            <dt>Full name</dt>
            <dd>{profile?.full_name || "Not set"}</dd>
          </div>
          <div>
            <dt>Graduation year</dt>
            <dd>{profile?.graduation_year || "Not set"}</dd>
          </div>
          <div>
            <dt>Profile status</dt>
            <dd>
              {profile
                ? profile.is_active
                  ? "Active"
                  : "Inactive"
                : "Profile missing"}
            </dd>
          </div>
        </dl>
      </section>

      <section className="panel">
        <h2>Your roles</h2>
        <p className="muted">
          System roles apply across the portal. Club roles apply only to a
          specific club.
        </p>

        <div className="role-section">
          <h3>System roles</h3>
          {systemRoles.length === 0 && memberships.length === 0 ? (
            <p className="muted">No system or club roles assigned.</p>
          ) : (
            <ul className="role-list">
              {systemRoles.map((role) => (
                <li key={role.code}>
                  <div className="role-list__item">
                    <RoleBadge role={role.code} />
                    <div>
                      <strong>{role.name || role.code}</strong>
                      {role.description ? <p>{role.description}</p> : null}
                    </div>
                  </div>
                </li>
              ))}
              {memberships.map((membership) => {
                const club = membership.clubs;
                const label = formatClubScopedRole(club?.name, membership.role);
                return (
                  <li key={`club-role-${membership.club_id}`}>
                    <div className="role-list__item">
                      <ClubRoleBadge role={membership.role} />
                      <div>
                        <strong>{label}</strong>
                        <p>
                          Club-scoped role
                          {membership.status !== "ACTIVE"
                            ? ` · ${membership.status}`
                            : ""}
                        </p>
                      </div>
                    </div>
                  </li>
                );
              })}
            </ul>
          )}
        </div>

        <div className="role-section">
          <h3>Club roles</h3>
          {membershipsError ? (
            <ErrorMessage>{membershipsError}</ErrorMessage>
          ) : null}
          {!membershipsError && memberships.length === 0 ? (
            <p className="muted">
              You are not an owner, executive, or member of any club yet.
            </p>
          ) : null}
          {memberships.length > 0 ? (
            <ul className="role-list">
              {memberships.map((membership) => {
                const club = membership.clubs;
                return (
                  <li key={`${membership.club_id}-${membership.user_id}`}>
                    <div className="role-list__item">
                      <ClubRoleBadge role={membership.role} />
                      <div>
                        <strong>{club?.name || "Unknown club"}</strong>
                        <p>
                          {formatClubScopedRole(club?.name, membership.role)}
                          {membership.status !== "ACTIVE"
                            ? ` · ${membership.status}`
                            : ""}
                        </p>
                        <p className="muted">
                          Joined {formatDate(membership.joined_at)}
                        </p>
                        {club?.slug ? (
                          <Link className="text-link" to={`/clubs/${club.slug}`}>
                            View club
                          </Link>
                        ) : null}
                      </div>
                      {club?.status ? (
                        <StatusBadge status={club.status} />
                      ) : null}
                    </div>
                  </li>
                );
              })}
            </ul>
          ) : null}
        </div>
      </section>

      <section className="panel">
        <h2>Quick actions</h2>
        <div className="button-row">
          <Link to="/clubs/apply" className="button button--primary">
            Create a new club
          </Link>
          <Link to="/clubs/my-clubs" className="button button--secondary">
            My clubs
          </Link>
          {canAccessExecDashboard ? (
            <Link to="/exec-dashboard" className="button button--secondary">
              Exec Dashboard
            </Link>
          ) : null}
        </div>
      </section>
    </div>
  );
}
