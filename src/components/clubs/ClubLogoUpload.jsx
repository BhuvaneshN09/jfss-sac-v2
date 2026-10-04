import { useState } from "react";
import { LocalFilePreview } from "../ui/LocalFilePreview";
import { FilePicker } from "../ui/FilePicker";
import { validateClubLogoFile } from "../../services/clubLogos";
import { toSameOriginSupabaseUrl } from "../../utils/proxiedSupabaseUrl";

/** Club logo uploader styled like the signed teacher-supervisor form control. */
export function ClubLogoUpload({
  id = "club-logo",
  label = "Club logo",
  file,
  onChange,
  error,
  disabled = false,
  required = false,
  currentUrl = null,
}) {
  const [localError, setLocalError] = useState("");
  const previewUrl = toSameOriginSupabaseUrl(currentUrl);

  function handleFileChange(next) {
    const validationError = next ? validateClubLogoFile(next) : null;
    setLocalError(validationError || "");
    onChange?.(validationError ? null : next);
  }

  return (
    <div className="stack">
      <FilePicker
        id={id}
        label={label}
        accept="image/jpeg,image/png,image/webp"
        disabled={disabled}
        required={required}
        files={file}
        buttonLabel="Choose image"
        emptyLabel="No image chosen"
        hint="JPEG, PNG, or WebP · max 5 MB"
        error={localError || error || undefined}
        onChange={handleFileChange}
      />
      {file ? (
        <div className="signed-form-preview">
          <p className="muted">Selected image preview</p>
          <LocalFilePreview
            file={file}
            disabled={disabled}
            alt="Selected club logo"
            removeLabel="Remove image"
            onRemove={() => {
              setLocalError("");
              onChange?.(null);
            }}
          />
        </div>
      ) : previewUrl ? (
        <div className="signed-form-preview">
          <p className="muted">Current club photo</p>
          <img
            src={previewUrl}
            alt="Current club logo"
            className="logo-preview"
          />
        </div>
      ) : null}
    </div>
  );
}
