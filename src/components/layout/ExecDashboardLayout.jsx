import { NavLink, Outlet, useLocation } from "react-router-dom";
import { useAuth } from "../../context/AuthContext";

const PRIMARY_TABS = [
  {
    id: "new-applications",
    to: "/exec-dashboard/applications/new",
    label: "New Club Applications",
    matchPrefix: "/exec-dashboard/applications/new",
    visible: ({ isSacAdmin, isSacExec, isFacultyAdvisor }) =>
      isSacAdmin || isSacExec || isFacultyAdvisor,
  },
  {
    id: "reapplications",
    to: "/exec-dashboard/applications/reapplications",
    label: "Reapplications",
    matchPrefix: "/exec-dashboard/applications/reapplications",
    visible: ({ isSacAdmin, isSacExec, isFacultyAdvisor }) =>
      isSacAdmin || isSacExec || isFacultyAdvisor,
  },
  {
    id: "requests",
    to: "/exec-dashboard/requests/announcements",
    label: "Requests",
    matchPrefix: "/exec-dashboard/requests",
    visible: ({ isSacAdmin, isSacExec, isFacultyAdvisor }) =>
      isSacAdmin || isSacExec || isFacultyAdvisor,
  },
  {
    id: "school-day",
    to: "/exec-dashboard/school-day",
    label: "School Day",
    matchPrefix: "/exec-dashboard/school-day",
    visible: ({ isSacAdmin, isSacExec }) => isSacAdmin || isSacExec,
  },
  {
    id: "archived",
    to: "/exec-dashboard/archived/clubs",
    label: "Archived",
    matchPrefix: "/exec-dashboard/archived",
    visible: ({ isSacAdmin, isSacExec }) => isSacAdmin || isSacExec,
  },
];

function isPathActive(pathname, prefix) {
  return pathname === prefix || pathname.startsWith(`${prefix}/`);
}

export function ExecDashboardLayout() {
  const { canMutateReviews, isSacExec, isSacAdmin, isFacultyAdvisor } =
    useAuth();
  const { pathname } = useLocation();

  const roleFlags = { isSacAdmin, isSacExec, isFacultyAdvisor };
  const primaryTabs = PRIMARY_TABS.filter((tab) => tab.visible(roleFlags));

  return (
    <div className="page">
      {!canMutateReviews ? (
        <div className="page-header">
          <span className="badge badge--role badge--role-sac-exec">
            Read only
          </span>
        </div>
      ) : null}

      {isSacExec && !canMutateReviews ? (
        <div className="alert alert--warning" role="status">
          <strong>Read-only access</strong>
          <p>
            As a SAC Executive you can view queues and re-application details,
            but you cannot approve, reject, or change request state. Mutation
            actions are limited to SAC administrators — except the School Day
            override, which SAC Executives may also change.
          </p>
        </div>
      ) : null}

      <nav className="subtabs" aria-label="Exec Dashboard sections">
        {primaryTabs.map((tab) => {
          const active = isPathActive(pathname, tab.matchPrefix);
          return (
            <NavLink
              key={tab.id}
              to={tab.to}
              className={active ? "subtab subtab--active" : "subtab"}
            >
              {tab.label}
            </NavLink>
          );
        })}
      </nav>

      <Outlet />
    </div>
  );
}
