export function FormField({
  id,
  label,
  error,
  hint,
  required = false,
  children,
}) {
  return (
    <div className={`form-field${error ? " form-field--error" : ""}`}>
      <label htmlFor={id}>
        {label}
        {required ? <span className="required-mark"> *</span> : null}
      </label>
      {children}
      {hint && !error ? <p className="form-hint">{hint}</p> : null}
      {error ? (
        <p className="form-error" role="alert" id={`${id}-error`}>
          {error}
        </p>
      ) : null}
    </div>
  );
}
