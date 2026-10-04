import { useLocation } from "react-router-dom";
import { useAuth } from "../../context/AuthContext";
import { LoadingScreen } from "../ui/LoadingScreen";
import { AuthGate } from "./AuthGate";

export function ProtectedRoute({ children }) {
  const { isAuthenticated, isLoading, accessDenied } = useAuth();
  const location = useLocation();
  const returnTo = `${location.pathname}${location.search}${location.hash}`;

  if (isLoading) {
    return <LoadingScreen message="Checking authentication…" />;
  }

  if (accessDenied || !isAuthenticated) {
    return <AuthGate returnTo={returnTo} />;
  }

  return children;
}
