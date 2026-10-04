import { useState } from "react";
import { LocalFilePreview } from "../ui/LocalFilePreview";
import { FilePicker } from "../ui/FilePicker";
import { validateSignedFormFile } from "../../services/clubDocuments";

export function SignedFormUpload({
  id = "signed-form",
  label = "Signed Teacher Supervisor Form image",
  file,
  onChange,
  error,
  disabled = false,
  required = true,
}) {
  const [localError, setLocalError] = useState("");

  function handleFileChange(next) {
    const validationError = next ? validateSignedFormFile(next) : null;
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
        hint="JPEG, PNG, or WebP · max 10 MB"
        error={localError || error || undefined}
        onChange={handleFileChange}
      />
      {file ? (
        <div className="signed-form-preview">
          <p className="muted">Selected image preview</p>
          <LocalFilePreview
            file={file}
            disabled={disabled}
            alt="Selected signed teacher supervisor form"
            removeLabel="Remove image"
            onRemove={() => {
              setLocalError("");
              onChange?.(null);
            }}
          />
        </div>
      ) : null}
    </div>
  );
}
