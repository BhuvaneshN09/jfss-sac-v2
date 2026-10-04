import { FormField } from "./FormField";

export function Select({
  id,
  label,
  error,
  hint,
  required = false,
  children,
  ...props
}) {
  return (
    <FormField id={id} label={label} error={error} hint={hint} required={required}>
      <select
        id={id}
        className="select"
        aria-invalid={Boolean(error)}
        aria-describedby={error ? `${id}-error` : undefined}
        required={required}
        {...props}
      >
        {children}
      </select>
    </FormField>
  );
}
