import { Navigate } from "react-router-dom";

export function ExecApplicationsIndexRedirect({
  basePath = "/exec-dashboard/applications",
}) {
  return <Navigate to={`${basePath}/new`} replace />;
}
