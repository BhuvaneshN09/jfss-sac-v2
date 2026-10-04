import { Outlet, useLocation } from "react-router-dom";
import { ClubsSubnav } from "../clubs/ClubsSubnav";

function shouldShowClubsSubnav(pathname) {
  if (pathname === "/clubs" || pathname === "/clubs/") return true;
  if (pathname.startsWith("/clubs/my-clubs")) return true;
  if (pathname.startsWith("/clubs/apply")) return true;
  if (pathname.startsWith("/clubs/reapply")) return true;
  if (pathname.startsWith("/clubs/register")) return true;
  return false;
}

/**
 * Shared Clubs section shell — hub subnav mounts once and persists
 * across Explore / My Clubs / Create / Re-register so underline transitions run.
 * Section banner is rendered by AppShell.
 */
export function ClubsLayout() {
  const { pathname } = useLocation();
  const showSubnav = shouldShowClubsSubnav(pathname);

  return (
    <div className="page clubs-page">
      {showSubnav ? <ClubsSubnav /> : null}
      <div className="clubs-page__content">
        <Outlet />
      </div>
    </div>
  );
}
