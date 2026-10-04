import { useMemo, useState } from "react";
import { ErrorMessage } from "../ui/ErrorMessage";
import { PermissionNotice } from "../ui/PermissionNotice";
import { Select } from "../ui/Select";
import { TextInput } from "../ui/TextInput";
import { Spinner } from "../ui/Spinner";
import {
  canAddClubRole,
  getInvitableRoles,
  getClubRoleLabel,
  isValidPdsbEmail,
  normalizePdsbEmail,
} from "../../utils/clubPermissions";
import { createClubMembershipInvitation } from "../../services/clubInvitations";
import { getErrorMessage } from "../../utils/errors";

export function AddClubMemberForm({
  club,
  currentUserId,
  currentUserRole,
  isSacAdmin = false,
  existingMemberships = [],
  pendingOwnerInvitationCount = 0,
  lookupAvailable = false,
  lookupWarning = null,
  onSuccess,
}) {
  const activeOwnerCount = useMemo(
    () =>
      (existingMemberships || []).filter(
        (row) => row.role === "OWNER" && row.status === "ACTIVE",
      ).length,
    [existingMemberships],
  );

  const addableRoles = useMemo(
    () =>
      getInvitableRoles({
        currentUserRole,
        isSacAdmin,
        activeOwnerCount,
        pendingOwnerInvitationCount,
      }),
    [
      currentUserRole,
      isSacAdmin,
      activeOwnerCount,
      pendingOwnerInvitationCount,
    ],
  );

  const [email, setEmail] = useState("");
  const [role, setRole] = useState("MEMBER");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");

  const selectedRole = addableRoles.includes(role)
    ? role
    : addableRoles.includes("MEMBER")
      ? "MEMBER"
      : addableRoles[0] || "MEMBER";

  async function handleSubmit(event) {
    event.preventDefault();
    if (busy) return;

    setError("");
    setSuccess("");

    if (!currentUserId) {
      setError("You must be signed in to send invitations.");
      return;
    }

    if (!club?.id) {
      setError("A club is required.");
      return;
    }

    const normalized = normalizePdsbEmail(email);
    if (!normalized) {
      setError("Enter the student’s complete PDSB email address.");
      return;
    }

    if (!isValidPdsbEmail(normalized)) {
      setError("Enter the student’s complete @pdsb.net email address.");
      return;
    }

    if (!["OWNER", "EXEC", "MEMBER"].includes(selectedRole)) {
      setError("Choose a valid position.");
      return;
    }

    if (
      !canAddClubRole({
        currentUserRole,
        newRole: selectedRole,
        isSacAdmin,
        activeOwnerCount,
        pendingOwnerInvitationCount,
      })
    ) {
      setError(
        "You do not have permission to invite someone to that position.",
      );
      return;
    }

    setBusy(true);

    try {
      await createClubMembershipInvitation({
        clubId: club.id,
        email: normalized,
        offeredRole: selectedRole,
      });

      setEmail("");
      setSuccess(
        `Invitation sent for ${getClubRoleLabel(selectedRole)}. The student must accept before joining.`,
      );
      onSuccess?.({
        role: selectedRole,
        email: normalized,
      });
    } catch (submitError) {
      setError(getErrorMessage(submitError, "Could not send this invitation."));
    } finally {
      setBusy(false);
    }
  }

  if (addableRoles.length === 0) {
    return (
      <PermissionNotice title="Cannot invite people">
        Only active club owners can send membership invitations.
      </PermissionNotice>
    );
  }

  return (
    <section className="panel add-member-panel">
      <h2>Add person</h2>
      <p className="muted">
        Enter a complete @pdsb.net email and choose a position. Sending creates
        a pending invitation — membership is added only after the student
        accepts. The school directory cannot be browsed.
      </p>

      <form className="stack" onSubmit={handleSubmit} noValidate>
        <TextInput
          id="add-person-email"
          type="email"
          label="Email"
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          placeholder=" p#######@pdsb.net"
          required
          disabled={busy}
          autoComplete="off"
        />

        <Select
          id="add-person-role"
          label="Position"
          value={selectedRole}
          onChange={(event) => setRole(event.target.value)}
          required
          disabled={busy}
        >
          {addableRoles
            .slice(0)
            .reverse()
            .map((option) => (
              <option key={option} value={option}>
                {getClubRoleLabel(option)}
              </option>
            ))}
        </Select>

        <div className="button-row">
          <button
            type="submit"
            className="button button--primary"
            disabled={busy || !email.trim()}
          >
            {busy ? <Spinner size="sm" label="Sending" /> : null}
            {busy ? "Sending…" : "Send request"}
          </button>
        </div>
      </form>

      {!lookupAvailable && lookupWarning ? (
        <PermissionNotice title="Student lookup unavailable">
          {lookupWarning}
        </PermissionNotice>
      ) : null}

      {error ? <ErrorMessage>{error}</ErrorMessage> : null}
      {success ? (
        <div className="alert alert--success" role="status">
          <strong>Success</strong>
          <p>{success}</p>
        </div>
      ) : null}
    </section>
  );
}
