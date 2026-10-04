import { Link } from "react-router-dom";
import { isSignInRequiredMessage } from "../../utils/errors";

export function ErrorMessage({ title = "Error", children }) {
  if (!children) return null;

  if (isSignInRequiredMessage(children)) {
    return (
      <div className="alert alert--info" role="status">
        <strong>Sign in to see</strong>
        <div>
          <Link className="text-link" to="/login">
            Sign in
          </Link>{" "}
          to view this.
        </div>
      </div>
    );
  }

  return (
    <div className="alert alert--error" role="alert">
      <strong>{title}</strong>
      <div>{children}</div>
    </div>
  );
}
