import { useCallback, useEffect, useMemo, useState } from "react";
import {
  Link,
  Navigate,
  useNavigate,
  useParams,
  useSearchParams,
} from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { AddClubMemberForm } from "../components/clubs/AddClubMemberForm";
import { ArchiveClubDialog } from "../components/clubs/ArchiveClubDialog";
import { ChangeRoleDialog } from "../components/clubs/ChangeRoleDialog";
import { ClubAnnouncementsPanel } from "../components/clubs/ClubAnnouncementsPanel";
import { ClubDetailsPanel } from "../components/clubs/ClubDetailsPanel";
import { ClubEventForm } from "../components/clubs/ClubEventForm";
import { ClubFundingForm } from "../components/clubs/ClubFundingForm";
import { ClubPromoLunchForm } from "../components/clubs/ClubPromoLunchForm";
import { ClubManageTabs } from "../components/clubs/ClubManageTabs";
import { ClubPeoplePanel } from "../components/clubs/ClubPeoplePanel";
import { ConfirmDialog } from "../components/ui/ConfirmDialog";
import { EmptyState } from "../components/ui/EmptyState";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { LoadingScreen } from "../components/ui/LoadingScreen";
import { RemoveMemberDialog } from "../components/clubs/RemoveMemberDialog";
import { getClubAnnualState, getClubBySlug } from "../services/clubs";
import {
  getApprovedReapplicationForClub,
  withdrawClubReapplication,
} from "../services/clubReapplications";
import {
  getClubMemberships,
  getCurrentUserClubMembership,
  probeStudentLookupAvailability,
} from "../services/memberships";
import {
  cancelClubMembershipInvitation,
  getClubPendingInvitations,
} from "../services/clubInvitations";
import {
  canArchiveOwnedClub,
  canSearchStudents,
  canSubmitClubRequestForms,
  getClubRequestBlockedMessage,
  getAddableRoles,
  isClubOwner,
} from "../utils/clubPermissions";
import { getErrorMessage } from "../utils/errors";
import { formatDate } from "../utils/format";
import { archiveSuccessNotice } from "../utils/clubOrigin";

function annualStatusLabel(status, overdue) {
  if (status === "PENDING_SUPERVISOR" && overdue) return "Supervisor Overdue";
  if (status === "PENDING_SUPERVISOR") return "Pending Supervisor";
  if (status === "ACTIVE") return "Active";
  if (status === "SUSPENDED") return "Suspended";
  if (status === "INACTIVE") return "Inactive";
  return status || "Unknown";
}

