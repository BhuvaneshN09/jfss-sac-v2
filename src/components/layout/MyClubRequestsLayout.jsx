import { NavLink, Outlet } from "react-router-dom";

export function MyClubRequestsLayout() {
  return (
    <div className="stack">
      <nav className="subtabs" aria-label="Club request types">
        <NavLink
          to="applications"
          end
          className={({ isActive }) =>
            isActive ? "subtab subtab--active" : "subtab"
          }
        >
          New Club
        </NavLink>
        <NavLink
          to="reapplications"
          end
          className={({ isActive }) =>
            isActive ? "subtab subtab--active" : "subtab"
          }
        >
          Re-register a Club
        </NavLink>
      </nav>
      <Outlet />
    </div>
  );
}
