import { useEffect } from "react";
import { Navigate, useLocation } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { LoadingScreen } from "../components/ui/LoadingScreen";
import { SignInView } from "../components/auth/SignInView";
import {
  normalizeAuthReturnPath,
  rememberAuthReturnTo,
} from "../utils/authRedirect";

/**
 * Dedicated sign-in page (not a modal). After Google ID-token sign-in,
 * AuthRedirectProvider sends the user back to the remembered return path.
 */
export function LoginPage() {
  const { isAuthenticated, isLoading } = useAuth();
  const location = useLocation();

  const from = location.state?.from;
  const returnTo =
    normalizeAuthReturnPath(
      from ? `${from.pathname || "/"}${from.search || ""}${from.hash || ""}` : "/",
    ) || "/";

  useEffect(() => {
    if (from) {
      rememberAuthReturnTo(returnTo);
    }
  }, [from, returnTo]);

  if (isLoading) {
    return <LoadingScreen message="Checking authentication…" />;
  }

  if (isAuthenticated) {
    return <Navigate to={returnTo === "/login" ? "/" : returnTo} replace />;
  }

  return (
    <div className="login-page">
      <SignInView returnTo={from ? returnTo : undefined} />
    </div>
  );
}