export function ClubManagePage() {
  const { slug } = useParams();
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();
  const { user, isSacAdmin, isAdmin } = useAuth();

  const [activeTab, setActiveTab] = useState(() => {
    const requestedTab = searchParams.get("tab");
    return [
      "details",
      "people",
      "announcements",
      "funding",
      "events",
      "promoLunch",
    ].includes(requestedTab)
      ? requestedTab
      : "details";
  });
  const [club, setClub] = useState(null);
  const [annual, setAnnual] = useState(null);
  const [membership, setMembership] = useState(null);
  const [memberships, setMemberships] = useState([]);
  const [invitations, setInvitations] = useState([]);
  const [profilesWarning, setProfilesWarning] = useState(null);
  const [lookupAvailable, setLookupAvailable] = useState(false);
  const [lookupWarning, setLookupWarning] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [unauthorized, setUnauthorized] = useState(false);
  const [cancellingInvitationId, setCancellingInvitationId] = useState(null);

  const [changeTarget, setChangeTarget] = useState(null);
  const [removeTarget, setRemoveTarget] = useState(null);
  const [archiveOpen, setArchiveOpen] = useState(false);
  const [withdrawOpen, setWithdrawOpen] = useState(false);
  const [withdrawBusy, setWithdrawBusy] = useState(false);
  const [approvedReappId, setApprovedReappId] = useState(null);
  const [nowMs] = useState(() => Date.now());

  const loadPage = useCallback(async () => {
    setLoading(true);
    setError("");
    setUnauthorized(false);

    try {
      const nextClub = await getClubBySlug(slug);
      if (!nextClub) {
        setClub(null);
        setMembership(null);
        setMemberships([]);
        setInvitations([]);
        setAnnual(null);
        return;
      }

      setClub(nextClub);

      const [currentMembership, annualState] = await Promise.all([
        getCurrentUserClubMembership(nextClub.id, user.id),
        getClubAnnualState(nextClub.id).catch(() => null),
      ]);
      setMembership(currentMembership);
      setAnnual(annualState);

      if (annualState?.status === "PENDING_SUPERVISOR") {
        try {
          const match = await getApprovedReapplicationForClub(nextClub.id);
          setApprovedReappId(match?.id || null);
        } catch {
          setApprovedReappId(null);
        }
      } else {
        setApprovedReappId(null);
      }

      const allowed =
        isSacAdmin || isClubOwner(currentMembership?.role);

      if (!allowed) {
        setUnauthorized(true);
        return;
      }

      const [membershipResult, lookupProbe, pendingInvites] =
        await Promise.all([
          getClubMemberships(nextClub.id),
          probeStudentLookupAvailability(),
          getClubPendingInvitations(nextClub.id).catch(() => []),
        ]);

      setMemberships(membershipResult.memberships);
      setProfilesWarning(membershipResult.profilesWarning);
      setLookupAvailable(lookupProbe.available);
      setLookupWarning(lookupProbe.warning);
      setInvitations(pendingInvites);
    } catch (loadError) {
      setError(getErrorMessage(loadError, "Could not load club management."));
    } finally {
      setLoading(false);
    }
  }, [isSacAdmin, slug, user.id]);

  useEffect(() => {
    // Initial and dependency-driven page load for club management.
    // eslint-disable-next-line react-hooks/set-state-in-effect -- intentional async page fetch
    loadPage();
  }, [loadPage]);

  const activeOwnerCount = useMemo(
    () =>
      memberships.filter(
        (row) => row.role === "OWNER" && row.status === "ACTIVE",
      ).length,
    [memberships],
  );

  const pendingOwnerInvitationCount = useMemo(
    () =>
      invitations.filter(
        (row) => row.offered_role === "OWNER" && row.status === "PENDING",
      ).length,
    [invitations],
  );

  const addableRoles = getAddableRoles({
    currentUserRole: membership?.role,
    isSacAdmin,
    activeOwnerCount,
    pendingOwnerInvitationCount,
  });

  const canInvite = canSearchStudents({
    clubRole: membership?.role,
    isSacAdmin,
  });

  const isPendingSupervisor = annual?.status === "PENDING_SUPERVISOR";
  const supervisorDueAtMs = annual?.supervisor_due_at
    ? new Date(annual.supervisor_due_at).getTime()
    : null;
  const isOverdue =
    isPendingSupervisor &&
    supervisorDueAtMs != null &&
    supervisorDueAtMs < nowMs;
  const canOwnerArchive = canArchiveOwnedClub({
    clubRole: membership?.role,
    membershipStatus: membership?.status,
    annualStatus: annual?.status,
    clubStatus: club?.status,
    isSacAdmin,
  });
  const canOwnerWithdrawPending =
    isPendingSupervisor &&
    isClubOwner(membership?.role) &&
    membership?.status === "ACTIVE" &&
    Boolean(approvedReappId);

  const canSubmitRequests = canSubmitClubRequestForms({
    clubRole: membership?.role,
    membershipStatus: membership?.status,
    annualStatus: annual?.status,
    clubStatus: club?.status,
    deletedAt: club?.deleted_at,
  });
  const canViewRequests = isSacAdmin || canSubmitRequests;
  const requestBlockedMessage = getClubRequestBlockedMessage({
    clubStatus: club?.status,
    annualStatus: annual?.status,
    noun: "requests",
    isSacAdmin,
  });

  function handleTabChange(tab) {
    setActiveTab(tab);
    setSearchParams(
      (current) => {
        const next = new URLSearchParams(current);
        if (tab === "details") {
          next.delete("tab");
        } else {
          next.set("tab", tab);
        }
        return next;
      },
      { replace: true },
    );
  }

  if (loading) {
    return <LoadingScreen message="Loading club management…" />;
  }

  if (unauthorized && club) {
    return <Navigate to={`/clubs/${club.slug}`} replace />;
  }

  if (!club) {
    return (
      <div className="page">
        <EmptyState title="Club not found">
          This club does not exist or is not available.
        </EmptyState>
        <Link className="text-link" to="/clubs">
          Back to clubs
        </Link>
      </div>
    );
  }

  if (error && memberships.length === 0 && !membership) {
    return (
      <div className="page">
        <ErrorMessage>{error}</ErrorMessage>
        <Link className="text-link" to={`/clubs/${club.slug}`}>
          Back to club
        </Link>
      </div>
    );
  }

  return (
    <div className="page">
      <header className="page-header">
        <div>
          <p className="eyebrow">Club management</p>
          <h1>{club.name}</h1>
          <p className="lede">
            Update club details, people, and requests. A club may have at most
            three active owners.
          </p>
          <p>
            Annual status:{" "}
            <strong>{annualStatusLabel(annual?.status, isOverdue)}</strong>
            {isPendingSupervisor && annual?.supervisor_due_at ? (
              <> · Supervisor due {formatDate(annual.supervisor_due_at)}</>
            ) : null}
          </p>
          <p>
            {activeOwnerCount} of 3 Owners
          </p>
        </div>
        <Link className="text-link" to={`/clubs/${club.slug}`}>
          View club page
        </Link>
      </header>

      {isPendingSupervisor ? (
        <div className="alert alert--warning" role="status">
          <strong>
            {isOverdue
              ? "Supervisor requirement overdue"
              : "Pending Teacher Supervisor"}
          </strong>
          <p>
            This club is not public in Explore. Funding, events, promo lunch,
            and announcements stay blocked until SAC approves at least one
            teacher supervisor. Owners may still manage members and submit
            supervisor information.
          </p>
        </div>
      ) : null}

      {success ? (
        <div className="alert alert--success" role="status">
          <strong>Success</strong>
          <p>{success}</p>
        </div>
      ) : null}

      {error ? <ErrorMessage>{error}</ErrorMessage> : null}

      <ClubManageTabs activeTab={activeTab} onChange={handleTabChange} />

      {activeTab === "details" ? (
        <ClubDetailsPanel
          club={club}
          annual={annual}
          membership={membership}
          isSacAdmin={isSacAdmin}
          canArchive={canOwnerArchive}
          canWithdrawPending={canOwnerWithdrawPending}
          onOpenArchive={() => setArchiveOpen(true)}
          onOpenWithdraw={() => setWithdrawOpen(true)}
          onClubUpdated={(updated) => {
            setClub(updated);
            setError("");
            setSuccess("Changes saved successfully.");
            window.scrollTo({ top: 0, behavior: "smooth" });
            if (updated?.slug && updated.slug !== slug) {
              navigate(`/clubs/${updated.slug}/manage`, { replace: true });
            }
          }}
          onSupervisorSubmitted={() => {
            setSuccess("Supervisor package submitted for SAC review.");
            loadPage();
          }}
        />
      ) : null}

      {activeTab === "people" ? (
        <ClubPeoplePanel
          memberships={memberships}
          invitations={invitations}
          currentUserId={user.id}
          currentUserRole={membership?.role}
          isSacAdmin={isSacAdmin}
          profilesWarning={profilesWarning}
          cancellingInvitationId={cancellingInvitationId}
          onCancelInvitation={async (invitation) => {
            if (cancellingInvitationId) return;
            setCancellingInvitationId(invitation.id);
            setError("");
            try {
              await cancelClubMembershipInvitation(invitation.id);
              setSuccess("Invitation cancelled.");
              await loadPage();
            } catch (cancelError) {
              setError(
                getErrorMessage(cancelError, "Could not cancel invitation."),
              );
            } finally {
              setCancellingInvitationId(null);
            }
          }}
          onChangeRole={setChangeTarget}
          onRemove={setRemoveTarget}
          addForm={
            canInvite && addableRoles.length > 0 ? (
              <AddClubMemberForm
                club={club}
                currentUserId={user.id}
                currentUserRole={membership?.role}
                isSacAdmin={isSacAdmin}
                existingMemberships={memberships}
                pendingOwnerInvitationCount={pendingOwnerInvitationCount}
                lookupAvailable={lookupAvailable}
                lookupWarning={lookupWarning}
                onSuccess={({ role }) => {
                  setSuccess(
                    `Invitation sent for ${role === "OWNER" ? "Owner" : role === "EXEC" ? "Executive" : "Member"}.`,
                  );
                  loadPage();
                }}
              />
            ) : null
          }
        />
      ) : null}

      {activeTab === "announcements" ? (
        <ClubAnnouncementsPanel
          club={club}
          membership={membership}
          annual={annual}
          isSacAdmin={isSacAdmin}
        />
      ) : null}

      {activeTab === "funding" ? (
        <div
          id="manage-panel-funding"
          role="tabpanel"
          aria-labelledby="manage-tab-funding"
          className="stack"
        >
          <section className="panel">
            <h2>Funding request</h2>
            <p className="muted">
              Request school-related materials for your club. Food or
              beverages for internal club use and clothing are not eligible.
            </p>
            <ClubFundingForm
              club={club}
              canSubmit={canSubmitRequests}
              canView={canViewRequests}
              blockedMessage={requestBlockedMessage}
            />
          </section>
        </div>
      ) : null}

      {activeTab === "events" ? (
        <div
          id="manage-panel-events"
          role="tabpanel"
          aria-labelledby="manage-tab-events"
          className="stack"
        >
          <section className="panel">
            <h2>Event proposal</h2>
            <p className="muted">
              Submit an event proposal for SAC review and potential approval.
            </p>
            <ClubEventForm
              club={club}
              canSubmit={canSubmitRequests}
              canView={canViewRequests}
              blockedMessage={requestBlockedMessage}
            />
          </section>
        </div>
      ) : null}

      {activeTab === "promoLunch" ? (
        <div
          id="manage-panel-promoLunch"
          role="tabpanel"
          aria-labelledby="manage-tab-promoLunch"
          className="stack"
        >
          <section className="panel">
            <h2>Club Promo Lunch sign-up</h2>
            <p className="muted">
              Submit your club&apos;s booth information for review and
              confirmation.
            </p>
            <ClubPromoLunchForm
              club={club}
              canSubmit={canSubmitRequests}
              canView={canViewRequests}
              blockedMessage={requestBlockedMessage}
            />
          </section>
        </div>
      ) : null}

      <ArchiveClubDialog
        open={archiveOpen}
        club={club}
        onClose={() => setArchiveOpen(false)}
        onSuccess={({ clubName, outcome }) => {
          navigate("/clubs", {
            replace: true,
            state: {
              notice: archiveSuccessNotice(clubName, outcome),
            },
          });
        }}
      />

      <ConfirmDialog
        open={withdrawOpen}
        title="Withdraw re-application?"
        confirmLabel="Withdraw"
        destructive
        busy={withdrawBusy}
        onCancel={() => setWithdrawOpen(false)}
        onConfirm={async () => {
          if (!approvedReappId || withdrawBusy) return;
          setWithdrawBusy(true);
          setError("");
          try {
            await withdrawClubReapplication(approvedReappId);
            navigate("/clubs/my-clubs", {
              replace: true,
              state: {
                notice:
                  "Re-application withdrawn. The club is inactive again and available for future re-application.",
              },
            });
          } catch (withdrawError) {
            setError(
              getErrorMessage(
                withdrawError,
                "Could not withdraw this re-application.",
              ),
            );
            setWithdrawOpen(false);
          } finally {
            setWithdrawBusy(false);
          }
        }}
      >
        <p>
          This will cancel this club application and return the club to inactive
          status. The club history will remain and students may apply again in
          the future.
        </p>
      </ConfirmDialog>

      <ChangeRoleDialog
        open={Boolean(changeTarget)}
        membership={changeTarget}
        clubName={club.name}
        currentUserRole={membership?.role}
        isSacAdmin={isSacAdmin}
        onClose={() => setChangeTarget(null)}
        onSuccess={({ role }) => {
          setSuccess(
            role === "EXEC"
              ? "Member promoted to Executive."
              : "Executive changed to Member.",
          );
          loadPage();
        }}
      />

      <RemoveMemberDialog
        open={Boolean(removeTarget)}
        membership={removeTarget}
        clubName={club.name}
        currentUserId={user.id}
        onClose={() => setRemoveTarget(null)}
        onSuccess={({ isSelf }) => {
          setSuccess(
            isSelf
              ? `You left ${club.name}.`
              : "Student removed from the club.",
          );
          if (isSelf && !isAdmin) {
            navigate(`/clubs/${club.slug}`, { replace: true });
            return;
          }
          loadPage();
        }}
      />
    </div>
  );
}
