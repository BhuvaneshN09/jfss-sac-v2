import { useCallback, useEffect, useState } from "react";
import { Link, useLocation } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { ClubInvitationsPanel } from "../components/clubs/ClubInvitationsPanel";
import { ClubRoleBadge } from "../components/clubs/ClubRoleBadge";
import { EmptyState } from "../components/ui/EmptyState";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { LoadingScreen } from "../components/ui/LoadingScreen";
import { StatusBadge } from "../components/ui/StatusBadge";
import { getMyPendingClubInvitations } from "../services/clubInvitations";
import { getMyClubMemberships } from "../services/memberships";
import {
  getClubRoleLabel,
  isClubOwner,
} from "../utils/clubPermissions";
import { formatDate } from "../utils/format";
import { getErrorMessage } from "../utils/errors";

export function MyClubsPage() {
  const { user, isSacAdmin } = useAuth();
  const location = useLocation();
  const [memberships, setMemberships] = useState([]);
  const [invitations, setInvitations] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const notice = location.state?.notice || "";

  const load = useCallback(async () => {
    setLoading(true);
    setError("");

    try {
      const [membershipData, invitationData] = await Promise.all([
        getMyClubMemberships(user.id),
        getMyPendingClubInvitations(user.id),
      ]);
      setMemberships(membershipData);
      setInvitations(invitationData);
    } catch (loadError) {
      setError(getErrorMessage(loadError, "Could not load your clubs."));
    } finally {
      setLoading(false);
    }
  }, [user.id]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- intentional async page fetch
    load();
  }, [load]);

  if (loading) {
    return <LoadingScreen message="Loading your clubs…" />;
  }

  return (
    <div className="page">
      {notice ? (
        <div className="alert alert--success" role="status">
          <strong>Success</strong>
          <p>{notice}</p>
        </div>
      ) : null}

      {error ? <ErrorMessage>{error}</ErrorMessage> : null}

      <ClubInvitationsPanel invitations={invitations} onChanged={load} />

      <h2>Your memberships</h2>

      {!error && memberships.length === 0 ? (
        <EmptyState title="No club memberships yet">
          Approved club ownership or membership will appear here after a club
          request is approved or you accept an invitation.
        </EmptyState>
      ) : (
        <div className="stack">
          {memberships.map((membership) => {
            const club = membership.clubs;
            const canManage = isSacAdmin || isClubOwner(membership.role);

            return (
              <article
                key={`${membership.club_id}-${membership.user_id}`}
                className="panel membership-card"
              >
                <div className="section-heading">
                  <div>
                    <h2>{club?.name || "Unknown club"}</h2>
                    <p className="membership-role-line">
                      Role: {getClubRoleLabel(membership.role)}
                    </p>
                    <div className="badge-row">
                      <ClubRoleBadge role={membership.role} />
                      <StatusBadge status={membership.status} />
                      {club?.status ? (
                        <StatusBadge status={club.status} />
                      ) : null}
                    </div>
                  </div>
                  <div className="button-row button-row--compact">
                    {club?.slug ? (
                      <Link className="text-link" to={`/clubs/${club.slug}`}>
                        View club
                      </Link>
                    ) : null}
                    {canManage && club?.slug ? (
                      <Link
                        className="button button--secondary"
                        to={`/clubs/${club.slug}/manage`}
                      >
                        Manage Club
                      </Link>
                    ) : null}
                  </div>
                </div>

                <dl className="meta-list">
                  <div>
                    <dt>Joined</dt>
                    <dd>{formatDate(membership.joined_at)}</dd>
                  </div>
                  {club?.short_description ? (
                    <div>
                      <dt>Summary</dt>
                      <dd>{club.short_description}</dd>
                    </div>
                  ) : null}
                </dl>
              </article>
            );
          })}
        </div>
      )}
    </div>
  );
}
