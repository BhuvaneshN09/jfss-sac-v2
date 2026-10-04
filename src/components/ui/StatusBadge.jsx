const STATUS_LABELS = {
  DRAFT: "Draft",
  SUBMITTED: "Submitted",
  UNDER_REVIEW: "Under review",
  CHANGES_REQUESTED: "Changes requested",
  APPROVED: "Approved",
  PUBLISHED: "Published",
  REJECTED: "Rejected",
  WITHDRAWN: "Withdrawn",
  CANCELLED: "Cancelled",
  ACTIVE: "Active",
  INACTIVE: "Inactive",
  SUSPENDED: "Suspended",
  ARCHIVED: "Archived",
  PENDING_SUPERVISOR: "Pending supervisor",
  PENDING_TEACHER_SUPERVISOR: "Pending Teacher Supervisor",
};

export function StatusBadge({ status, prefix = "" }) {
  const label = STATUS_LABELS[status] || status;
  const tone = String(status || "unknown")
    .toLowerCase()
    .replace(/_/g, "-");

  return (
    <span className={`badge badge--status badge--${tone}`}>
      <span className="badge__label" aria-hidden="true">
        {prefix}
        {label}
      </span>
      <span className="sr-only">Status: {label}</span>
    </span>
  );
}
