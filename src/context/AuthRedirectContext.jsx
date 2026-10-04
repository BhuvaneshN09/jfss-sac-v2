import { useEffect, useRef } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import { useAuth } from "./AuthContext";
import { consumeAuthReturnTo } from "../utils/authRedirect";

/**
 * After sign-in completes, send the user back to the path they were
 * trying to open (if one was remembered).
 */
export function AuthRedirectProvider({ children }) {
  const { isAuthenticated, isLoading } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const handledAuthRef = useRef(false);

  useEffect(() => {
    if (!isAuthenticated) {
      handledAuthRef.current = false;
      return;
    }
    if (isLoading || handledAuthRef.current) return;

    handledAuthRef.current = true;

    const returnTo = consumeAuthReturnTo(null);
    if (!returnTo) return;

    const current = `${location.pathname}${location.search}${location.hash}`;
    if (returnTo !== current) {
      navigate(returnTo, { replace: true });
    }
  }, [
    isAuthenticated,
    isLoading,
    location.hash,
    location.pathname,
    location.search,
    navigate,
  ]);

  return children;
}
