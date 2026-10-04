import { useNavigate } from "react-router-dom";
import { rememberAuthReturnTo } from "../../utils/authRedirect";

/**
 * Locked section gate for signed-out users.
 * Blurs this content area, blocks interaction (except Sign in), and still
 * allows page scroll when the pointer is over the gate.
 */
export function AuthGate({
  returnTo,
  title = "Sign in to see this section",
  description = "Continue with Google to access this area of the portal.",
}) {
  const navigate = useNavigate();

  function goToLogin() {
    if (returnTo) {
      rememberAuthReturnTo(returnTo);
    }
    navigate("/login");
  }

  return (
    <div className="auth-gate" role="region" aria-label="Sign in required">
      <div className="auth-gate__blur" aria-hidden="true" inert>
        <div className="auth-gate__ghost">
          <div className="auth-gate__ghost-line auth-gate__ghost-line--wide" />
          <div className="auth-gate__ghost-line" />
          <div className="auth-gate__ghost-grid">
            <div className="auth-gate__ghost-card" />
            <div className="auth-gate__ghost-card" />
            <div className="auth-gate__ghost-card" />
          </div>
          <div className="auth-gate__ghost-block" />
          <div className="auth-gate__ghost-line auth-gate__ghost-line--mid" />
          <div className="auth-gate__ghost-block auth-gate__ghost-block--tall" />
        </div>
      </div>

      <div className="auth-gate__scrim" aria-hidden="true" />

      <div className="auth-gate__prompt">
        <div className="auth-gate__card">
          <h1 className="auth-gate__title">{title}</h1>
          <p className="auth-gate__description">{description}</p>
          <button
            type="button"
            className="button button--primary"
            onClick={goToLogin}
          >
            Sign in
          </button>
        </div>
      </div>
    </div>
  );
}
