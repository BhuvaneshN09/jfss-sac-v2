import { getClubRoleLabel } from "../../utils/clubPermissions";

export function ClubRoleBadge({ role }) {
  const label = getClubRoleLabel(role);
  const tone = String(role || "unknown")
    .toLowerCase()
    .replace(/_/g, "-");

  return (
    <span className={`badge badge--role badge--role-${tone}`}>
      <span aria-hidden="true">{label}</span>
      <span className="sr-only">Club role: {label}</span>
    </span>
  );
}
