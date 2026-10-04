import { useLocation } from "react-router-dom";
import { useAuth } from "../../context/AuthContext";
import { LoadingScreen } from "../ui/LoadingScreen";
import { ErrorMessage } from "../ui/ErrorMessage";
import { AuthGate } from "./AuthGate";

/**
 * Requires authentication and at least one of the allowed system-role codes.
 */
export function RoleRoute({ allowedRoles = [], children }) {
  const { isAuthenticated, isLoading, systemRoles } = useAuth();
  const location = useLocation();
  const returnTo = `${location.pathname}${location.search}${location.hash}`;

  if (isLoading) {
    return <LoadingScreen message="Checking access…" />;
  }

  if (!isAuthenticated) {
    return <AuthGate returnTo={returnTo} />;
  }

  const roleCodes = (systemRoles || []).map((role) => role.code);
  const allowed = allowedRoles.some((code) => roleCodes.includes(code));

  if (!allowed) {
    return (
      <div className="page">
        <ErrorMessage title="Access denied">
          You do not have permission to view this page.
        </ErrorMessage>
      </div>
    );
  }

  return children;
}
