import { Link } from "react-router-dom";
import { formatDate } from "../../utils/format";
import { StatusBadge } from "../ui/StatusBadge";

export function RequestCard({
  request,
  showRequester = false,
  actions = null,
  createdClubSlug = null,
  createdClubMissing = false,
}) {
  const showCreatedClub =
    request.status === "APPROVED" &&
    Boolean(request.created_club_id) &&
    Boolean(createdClubSlug);
  const showClubIdFallback =
    request.status === "APPROVED" &&
    Boolean(request.created_club_id) &&
    !createdClubSlug &&
    !createdClubMissing;
  const showRemovedClub =
    request.status === "APPROVED" &&
    !createdClubSlug &&
    (!request.created_club_id || createdClubMissing);

  return (
    <article className="request-card">
      <div className="request-card__header">
        <div>
          <div className="request-card__labels">
            <span className="submission-type request-card__type">
              New club application
            </span>
            <StatusBadge status={request.status} prefix="Status: " />
          </div>
          <h2>{request.proposed_name}</h2>
        </div>
        <time
          className="request-card__date"
          dateTime={request.submitted_at || request.created_at || undefined}
        >
          Submitted {formatDate(request.submitted_at || request.created_at)}
        </time>
      </div>

      {request.short_description ? (
        <p>{request.short_description}</p>
      ) : null}

      <dl className="meta-list">
        <div>
          <dt>Updated</dt>
          <dd>{formatDate(request.updated_at)}</dd>
        </div>
        {showRequester ? (
          <div>
            <dt>Requested by</dt>
            <dd>
              <code>{request.requested_by}</code>
            </dd>
          </div>
        ) : null}
      </dl>

      {request.review_notes ? (
        <div className="request-card__notes">
          <strong>Review notes</strong>
          <p>{request.review_notes}</p>
        </div>
      ) : null}

      {showCreatedClub ? (
        <p>
          <Link className="text-link" to={`/clubs/${createdClubSlug}`}>
            View created club
          </Link>
        </p>
      ) : null}

      {showClubIdFallback ? (
        <p className="muted">
          Approved club ID: <code>{request.created_club_id}</code>
        </p>
      ) : null}

      {showRemovedClub ? (
        <p className="muted" role="status">
          The previously created club has been removed.
        </p>
      ) : null}

      {actions ? <div className="request-card__actions">{actions}</div> : null}
    </article>
  );
}
