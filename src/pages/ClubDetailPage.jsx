import { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { ClubRoleBadge } from "../components/clubs/ClubRoleBadge";
import { EmptyState } from "../components/ui/EmptyState";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { LoadingScreen } from "../components/ui/LoadingScreen";
import { SafeExternalLink } from "../components/ui/SafeExternalLink";
import { StatusBadge } from "../components/ui/StatusBadge";
import { getClubBySlug } from "../services/clubs";
import { getApprovedClubPromoLunchConfirmation } from "../services/clubPromoLunch";
import { getMyMembershipForClub } from "../services/memberships";
import { isClubOwner } from "../utils/clubPermissions";
import { getVisibleMeetingSchedule } from "../utils/clubSchedule";
import { getErrorMessage } from "../utils/errors";
import { toSameOriginSupabaseUrl } from "../utils/proxiedSupabaseUrl";
import { safeExternalHref } from "../utils/urls";

export function ClubDetailPage() {
  const { slug } = useParams();
  const { user, isAuthenticated, isAdmin } = useAuth();
  const [club, setClub] = useState(null);
  const [promoLunchConfirmed, setPromoLunchConfirmed] = useState(false);
  const [membership, setMembership] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    let active = true;

    async function load() {
      setLoading(true);
      setError("");
      setMembership(null);
      setPromoLunchConfirmed(false);

      try {
        const nextClub = await getClubBySlug(slug);
        if (!active) return;

        if (!nextClub) {
          setClub(null);
          setError("");
          setLoading(false);
          return;
        }

        setClub(nextClub);

        const promoLunchConfirmation =
          await getApprovedClubPromoLunchConfirmation(nextClub.id);
        if (!active) return;
        setPromoLunchConfirmed(Boolean(promoLunchConfirmation));

        if (isAuthenticated && user?.id) {
          try {
            const nextMembership = await getMyMembershipForClub(
              user.id,
              nextClub.id,
            );
            if (!active) return;
            setMembership(nextMembership);
          } catch (membershipError) {
            console.error(membershipError);
          }
        }
      } catch (loadError) {
        if (!active) return;
        setError(getErrorMessage(loadError, "Could not load this club."));
      } finally {
        if (active) setLoading(false);
      }
    }

    load();

    return () => {
      active = false;
    };
  }, [slug, isAuthenticated, user?.id]);

  if (loading) {
    return <LoadingScreen message="Loading club…" />;
  }

  if (error) {
    return (
      <div className="page">
        <ErrorMessage>{error}</ErrorMessage>
        <Link className="text-link" to="/clubs">
          Back to clubs
        </Link>
      </div>
    );
  }

  if (!club) {
    return (
      <div className="page">
        <EmptyState title="Club not found">
          This club does not exist or is not publicly available.
        </EmptyState>
        <Link className="text-link" to="/clubs">
          Back to clubs
        </Link>
      </div>
    );
  }

  const initial = club.name?.charAt(0)?.toUpperCase() || "C";
  const meetingSchedule = getVisibleMeetingSchedule(club.meeting_schedule);
  const showStatus = isAdmin || club.status !== "APPROVED";
  const canManage = isAdmin || isClubOwner(membership?.role);
  const bannerUrl = safeExternalHref(toSameOriginSupabaseUrl(club.banner_url));
  const logoUrl = safeExternalHref(toSameOriginSupabaseUrl(club.logo_url));
  const memberApplyHref = safeExternalHref(club.member_application_url);
  const execApplyHref = safeExternalHref(club.exec_application_url);

  return (
    <div className="page">
      <div className="club-hero">
        {bannerUrl ? (
          <img src={bannerUrl} alt="" className="club-hero__banner" />
        ) : (
          <div className="club-hero__banner club-hero__banner--fallback" />
        )}

        <div className="club-hero__content">
          {logoUrl ? (
            <img src={logoUrl} alt="" className="club-hero__logo" />
          ) : (
            <div
              className="club-hero__logo club-hero__logo--fallback"
              aria-hidden="true"
            >
              {initial}
            </div>
          )}

          <div className="club-hero__title">
            <div>
            <h1>{club.name}</h1>
            <div className="badge-row">
              {showStatus ? <StatusBadge status={club.status} /> : null}
              {membership ? <ClubRoleBadge role={membership.role} /> : null}
            </div>
            </div>
            {promoLunchConfirmed || memberApplyHref || execApplyHref ? (
              <div className="club-hero__actions">
                {promoLunchConfirmed ? (
                  <p className="club-promo-confirmation">
                    Confirmed for Club Promo Lunch
                  </p>
                ) : null}
                {memberApplyHref || execApplyHref ? (
                  <div className="club-hero__applications">
                    {memberApplyHref ? (
                      <SafeExternalLink
                        className="button button--primary"
                        href={memberApplyHref}
                      >
                        Member Apply
                      </SafeExternalLink>
                    ) : null}
                    {execApplyHref ? (
                      <SafeExternalLink
                        className="button button--secondary"
                        href={execApplyHref}
                      >
                        Exec Apply
                      </SafeExternalLink>
                    ) : null}
                  </div>
                ) : null}
              </div>
            ) : null}
          </div>
        </div>
      </div>

      <section className="panel">
        <h2>About</h2>
        <p className="prose">{club.description}</p>
      </section>

      <section className="panel club-details-panel">
        <h2>Details</h2>
        <dl className="meta-list club-details-grid">
          <div className="club-detail-item">
            <dt>Club contact</dt>
            <dd>{club.contact_email || "Not provided"}</dd>
          </div>
          <div className="club-detail-item">
            <dt>Instagram handle</dt>
            <dd>{club.instagram_handle || "Not provided"}</dd>
          </div>
          <div className="club-detail-item">
            <dt>Meeting schedule</dt>
            <dd>{meetingSchedule || "Not provided"}</dd>
          </div>
          <div className="club-detail-item">
            <dt>Meeting location</dt>
            <dd>{club.meeting_location || "Not provided"}</dd>
          </div>
          {membership ? (
            <div className="club-detail-item">
              <dt>Your role in this club</dt>
              <dd>
                <ClubRoleBadge role={membership.role} />
              </dd>
            </div>
          ) : null}
        </dl>

        {canManage ? (
          <div className="button-row">
            <Link
              className="button button--primary"
              to={`/clubs/${club.slug}/manage`}
            >
              Manage Club
            </Link>
          </div>
        ) : null}
      </section>

      <Link className="text-link" to="/clubs">
        Back to clubs
      </Link>
    </div>
  );
}
