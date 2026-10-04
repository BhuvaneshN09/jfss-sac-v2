import { Link } from "react-router-dom";
import { StatusBadge } from "../ui/StatusBadge";

export function ExecReviewQueueCard({ to, title, submitter, status }) {
  return (
    <Link to={to} className="exec-queue-card">
      <div className="exec-queue-card__main">
        <h3 className="exec-queue-card__title">{title}</h3>
        <p className="exec-queue-card__submitter">{submitter}</p>
      </div>
      {status ? <StatusBadge status={status} /> : null}
    </Link>
  );
}
