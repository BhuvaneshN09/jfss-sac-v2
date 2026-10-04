import { Navigate } from "react-router-dom";
import { useAuth } from "../../context/AuthContext";

export function ExecRequestsIndexRedirect() {
  const { isSacAdmin } = useAuth();
  if (isSacAdmin) {
    return <Navigate to="/exec-dashboard/requests/funding" replace />;
  }
  return <Navigate to="/exec-dashboard/requests/announcements" replace />;
}
