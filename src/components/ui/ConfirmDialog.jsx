import { useEffect, useId, useRef } from "react";
import { Spinner } from "./Spinner";

export function ConfirmDialog({
  open,
  title,
  children,
  confirmLabel = "Confirm",
  cancelLabel = "Cancel",
  onConfirm,
  onCancel,
  busy = false,
  confirmDisabled = false,
  destructive = false,
}) {
  const titleId = useId();
  const dialogRef = useRef(null);

  useEffect(() => {
    if (!open) return undefined;

    const previouslyFocused = document.activeElement;
    const node = dialogRef.current;
    node?.focus();

    function onKeyDown(event) {
      if (event.key === "Escape" && !busy) {
        onCancel?.();
      }
    }

    document.addEventListener("keydown", onKeyDown);

    return () => {
      document.removeEventListener("keydown", onKeyDown);
      if (previouslyFocused instanceof HTMLElement) {
        previouslyFocused.focus();
      }
    };
  }, [open, busy, onCancel]);

  if (!open) return null;

  return (
    <div className="dialog-backdrop" role="presentation">
      <div
        className="dialog"
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        tabIndex={-1}
        ref={dialogRef}
      >
        <h2 id={titleId}>{title}</h2>
        <div className="dialog__body">{children}</div>
        <div className="dialog__actions">
          <button
            type="button"
            className="button button--secondary"
            onClick={onCancel}
            disabled={busy}
          >
            {cancelLabel}
          </button>
          <button
            type="button"
            className={`button ${destructive ? "button--danger" : "button--primary"}`}
            onClick={onConfirm}
            disabled={busy || confirmDisabled}
          >
            {busy ? (
              <>
                <Spinner size="sm" label="Working" /> Working…
              </>
            ) : (
              confirmLabel
            )}
          </button>
        </div>
      </div>
    </div>
  );
}
