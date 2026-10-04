/* eslint-disable react-hooks/set-state-in-effect */
import { useEffect, useState } from "react";
import { ConfirmDialog } from "../ui/ConfirmDialog";
import { ErrorMessage } from "../ui/ErrorMessage";
import { archiveAnnouncement } from "../../services/announcements";
import { getErrorMessage } from "../../utils/errors";

export function ArchiveAnnouncementDialog({
  open,
  announcement,
  onClose,
  onSuccess,
}) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!open) return;
    setBusy(false);
    setError("");
  }, [open, announcement?.id]);

  async function handleConfirm() {
    if (!announcement || busy) return;
    setBusy(true);
    setError("");

    try {
      await archiveAnnouncement(announcement.id);
      onSuccess?.(announcement);
      onClose?.();
    } catch (archiveError) {
      setError(
        getErrorMessage(archiveError, "Could not archive this announcement."),
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <ConfirmDialog
      open={open}
      title="Archive announcement"
      confirmLabel="Archive announcement"
      onCancel={onClose}
      onConfirm={handleConfirm}
      busy={busy}
      destructive
    >
      <p>
        Archive <strong>{announcement?.title}</strong>?
      </p>
      <ul className="dialog-list">
        <li>It will disappear from the homepage and public feed.</li>
        <li>The database row will remain for history.</li>
        <li>This does not permanently delete the announcement.</li>
      </ul>
      {error ? <ErrorMessage>{error}</ErrorMessage> : null}
    </ConfirmDialog>
  );
}
