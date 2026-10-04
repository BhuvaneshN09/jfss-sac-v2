const ROLE_LABELS = {
  OWNER: "Owner",
  EXEC: "Executive",
  MEMBER: "Member",
  SITE_ADMIN: "Site Admin",
};

export function RoleBadge({ role }) {
  const label = ROLE_LABELS[role] || role;
  const tone = String(role || "unknown")
    .toLowerCase()
    .replace(/_/g, "-");

  return (
    <span className={`badge badge--role badge--role-${tone}`}>
      <span aria-hidden="true">{label}</span>
      <span className="sr-only">Role: {label}</span>
    </span>
  );
}
