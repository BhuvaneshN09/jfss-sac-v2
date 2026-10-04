import { FormField } from "./FormField";

export function TextArea({
  id,
  label,
  error,
  hint,
  required = false,
  rows = 4,
  ...props
}) {
  return (
    <FormField id={id} label={label} error={error} hint={hint} required={required}>
      <textarea
        id={id}
        className="textarea"
        rows={rows}
        aria-invalid={Boolean(error)}
        aria-describedby={error ? `${id}-error` : undefined}
        required={required}
        {...props}
      />
    </FormField>
  );
}
