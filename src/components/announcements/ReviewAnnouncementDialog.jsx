/* eslint-disable react-hooks/set-state-in-effect */
import { useEffect, useState } from "react";
import { ConfirmDialog } from "../ui/ConfirmDialog";
import { ErrorMessage } from "../ui/ErrorMessage";
import { TextArea } from "../ui/TextArea";
import { getErrorMessage } from "../../utils/errors";

export function ReviewAnnouncementDialog({
  open,
  title,
  confirmLabel,
  requireNotes = false,
  notesLabel = "Review notes",
  onCancel,
  onConfirm,
  busy = false,
}) {
  const [notes, setNotes] = useState("");
  const [error, setError] = useState("");

  useEffect(() => {
    if (!open) return;
    setNotes("");
    setError("");
  }, [open]);

  async function handleConfirm() {
    if (requireNotes && !notes.trim()) {
      setError("Review notes are required for this action.");
      return;
    }

    try {
      await onConfirm?.(notes.trim() || null);
    } catch (confirmError) {
      setError(
        getErrorMessage(confirmError, "Could not complete this review action."),
      );
    }
  }

  return (
    <ConfirmDialog
      open={open}
      title={title}
      confirmLabel={confirmLabel}
      onCancel={onCancel}
      onConfirm={handleConfirm}
      busy={busy}
      confirmDisabled={requireNotes && !notes.trim()}
      destructive={confirmLabel.toLowerCase().includes("reject")}
    >
      <TextArea
        id="review-notes"
        label={notesLabel}
        value={notes}
        onChange={(event) => setNotes(event.target.value)}
        rows={4}
        required={requireNotes}
        hint={requireNotes ? "Required" : "Optional"}
      />
      {error ? <ErrorMessage>{error}</ErrorMessage> : null}
    </ConfirmDialog>
  );
}
