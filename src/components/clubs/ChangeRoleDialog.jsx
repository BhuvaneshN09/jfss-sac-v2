/* eslint-disable react-hooks/set-state-in-effect */
import { useEffect, useState } from "react";
import { ConfirmDialog } from "../ui/ConfirmDialog";
import { ErrorMessage } from "../ui/ErrorMessage";
import { Select } from "../ui/Select";
import {
  canChangeMemberRole,
  getClubRoleLabel,
} from "../../utils/clubPermissions";
import { updateClubMembershipRole } from "../../services/memberships";
import { getErrorMessage } from "../../utils/errors";

export function ChangeRoleDialog({
  open,
  membership,
  clubName,
  currentUserRole,
  isSacAdmin = false,
  onClose,
  onSuccess,
}) {
  const [newRole, setNewRole] = useState("MEMBER");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!open || !membership) return;
    setNewRole(membership.role === "EXEC" ? "MEMBER" : "EXEC");
    setBusy(false);
    setError("");
  }, [open, membership]);

  const displayName =
    membership?.profile?.full_name ||
    membership?.profile?.email ||
    membership?.user_id;

  async function handleConfirm() {
    if (!membership) return;

    if (
      !canChangeMemberRole({
        currentUserRole,
        targetCurrentRole: membership.role,
        targetNewRole: newRole,
        isSacAdmin,
      })
    ) {
      setError("You do not have permission to change this member’s role.");
      return;
    }

    setBusy(true);
    setError("");

    try {
      await updateClubMembershipRole({
        clubId: membership.club_id,
        userId: membership.user_id,
        role: newRole,
      });
      onSuccess?.({
        userId: membership.user_id,
        label: displayName,
        role: newRole,
      });
      onClose?.();
    } catch (updateError) {
      setError(
        getErrorMessage(
          updateError,
          "You do not have permission to change this member’s role.",
        ),
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <ConfirmDialog
      open={open}
      title="Change member role"
      confirmLabel="Change role"
      onCancel={onClose}
      onConfirm={handleConfirm}
      busy={busy}
      confirmDisabled={!membership || newRole === membership?.role}
    >
      <p>
        Change the club role for <strong>{displayName}</strong> in{" "}
        <strong>{clubName}</strong>.
      </p>
      <p className="muted">
        Current role: {getClubRoleLabel(membership?.role)}
      </p>

      <Select
        id="change-member-role"
        label="New role"
        value={newRole}
        onChange={(event) => setNewRole(event.target.value)}
        required
      >
        <option value="EXEC">{getClubRoleLabel("EXEC")}</option>
        <option value="MEMBER">{getClubRoleLabel("MEMBER")}</option>
      </Select>

      {error ? <ErrorMessage>{error}</ErrorMessage> : null}
    </ConfirmDialog>
  );
}
