/* eslint-disable react-hooks/set-state-in-effect */
import { useEffect, useState } from "react";
import { ConfirmDialog } from "../ui/ConfirmDialog";
import { ErrorMessage } from "../ui/ErrorMessage";
import { getClubRoleLabel } from "../../utils/clubPermissions";
import { removeClubMembership } from "../../services/memberships";
import { getErrorMessage } from "../../utils/errors";

export function RemoveMemberDialog({
  open,
  membership,
  clubName,
  currentUserId,
  onClose,
  onSuccess,
}) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!open) return;
    setBusy(false);
    setError("");
  }, [open, membership]);

  const displayName =
    membership?.profile?.full_name ||
    membership?.profile?.email ||
    membership?.user_id;
  const isSelf = membership?.user_id === currentUserId;

  async function handleConfirm() {
    if (!membership) return;

    if (membership.role === "OWNER") {
      setError("The owner membership cannot be removed through this workflow.");
      return;
    }

    setBusy(true);
    setError("");

    try {
      await removeClubMembership({
        clubId: membership.club_id,
        userId: membership.user_id,
      });
      onSuccess?.({
        userId: membership.user_id,
        label: displayName,
        isSelf,
      });
      onClose?.();
    } catch (removeError) {
      setError(
        getErrorMessage(removeError, "Could not remove this club membership."),
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <ConfirmDialog
      open={open}
      title={isSelf ? "Leave club" : "Remove club member"}
      confirmLabel={isSelf ? "Leave club" : "Remove member"}
      onCancel={onClose}
      onConfirm={handleConfirm}
      busy={busy}
    >
      <p>
        {isSelf ? (
          <>
            Leave <strong>{clubName}</strong> as{" "}
            <strong>{getClubRoleLabel(membership?.role)}</strong>?
          </>
        ) : (
          <>
            Remove <strong>{displayName}</strong> from{" "}
            <strong>{clubName}</strong>?
          </>
        )}
      </p>
      <ul className="dialog-list">
        <li>
          Student: <code>{displayName}</code>
        </li>
        <li>Club: {clubName}</li>
        <li>Current role: {getClubRoleLabel(membership?.role)}</li>
      </ul>
      <p className="muted">
        This removes access to club management features tied to this membership.
      </p>
      {error ? <ErrorMessage>{error}</ErrorMessage> : null}
    </ConfirmDialog>
  );
}
