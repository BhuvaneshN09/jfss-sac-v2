/* eslint-disable react-hooks/set-state-in-effect */
import { useEffect, useState } from "react";
import { ConfirmDialog } from "../ui/ConfirmDialog";
import { ErrorMessage } from "../ui/ErrorMessage";
import { TextInput } from "../ui/TextInput";
import { StatusBadge } from "../ui/StatusBadge";
import { archiveOwnedClub } from "../../services/clubs";
import {
  archiveOutcomeForClub,
  isNewApplicationClub,
} from "../../utils/clubOrigin";
import { getErrorMessage } from "../../utils/errors";

/** Owner archive confirmation — copy branches on immutable creation origin. */
export function ArchiveClubDialog({ open, club, onClose, onSuccess }) {
  const [confirmation, setConfirmation] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!open) return;
    setConfirmation("");
    setBusy(false);
    setError("");
  }, [open, club?.id]);

  const nameMatches =
    Boolean(club?.name) && confirmation.trim() === club.name.trim();
  const terminal = isNewApplicationClub(club);

  async function handleConfirm() {
    if (!club || busy || !nameMatches) return;

    setBusy(true);
    setError("");

    try {
      await archiveOwnedClub(club.id);
      onSuccess?.({
        clubName: club.name,
        outcome: archiveOutcomeForClub(club),
      });
      onClose?.();
    } catch (archiveError) {
      setError(
        getErrorMessage(archiveError, "Could not archive this club."),
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <ConfirmDialog
      open={open}
      title="Archive club"
      confirmLabel="Archive Club"
      onCancel={onClose}
      onConfirm={handleConfirm}
      busy={busy}
      confirmDisabled={!nameMatches}
      destructive
    >
      {terminal ? (
        <>
          <p>
            Archiving this club permanently removes it from the portal. Because
            it was created through a new-club application, it will not be
            available for reapplication.
          </p>
          <ul className="dialog-list">
            <li>
              Club: <strong>{club?.name}</strong>
            </li>
            <li>
              Current status: <StatusBadge status={club?.status} />
            </li>
            <li>
              It leaves Explore, My Clubs, Manage Club, and public club pages.
            </li>
            <li>All active memberships and the school-year record deactivate.</li>
            <li>Unfinished supervisor requests are cancelled.</li>
            <li>
              Internal application and audit records are preserved, but the club
              can never become reapplication-eligible again.
            </li>
          </ul>
        </>
      ) : (
        <>
          <p>
            Archiving this club marks it inactive for the current school year.
            The club identity and history remain, and it may later be eligible
            for reapplication.
          </p>
          <ul className="dialog-list">
            <li>
              Club: <strong>{club?.name}</strong>
            </li>
            <li>
              Current status: <StatusBadge status={club?.status} />
            </li>
            <li>
              The club leaves Explore and public club pages for this school year.
            </li>
            <li>
              OWNER, EXEC, and MEMBER roles become inactive (history is
              preserved).
            </li>
            <li>
              Future students can select this club on re-application when it is
              eligible.
            </li>
          </ul>
        </>
      )}

      <TextInput
        id="archive-club-confirmation"
        label={`Type “${club?.name || "club name"}” to confirm`}
        value={confirmation}
        onChange={(event) => setConfirmation(event.target.value)}
        autoComplete="off"
        required
      />

      {error ? <ErrorMessage>{error}</ErrorMessage> : null}
    </ConfirmDialog>
  );
}
