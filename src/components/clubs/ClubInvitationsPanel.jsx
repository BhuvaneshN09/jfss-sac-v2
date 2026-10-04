import { useState } from "react";
import { ClubRoleBadge } from "./ClubRoleBadge";
import { EmptyState } from "../ui/EmptyState";
import { ErrorMessage } from "../ui/ErrorMessage";
import { Spinner } from "../ui/Spinner";
import {
  acceptClubMembershipInvitation,
  rejectClubMembershipInvitation,
} from "../../services/clubInvitations";
import { getClubRoleLabel } from "../../utils/clubPermissions";
import { formatDate } from "../../utils/format";
import { getErrorMessage } from "../../utils/errors";

export function ClubInvitationsPanel({ invitations, onChanged }) {
  const [busyId, setBusyId] = useState(null);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");

  async function respond(invitation, action) {
    if (busyId) return;
    setBusyId(invitation.id);
    setError("");
    setSuccess("");

    try {
      if (action === "accept") {
        await acceptClubMembershipInvitation(invitation.id);
        setSuccess(
          `You joined ${invitation.clubs?.name || "the club"} as ${getClubRoleLabel(invitation.offered_role)}.`,
        );
      } else {
        await rejectClubMembershipInvitation(invitation.id);
        setSuccess("Invitation rejected.");
      }
      onChanged?.();
    } catch (respondError) {
      setError(
        getErrorMessage(
          respondError,
          action === "accept"
            ? "Could not accept this invitation."
            : "Could not reject this invitation.",
        ),
      );
    } finally {
      setBusyId(null);
    }
  }

  return (
    <section className="panel" aria-labelledby="club-invitations-title">
      <h2 id="club-invitations-title">Club invitations</h2>
      <p className="muted">
        Accept to join with the offered position, or reject to decline.
      </p>

      {error ? <ErrorMessage>{error}</ErrorMessage> : null}
      {success ? (
        <div className="alert alert--success" role="status">
          <strong>Success</strong>
          <p>{success}</p>
        </div>
      ) : null}

      {!invitations?.length ? (
        <EmptyState title="No pending invitations">
          When a club owner invites you, the request appears here.
        </EmptyState>
      ) : (
        <ul className="stack card-list">
          {invitations.map((invitation) => {
            const club = invitation.clubs;
            const inviter =
              invitation.inviter?.full_name ||
              invitation.inviter?.email ||
              "A club owner";
            const busy = busyId === invitation.id;

            return (
              <li key={invitation.id} className="card">
                <div className="section-heading">
                  <div className="badge-row" style={{ alignItems: "center" }}>
                    <div>
                      <h3>{club?.name || "Club"}</h3>
                      <p className="muted">
                        Invited by {inviter} · {formatDate(invitation.created_at)}
                      </p>
                    </div>
                  </div>
                  <ClubRoleBadge role={invitation.offered_role} />
                </div>

                <p>
                  Offered position:{" "}
                  <strong>{getClubRoleLabel(invitation.offered_role)}</strong>
                </p>

                <div className="button-row">
                  <button
                    type="button"
                    className="button button--primary"
                    disabled={Boolean(busyId)}
                    onClick={() => respond(invitation, "accept")}
                  >
                    {busy ? <Spinner size="sm" label="Accepting" /> : null}
                    Accept
                  </button>
                  <button
                    type="button"
                    className="button button--secondary"
                    disabled={Boolean(busyId)}
                    onClick={() => respond(invitation, "reject")}
                  >
                    Reject
                  </button>
                </div>
              </li>
            );
          })}
        </ul>
      )}
    </section>
  );
}
