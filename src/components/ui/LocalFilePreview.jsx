/* eslint-disable react-hooks/set-state-in-effect */
import { useEffect, useState } from "react";
import { AttachmentPreview } from "./AttachmentPreview";

/** Local File object preview (before upload). */
export function LocalFilePreview({
  file,
  onRemove,
  alt = "Selected file preview",
  disabled = false,
  removeLabel = "Remove",
}) {
  const [objectUrl, setObjectUrl] = useState("");

  useEffect(() => {
    if (!file) {
      setObjectUrl("");
      return undefined;
    }
    const next = URL.createObjectURL(file);
    setObjectUrl(next);
    return () => URL.revokeObjectURL(next);
  }, [file]);

  if (!file || !objectUrl) return null;

  return (
    <div className="attachment-preview attachment-preview--local">
      <AttachmentPreview
        url={objectUrl}
        mimeType={file.type}
        filename={file.name}
        alt={alt}
      />
      {onRemove ? (
        <button
          type="button"
          className="button button--secondary"
          disabled={disabled}
          onClick={onRemove}
        >
          {removeLabel}
        </button>
      ) : null}
    </div>
  );
}
