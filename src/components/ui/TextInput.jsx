import { FormField } from "./FormField";

export function TextInput({
  id,
  label,
  error,
  hint,
  required = false,
  type = "text",
  ...props
}) {
  return (
    <FormField id={id} label={label} error={error} hint={hint} required={required}>
      <input
        id={id}
        type={type}
        className="input"
        aria-invalid={Boolean(error)}
        aria-describedby={error ? `${id}-error` : undefined}
        required={required}
        {...props}
      />
    </FormField>
  );
}
