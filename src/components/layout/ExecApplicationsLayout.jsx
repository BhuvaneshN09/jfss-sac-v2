import { NavLink, Navigate, Outlet, useLocation } from "react-router-dom";
import { useAuth } from "../../context/AuthContext";

export function ExecApplicationsLayout() {
  const { isSacAdmin, isSacExec, isFacultyAdvisor } = useAuth();
  const { pathname } = useLocation();
  const canViewApps = isSacAdmin || isSacExec || isFacultyAdvisor;
  const canViewReapps = isSacAdmin || isSacExec;

  if (!canViewApps) {
    return <Navigate to="/exec-dashboard/requests/announcements" replace />;
  }

  const subtabs = [
    { to: "/exec-dashboard/applications/new", label: "New Club Applications" },
    ...(canViewReapps
      ? [
          {
            to: "/exec-dashboard/applications/reapplications",
            label: "Reapplications",
          },
        ]
      : []),
  ];

  return (
    <div className="exec-section">
      <nav className="subtabs subtabs--nested" aria-label="Applications">
        {subtabs.map((tab) => (
          <NavLink
            key={tab.to}
            to={tab.to}
            className={() =>
              pathname === tab.to || pathname.startsWith(`${tab.to}/`)
                ? "subtab subtab--active"
                : "subtab"
            }
          >
            {tab.label}
          </NavLink>
        ))}
      </nav>
      <Outlet />
    </div>
  );
}
