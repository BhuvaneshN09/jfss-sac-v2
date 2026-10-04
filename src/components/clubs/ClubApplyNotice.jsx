import { ClubLiaisonContacts } from "./ClubLiaisonContacts";
import { CLUB_APPLICATION_DEADLINE_TEXT } from "../../config/clubApplications";

/**
 * Shared disclaimer + deadline + account + club liaisons for club applications.
 */
export function ClubApplyNotice({ accountEmail }) {
  return (
    <section className="panel club-apply-notice">
      <p className="club-apply-notice__disclaimer">
        Please note that submitting a proposal does not guarantee approval. All
        applications will be reviewed based on feasibility, student interest,
        and their impact on the school community.
      </p>
      <p
        className="alert alert--warning club-apply-notice__deadline"
        role="status"
      >
        All proposals must be submitted by {CLUB_APPLICATION_DEADLINE_TEXT}.
        Late submissions will not be considered.
      </p>
      {accountEmail ? (
        <p className="muted club-apply-notice__account">
          Submitting as <strong>{accountEmail}</strong>. Your account email is
          recorded automatically.
        </p>
      ) : null}
      <ClubLiaisonContacts embedded />
    </section>
  );
}
