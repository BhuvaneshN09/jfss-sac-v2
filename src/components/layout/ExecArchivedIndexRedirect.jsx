import { Navigate } from "react-router-dom";

export function ExecArchivedIndexRedirect() {
  return <Navigate to="/exec-dashboard/archived/clubs" replace />;
}
