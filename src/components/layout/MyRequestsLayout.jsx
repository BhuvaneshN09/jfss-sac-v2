import { useEffect, useMemo, useState } from "react";
import { NavLink, Outlet } from "react-router-dom";
import { useAuth } from "../../context/AuthContext";
import { ErrorMessage } from "../ui/ErrorMessage";
import { LoadingScreen } from "../ui/LoadingScreen";
import { getMyClubMemberships } from "../../services/memberships";
import { buildMyRequestTabs } from "../../utils/myRequestTabs";
import { getErrorMessage } from "../../utils/errors";

/**
 * My Requests shell — role-gated subtabs for every request kind the user can send.
 */
export function MyRequestsLayout() {
  const { user, canCreateAnnouncements } = useAuth();
  const [memberships, setMemberships] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    let active = true;

    async function load() {
      setLoading(true);
      setError("");
      try {
        const rows = await getMyClubMemberships(user.id);
        if (!active) return;
        setMemberships(rows);
      } catch (loadError) {
        if (!active) return;
        setError(
          getErrorMessage(loadError, "Could not load your club roles."),
        );
        setMemberships([]);
      } finally {
        if (active) setLoading(false);
      }
    }

    load();
    return () => {
      active = false;
    };
  }, [user.id]);

  const tabs = useMemo(
    () =>
      buildMyRequestTabs({
        canCreateAnnouncements,
        memberships,
      }),
    [canCreateAnnouncements, memberships],
  );

  if (loading) {
    return <LoadingScreen message="Loading your requests…" />;
  }

  return (
    <div className="page">
      {error ? <ErrorMessage>{error}</ErrorMessage> : null}

      <nav className="subtabs" aria-label="My request types">
        {tabs.map((tab) => (
          <NavLink
            key={tab.id}
            to={tab.to}
            end={tab.id !== "clubRequests"}
            className={({ isActive }) =>
              isActive ? "subtab subtab--active" : "subtab"
            }
          >
            {tab.label}
          </NavLink>
        ))}
      </nav>

      <Outlet context={{ memberships, tabs }} />
    </div>
  );
}
