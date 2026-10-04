import { EmptyState } from "../ui/EmptyState";
import { ClubMemberRow } from "./ClubMemberRow";
import { ClubRoleBadge } from "./ClubRoleBadge";
import { Spinner } from "../ui/Spinner";
import { getClubRoleLabel, isClubOwner } from "../../utils/clubPermissions";
import { formatDate } from "../../utils/format";

function PersonTable({
  memberships,
  currentUserId,
  currentUserRole,
  isSacAdmin,
  onChangeRole,
  onRemove,
  emptyTitle,
  emptyBody,
  showEmails = true,
}) {
  if (!memberships?.length) {
    return <EmptyState title={emptyTitle}>{emptyBody}</EmptyState>;
  }

  return (
    <div className="table-wrap">
      <table className="data-table">
        <thead>
          <tr>
            <th scope="col">Person</th>
            <th scope="col">Role</th>
            <th scope="col">Status</th>
            <th scope="col">Joined</th>
            <th scope="col">Added by</th>
            <th scope="col">Actions</th>
          </tr>
        </thead>
        <tbody>
          {memberships.map((membership) => (
            <ClubMemberRow
              key={`${membership.club_id}-${membership.user_id}`}
              membership={
                showEmails
                  ? membership
                  : {
                      ...membership,
                      profile: membership.profile
                        ? {
                            ...membership.profile,
                            email: null,
                          }
                        : null,
                    }
              }
              currentUserId={currentUserId}
              currentUserRole={currentUserRole}
              isSacAdmin={isSacAdmin}
              onChangeRole={onChangeRole}
              onRemove={onRemove}
            />
          ))}
        </tbody>
      </table>
    </div>
  );
}

function PendingInvitationsPanel({
  invitations,
  canCancel,
  cancellingId,
  onCancel,
}) {
  return (
    <section className="panel">
      <h2>Pending invitations</h2>
      <p className="muted">
        These people have been invited but have not accepted yet. They are not
        club members until they accept.
      </p>

      {!invitations?.length ? (
        <EmptyState title="No pending invitations">
          Sent invitations appear here until they are accepted, rejected, or
          cancelled.
        </EmptyState>
      ) : (
        <div className="table-wrap">
          <table className="data-table">
            <thead>
              <tr>
                <th scope="col">Invitee</th>
                <th scope="col">Offered position</th>
                <th scope="col">Sent</th>
                <th scope="col">Actions</th>
              </tr>
            </thead>
            <tbody>
              {invitations.map((invitation) => {
                const label =
                  invitation.invitee?.full_name ||
                  invitation.invitee_email ||
                  invitation.invitee_user_id;
                return (
                  <tr key={invitation.id}>
                    <td>
                      <strong>{label}</strong>
                      {invitation.invitee_email ? (
                        <div className="muted">{invitation.invitee_email}</div>
                      ) : null}
                    </td>
                    <td>
                      <ClubRoleBadge role={invitation.offered_role} />
                    </td>
                    <td>{formatDate(invitation.created_at)}</td>
                    <td>
                      {canCancel ? (
                        <button
                          type="button"
                          className="button button--secondary"
                          disabled={cancellingId === invitation.id}
                          onClick={() => onCancel?.(invitation)}
                        >
                          {cancellingId === invitation.id ? (
                            <Spinner size="sm" label="Cancelling" />
                          ) : null}
                          Cancel
                        </button>
                      ) : (
                        <span className="muted">Pending</span>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
}

export function ClubPeoplePanel({
  memberships,
  invitations = [],
  currentUserId,
  currentUserRole,
  isSacAdmin = false,
  addForm = null,
  profilesWarning = null,
  cancellingInvitationId = null,
  onCancelInvitation,
  onChangeRole,
  onRemove,
}) {
  const canViewPrivatePeople = isSacAdmin || isClubOwner(currentUserRole);
  const canCancelInvites = isSacAdmin || isClubOwner(currentUserRole);

  const owners = memberships.filter((row) => row.role === "OWNER");
  const executives = memberships.filter((row) => row.role === "EXEC");
  const members = memberships.filter((row) => row.role === "MEMBER");

  return (
    <div
      id="manage-panel-people"
      role="tabpanel"
      aria-labelledby="manage-tab-people"
      className="stack"
    >
      {profilesWarning ? (
        <div className="alert alert--warning" role="status">
          <p>{profilesWarning}</p>
        </div>
      ) : null}

      {addForm}

      {canCancelInvites ? (
        <PendingInvitationsPanel
          invitations={invitations}
          canCancel={canCancelInvites}
          cancellingId={cancellingInvitationId}
          onCancel={onCancelInvitation}
        />
      ) : null}

      <section className="panel">
        <h2>Owners</h2>
        <p className="muted">
          {owners.length} of 3 active owners. Pending owner invitations also
          reserve a slot.
        </p>
        <PersonTable
          memberships={owners}
          currentUserId={currentUserId}
          currentUserRole={currentUserRole}
          isSacAdmin={isSacAdmin}
          onChangeRole={onChangeRole}
          onRemove={onRemove}
          emptyTitle="No owners"
          emptyBody="This club has no active owners."
          showEmails
        />
      </section>

      {canViewPrivatePeople ? (
        <>
          <section className="panel">
            <h2>Executives</h2>
            <PersonTable
              memberships={executives}
              currentUserId={currentUserId}
              currentUserRole={currentUserRole}
              isSacAdmin={isSacAdmin}
              onChangeRole={onChangeRole}
              onRemove={onRemove}
              emptyTitle="No executives"
              emptyBody="No executives have been added yet."
              showEmails
            />
          </section>

          <section className="panel">
            <h2>Members</h2>
            <PersonTable
              memberships={members}
              currentUserId={currentUserId}
              currentUserRole={currentUserRole}
              isSacAdmin={isSacAdmin}
              onChangeRole={onChangeRole}
              onRemove={onRemove}
              emptyTitle="No members"
              emptyBody="No members have been added yet."
              showEmails
            />
          </section>
        </>
      ) : (
        <section className="panel">
          <h2>Members</h2>
          <p className="muted">
            Executive and member contact details are visible only to{" "}
            {getClubRoleLabel("OWNER")}s. You can still manage members you
            already oversee.
          </p>
          <PersonTable
            memberships={members}
            currentUserId={currentUserId}
            currentUserRole={currentUserRole}
            isSacAdmin={isSacAdmin}
            onChangeRole={onChangeRole}
            onRemove={onRemove}
            emptyTitle="No members"
            emptyBody="No members have been added yet."
            showEmails={false}
          />
        </section>
      )}
    </div>
  );
}
