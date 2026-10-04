import { Spinner } from "./Spinner";

export function LoadingScreen({ message = "Loading…" }) {
  return (
    <div className="loading-screen" role="status" aria-live="polite">
      <Spinner size="lg" label={message} />
      <p>{message}</p>
    </div>
  );
}
