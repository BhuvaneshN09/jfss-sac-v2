const STATUS_LABELS = {
  ACTIVE: "Active",
  INACTIVE: "Inactive",
};

export function MembershipStatusBadge({ status }) {
  const label = STATUS_LABELS[status] || status;
  const tone = String(status || "unknown").toLowerCase();

  return (
    <span className={`badge badge--status badge--${tone}`}>
      <span aria-hidden="true">{label}</span>
      <span className="sr-only">Membership status: {label}</span>
    </span>
  );
}
