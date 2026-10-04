import { NavLink, Navigate, Outlet, useLocation } from "react-router-dom";
import { useAuth } from "../../context/AuthContext";

export function ExecRequestsLayout() {
  const { isSacAdmin, isSacExec, isFacultyAdvisor } = useAuth();
  const { pathname } = useLocation();
  const canView = isSacAdmin || isSacExec || isFacultyAdvisor;

  if (!canView) {
    return <Navigate to="/" replace />;
  }

  const subtabs = [
    ...(isSacAdmin
      ? [
          {
            to: "/exec-dashboard/requests/funding",
            label: "Club Funding",
          },
        ]
      : []),
    {
      to: "/exec-dashboard/requests/events",
      label: "Events",
    },
    {
      to: "/exec-dashboard/requests/promo-lunch",
      label: "Promo Lunch",
    },
    {
      to: "/exec-dashboard/requests/announcements",
      label: "Announcements",
    },
    ...(isSacAdmin || isSacExec
      ? [
          {
            to: "/exec-dashboard/requests/supervisor",
            label: "Supervisor",
          },
        ]
      : []),
  ];

  return (
    <div className="exec-section">
      <nav className="subtabs subtabs--nested" aria-label="Review types">
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
