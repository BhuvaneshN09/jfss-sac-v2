export function Spinner({ label = "Loading", size = "md" }) {
  return (
    <span
      className={`spinner spinner--${size}`}
      role="status"
      aria-live="polite"
      aria-label={label}
    >
      <span className="spinner__visual" aria-hidden="true" />
      <span className="sr-only">{label}</span>
    </span>
  );
}
