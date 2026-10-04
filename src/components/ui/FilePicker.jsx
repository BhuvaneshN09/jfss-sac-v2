import { useId, useRef } from "react";

function formatFileSize(bytes) {
  const size = Number(bytes) || 0;
  if (size < 1024) return `${size} B`;
  if (size < 1024 * 1024) return `${Math.round(size / 1024)} KB`;
  return `${(size / (1024 * 1024)).toFixed(1)} MB`;
}

/**
 * Styled file chooser. Hides the native control and shows a button + filename.
 * Supports single or multiple selection.
 */
export function FilePicker({
  id,
  label,
  accept,
  multiple = false,
  disabled = false,
  required = false,
  hint,
  error,
  buttonLabel = "Choose file",
  emptyLabel = "No file chosen",
  files = null,
  onChange,
  className = "",
}) {
  const generatedId = useId();
  const inputId = id || generatedId;
  const inputRef = useRef(null);

  const selected = (() => {
    if (Array.isArray(files)) return files.filter(Boolean);
    if (files) return [files];
    return [];
  })();

  function handleChange(event) {
    const list = Array.from(event.target.files || []);
    if (multiple) {
      onChange?.(list, event);
    } else {
      onChange?.(list[0] || null, event);
    }
    // Allow re-selecting the same file after remove.
    event.target.value = "";
  }

  return (
    <div
      className={`form-field file-picker${error ? " form-field--error" : ""} ${className}`.trim()}
    >
      {label ? (
        <label htmlFor={inputId}>
          {label}
          {required ? <span className="required-mark"> *</span> : null}
        </label>
      ) : null}

      <input
        ref={inputRef}
        id={inputId}
        type="file"
        className="file-picker__input"
        accept={accept}
        multiple={multiple}
        disabled={disabled}
        required={required && selected.length === 0}
        onChange={handleChange}
      />

      <div className="file-picker__row">
        <button
          type="button"
          className="button button--secondary file-picker__button"
          disabled={disabled}
          onClick={() => inputRef.current?.click()}
        >
          {buttonLabel}
        </button>
        <span className="file-picker__meta" aria-live="polite">
          {selected.length === 0 ? (
            emptyLabel
          ) : selected.length === 1 ? (
            <>
              <span className="file-picker__name">{selected[0].name}</span>
              <span className="muted">
                {" "}
                · {formatFileSize(selected[0].size)}
              </span>
            </>
          ) : (
            <span className="file-picker__name">
              {selected.length} files selected
            </span>
          )}
        </span>
      </div>

      {hint && !error ? <p className="form-hint">{hint}</p> : null}
      {error ? (
        <p className="form-error" role="alert">
          {error}
        </p>
      ) : null}
    </div>
  );
}
