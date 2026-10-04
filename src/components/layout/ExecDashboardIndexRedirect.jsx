import { Navigate } from "react-router-dom";
import { useAuth } from "../../context/AuthContext";

export function ExecDashboardIndexRedirect() {
  const { isSacAdmin, isSacExec, isFacultyAdvisor } = useAuth();
  if (isSacAdmin || isSacExec) {
    return <Navigate to="/exec-dashboard/applications/new" replace />;
  }
  if (isFacultyAdvisor) {
    return <Navigate to="/exec-dashboard/requests/announcements" replace />;
  }
  return <Navigate to="/" replace />;
}
