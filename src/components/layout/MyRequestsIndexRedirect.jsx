import { Navigate, useOutletContext } from "react-router-dom";

export function MyRequestsIndexRedirect() {
  const { tabs } = useOutletContext() || {};
  const first = tabs?.[0]?.to || "/my-requests/applications";
  return <Navigate to={first} replace />;
}
