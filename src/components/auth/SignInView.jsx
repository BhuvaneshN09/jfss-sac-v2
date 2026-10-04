import { useState } from "react";
import { GoogleLogin } from "@react-oauth/google";
import { useAuth } from "../../context/AuthContext";
import { ErrorMessage } from "../ui/ErrorMessage";
import { Spinner } from "../ui/Spinner";
import {
  peekAuthReturnTo,
  rememberAuthReturnTo,
} from "../../utils/authRedirect";
import { getErrorMessage } from "../../utils/errors";
import { ALLOWED_EMAIL_DOMAIN } from "../../utils/domain";

const GOOGLE_CLIENT_ID = import.meta.env.VITE_GOOGLE_CLIENT_ID;

function rememberReturnPath(returnTo) {
  if (returnTo) {
    rememberAuthReturnTo(returnTo);
  } else if (!peekAuthReturnTo()) {
    rememberAuthReturnTo(
      `${window.location.pathname}${window.location.search}${window.location.hash}`,
    );
  }
}

/**
 * Fraser Pay–style sign-in card: logo, Welcome, Google CTA, help footer.
 * Uses a Google ID token (GIS) rather than a Supabase OAuth redirect.
 */
export function SignInView({ returnTo, className = "" }) {
  const { accessDenied, authError, signInWithGoogle } = useAuth();
  const [signingIn, setSigningIn] = useState(false);
  const [localError, setLocalError] = useState("");
  const googleConfigured = Boolean(GOOGLE_CLIENT_ID);

  async function handleGoogleCredential(response) {
    const credential = response?.credential;
    if (!credential) {
      setLocalError("Google sign-in did not return an ID token.");
      setSigningIn(false);
      return;
    }

    setSigningIn(true);
    setLocalError("");
    rememberReturnPath(returnTo);

    try {
      await signInWithGoogle(credential);
    } catch (error) {
      setLocalError(getErrorMessage(error, "Google sign-in failed."));
      setSigningIn(false);
    }
  }

  function handleGoogleError() {
    setSigningIn(false);
    setLocalError("Google sign-in was cancelled or failed. Please try again.");
  }

  const configError = googleConfigured
    ? ""
    : "This app uses Supabase Auth with Google Identity Services, not Firebase. Add your Google Cloud Web client ID as VITE_GOOGLE_CLIENT_ID in .env.local and reload.";

  return (
    <div className={`sign-in-view${className ? ` ${className}` : ""}`}>
      <div className="sign-in-view__logo-frame">
        <img
          src="/images/SAC-LOGO.png"
          alt="John Fraser SAC"
          className="sign-in-view__logo"
          width={120}
          height={120}
        />
      </div>

      <div className="sign-in-view__card">
        <h1 className="sign-in-view__title">Welcome</h1>
        <p className="sign-in-view__subtitle">
          Sign in with your @{ALLOWED_EMAIL_DOMAIN} Google account to access
          your SAC portal account.
        </p>

        {(accessDenied || authError || localError || configError) && (
          <ErrorMessage title="Unable to sign in">
            {localError || authError || configError}
          </ErrorMessage>
        )}

        {signingIn ? (
          <button
            type="button"
            className="sign-in-view__google"
            disabled
          >
            <Spinner size="sm" label="Signing in" />
            Signing in…
          </button>
        ) : googleConfigured ? (
          <div className="sign-in-view__google-gis">
            <GoogleLogin
              onSuccess={handleGoogleCredential}
              onError={handleGoogleError}
              click_listener={() => rememberReturnPath(returnTo)}
              useOneTap={false}
              auto_select={false}
              ux_mode="popup"
              hosted_domain={ALLOWED_EMAIL_DOMAIN}
              text="signin_with"
              theme="outline"
              size="large"
              shape="rectangular"
              logo_alignment="left"
            />
          </div>
        ) : (
          <button type="button" className="sign-in-view__google" disabled>
            Sign in With Google
          </button>
        )}

        <div className="sign-in-view__footer">
          <span className="sign-in-view__info-icon" aria-hidden="true">
            i
          </span>
          <p className="sign-in-view__help">
            Contact SAC if you need help signing in.
          </p>
        </div>
      </div>
    </div>
  );
}
