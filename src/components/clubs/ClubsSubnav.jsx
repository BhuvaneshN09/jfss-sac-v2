import { NavLink } from "react-router-dom";

const TABS = [
  { to: "/clubs", label: "Explore", end: true },
  { to: "/clubs/my-clubs", label: "My Clubs", end: true },
  { to: "/clubs/apply", label: "Create a New Club", end: true },
  { to: "/clubs/reapply", label: "Re-register a club", end: true },
];

export function ClubsSubnav() {
  return (
    <nav className="subtabs" aria-label="Clubs sections">
      {TABS.map((tab) => (
        <NavLink
          key={tab.to}
          to={tab.to}
          end={tab.end}
          className={({ isActive }) =>
            isActive ? "subtab subtab--active" : "subtab"
          }
        >
          {tab.label}
        </NavLink>
      ))}
    </nav>
  );
}
