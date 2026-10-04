import { NavLink, Navigate, Outlet } from "react-router-dom";
import { useAuth } from "../../context/AuthContext";

export function ExecArchivedLayout() {
  const { isSacAdmin, isSacExec } = useAuth();
  const canView = isSacAdmin || isSacExec;

  if (!canView) {
    return <Navigate to="/exec-dashboard/requests/announcements" replace />;
  }

  const subtabs = [
    { to: "/exec-dashboard/archived/clubs", label: "Archived Clubs" },
    {
      to: "/exec-dashboard/archived/announcements",
      label: "Archived Announcements",
    },
  ];

  return (
    <div className="exec-section">
      <nav className="subtabs subtabs--nested" aria-label="Archived">
        {subtabs.map((tab) => (
          <NavLink
            key={tab.to}
            to={tab.to}
            end
            className={({ isActive }) =>
              isActive ? "subtab subtab--active" : "subtab"
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
