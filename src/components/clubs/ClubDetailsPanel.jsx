import { useEffect, useState } from "react";
import { TextArea } from "../ui/TextArea";
import { TextInput } from "../ui/TextInput";
import { ErrorMessage } from "../ui/ErrorMessage";
import { Spinner } from "../ui/Spinner";
import { ClubLogoUpload } from "./ClubLogoUpload";
import { ClubSupervisorSubmitForm } from "./ClubSupervisorSubmitForm";
import { StatusBadge } from "../ui/StatusBadge";
import { useAuth } from "../../context/AuthContext";
import { MEETING_DAYS } from "../../config/clubApplications";
import { updateOwnedClubProfile } from "../../services/clubs";
import {
  deleteClubLogo,
  removeOldClubProfileLogos,
  uploadClubLogo,
} from "../../services/clubLogos";
import {
  getActiveClubAdvisors,
  getClubSupervisorRequests,
} from "../../services/clubSupervisors";
import { isClubOwner } from "../../utils/clubPermissions";
import { getErrorMessage } from "../../utils/errors";
import {
  validateOptionalHttpsUrl,
  validateOwnerNames,
} from "../../utils/validation";

function ClubDetailsForm({ club, canEdit, onClubUpdated }) {
  const { user } = useAuth();
  const [name, setName] = useState(club?.name || "");
  const [description, setDescription] = useState(club?.description || "");
  const [ownerNames, setOwnerNames] = useState(club?.owner_names || "");
  const [publicEmail, setPublicEmail] = useState(club?.contact_email || "");
  const [instagramHandle, setInstagramHandle] = useState(
    club?.instagram_handle || "",
  );
  const [memberApplicationUrl, setMemberApplicationUrl] = useState(
    club?.member_application_url || "",
  );
  const [execApplicationUrl, setExecApplicationUrl] = useState(
    club?.exec_application_url || "",
  );
  const [meetingDays, setMeetingDays] = useState(club?.meeting_days || []);
  const [meetingTimeDetails, setMeetingTimeDetails] = useState(
    club?.meeting_time_details || "",
  );
  const [meetingLocation, setMeetingLocation] = useState(
    club?.meeting_location || "",
  );
  const [logoFile, setLogoFile] = useState(null);
  const [fieldErrors, setFieldErrors] = useState({});
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  function validate() {
    const errors = {};
    if (name.trim().length < 2) {
      errors.name = "Enter your club name.";
    }
    if (description.trim().length < 10) {
      errors.description =
        "Provide a detailed club description (at least 10 characters).";
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(publicEmail.trim())) {
      errors.publicEmail = "Enter a valid public club email.";
    }
    if (!instagramHandle.trim()) {
      errors.instagramHandle = "Enter the club Instagram handle.";
    }
    const memberUrlError = validateOptionalHttpsUrl(memberApplicationUrl, {
      previous: club?.member_application_url,
      label: "member application link",
    });
    if (memberUrlError) errors.memberApplicationUrl = memberUrlError;
    const execUrlError = validateOptionalHttpsUrl(execApplicationUrl, {
      previous: club?.exec_application_url,
      label: "executive application link",
    });
    if (execUrlError) errors.execApplicationUrl = execUrlError;
    const ownerNamesError = validateOwnerNames(ownerNames, { required: false });
    if (ownerNamesError) {
      errors.ownerNames = ownerNamesError;
    }
    return errors;
  }

  async function handleSave(event) {
    event.preventDefault();
    if (busy || !canEdit) return;

    setError("");

    const errors = validate();
    setFieldErrors(errors);
    if (Object.keys(errors).length > 0) {
      setError("Please fix the highlighted fields before saving.");
      return;
    }

    setBusy(true);
    let uploadedLogoPath = null;

    try {
      // Save text fields first so photo-upload issues don't block edits.
      let updated = await updateOwnedClubProfile(club.id, {
        name,
        description,
        contactEmail: publicEmail,
        instagramHandle: instagramHandle.replace(/^@+/, ""),
        memberApplicationUrl,
        execApplicationUrl,
        meetingDays,
        meetingTimeDetails,
        meetingLocation,
        ownerNames,
      });

      if (logoFile) {
        if (!user?.id) {
          throw new Error("Sign in again to upload a club photo.");
        }
        const logoUrl = await uploadClubLogo({
          userId: user.id,
          clubId: club.id,
          file: logoFile,
        });
        uploadedLogoPath = logoUrl;
        updated = await updateOwnedClubProfile(club.id, {
          name,
          description,
          contactEmail: publicEmail,
          instagramHandle: instagramHandle.replace(/^@+/, ""),
          memberApplicationUrl,
          execApplicationUrl,
          meetingDays,
          meetingTimeDetails,
          meetingLocation,
          ownerNames,
          logoUrl,
        });
        await removeOldClubProfileLogos({
          userId: user.id,
          clubId: club.id,
          keepPath: logoUrl,
        });
        setLogoFile(null);
      }

      setFieldErrors({});
      onClubUpdated?.(updated);
    } catch (saveError) {
      await deleteClubLogo(uploadedLogoPath);
      setError(getErrorMessage(saveError, "Could not save club details."));
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="panel">
      <h2>Club details</h2>
      <p className="muted">
        These details appear on the public club page. The club URL slug stays{" "}
        <code>{club.slug}</code> when you rename the club.
      </p>

      {error ? <ErrorMessage>{error}</ErrorMessage> : null}

      <form className="stack" onSubmit={handleSave} noValidate>
        <TextInput
          id="club-name"
          label="Club name"
          value={name}
          onChange={(event) => setName(event.target.value)}
          error={fieldErrors.name}
          required
          disabled={!canEdit || busy}
        />
        <TextArea
          id="club-description"
          label="Description"
          value={description}
          onChange={(event) => setDescription(event.target.value)}
          error={fieldErrors.description}
          rows={6}
          required
          disabled={!canEdit || busy}
          hint="Pitch your club and how it benefits students at JFSS."
        />
        <TextArea
          id="club-owner-names"
          label="Names of all club owners"
          value={ownerNames}
          onChange={(event) => setOwnerNames(event.target.value)}
          error={fieldErrors.ownerNames}
          rows={3}
          disabled={!canEdit || busy}
          hint="List the full name of every owner. A club may have at most three owners."
        />
        <TextInput
          id="club-public-email"
          type="email"
          label="Public club email"
          value={publicEmail}
          onChange={(event) => setPublicEmail(event.target.value)}
          error={fieldErrors.publicEmail}
          required
          disabled={!canEdit || busy}
        />
        <TextInput
          id="club-instagram"
          label="Instagram handle"
          value={instagramHandle}
          onChange={(event) => setInstagramHandle(event.target.value)}
          error={fieldErrors.instagramHandle}
          required
          disabled={!canEdit || busy}
        />
        <TextInput
          id="club-member-application"
          type="url"
          label="Link to member application"
          value={memberApplicationUrl}
          onChange={(event) => setMemberApplicationUrl(event.target.value)}
          error={fieldErrors.memberApplicationUrl}
          disabled={!canEdit || busy}
          hint="Optional"
        />
        <TextInput
          id="club-exec-application"
          type="url"
          label="Link to executive application"
          value={execApplicationUrl}
          onChange={(event) => setExecApplicationUrl(event.target.value)}
          error={fieldErrors.execApplicationUrl}
          disabled={!canEdit || busy}
          hint="Optional"
        />

        <fieldset className="form-field meeting-day-picker">
          <legend>
            Meeting days <span className="muted">(optional)</span>
          </legend>
          <div className="meeting-day-picker__row" role="group">
            {MEETING_DAYS.map((day) => {
              const selected = meetingDays.includes(day);
              return (
                <button
                  key={day}
                  type="button"
                  className={
                    selected
                      ? "meeting-day-picker__day meeting-day-picker__day--selected"
                      : "meeting-day-picker__day"
                  }
                  aria-pressed={selected}
                  disabled={!canEdit || busy}
                  onClick={() =>
                    setMeetingDays((current) =>
                      selected
                        ? current.filter((item) => item !== day)
                        : [...current, day],
                    )
                  }
                >
                  {day.slice(0, 3)}
                </button>
              );
            })}
          </div>
        </fieldset>

        <TextInput
          id="club-meeting-time"
          label="Meeting time / details"
          placeholder="e.g. lunch, before school, after school"
          value={meetingTimeDetails}
          onChange={(event) => setMeetingTimeDetails(event.target.value)}
          disabled={!canEdit || busy}
          hint="Optional"
        />

        <TextInput
          id="club-meeting-location"
          label="Meeting location"
          value={meetingLocation}
          onChange={(event) => setMeetingLocation(event.target.value)}
          disabled={!canEdit || busy}
          hint="Optional"
        />

        <ClubLogoUpload
          id="club-manage-logo"
          file={logoFile}
          onChange={setLogoFile}
          currentUrl={club?.logo_url || null}
          disabled={!canEdit || busy}
        />

        {canEdit ? (
          <div className="button-row">
            <button
              type="submit"
              className="button button--primary"
              disabled={busy}
            >
              {busy ? <Spinner size="sm" label="Saving" /> : null}
              {busy ? "Saving…" : "Save details"}
            </button>
          </div>
        ) : (
          <p className="muted">Only club owners can edit these details.</p>
        )}
      </form>
    </section>
  );
}

export function ClubDetailsPanel({
  club,
  annual,
  membership,
  isSacAdmin = false,
  canArchive,
  onClubUpdated,
  onOpenArchive,
  onSupervisorSubmitted,
  canWithdrawPending,
  onOpenWithdraw,
}) {
  const canEdit =
    isSacAdmin ||
    (isClubOwner(membership?.role) && membership?.status === "ACTIVE");
  const canSubmitSupervisor =
    isClubOwner(membership?.role) &&
    membership?.status === "ACTIVE" &&
    (annual?.status === "PENDING_SUPERVISOR" || annual?.status === "ACTIVE") &&
    club?.status === "APPROVED" &&
    !club?.deleted_at;
  const isArchived = club?.status === "ARCHIVED";

  const [advisors, setAdvisors] = useState([]);
  const [requestHistory, setRequestHistory] = useState([]);
  const [supervisorNotice, setSupervisorNotice] = useState("");

  useEffect(() => {
    let active = true;

    async function loadSupervisorState() {
      if (!club?.id) return;
      if (club.status === "ARCHIVED") {
        setAdvisors([]);
        setRequestHistory([]);
        return;
      }
      try {
        const [advisorRows, requestRows] = await Promise.all([
          getActiveClubAdvisors(club.id, annual?.school_year).catch(() => []),
          getClubSupervisorRequests(club.id).catch(() => []),
        ]);
        if (!active) return;
        setAdvisors(advisorRows);
        setRequestHistory(requestRows || []);
      } catch {
        if (!active) return;
        setAdvisors([]);
        setRequestHistory([]);
      }
    }

    void loadSupervisorState();
    return () => {
      active = false;
    };
  }, [club?.id, club?.status, annual?.school_year, supervisorNotice]);

  return (
    <div
      id="manage-panel-details"
      role="tabpanel"
      aria-labelledby="manage-tab-details"
      className="stack"
    >
      <ClubDetailsForm
        key={`${club.id}-${club.updated_at || "initial"}`}
        club={club}
        canEdit={canEdit}
        onClubUpdated={onClubUpdated}
      />

      {!isArchived ? (
        <section className="panel">
          <h2>Approved teacher supervisors</h2>
          {advisors.length > 0 ? (
            <ul className="stack">
              {advisors.map((advisor) => (
                <li key={advisor.id}>
                  <strong>{advisor.supervisor_name}</strong>
                  <span className="muted"> · {advisor.supervisor_email}</span>
                  <StatusBadge status="APPROVED" />
                </li>
              ))}
            </ul>
          ) : (
            <p className="muted">No approved teacher supervisors yet.</p>
          )}

          {canWithdrawPending ? (
            <div className="button-row" style={{ marginTop: "1rem" }}>
              <button
                type="button"
                className="button button--secondary"
                onClick={onOpenWithdraw}
              >
                Withdraw pending approval
              </button>
            </div>
          ) : null}
        </section>
      ) : null}

      {!isArchived &&
      (canSubmitSupervisor || isSacAdmin || requestHistory.length > 0) ? (
        <ClubSupervisorSubmitForm
          club={club}
          canSubmit={canSubmitSupervisor}
          canView={isSacAdmin}
          onSubmitted={() => {
            setSupervisorNotice(`submitted-${Date.now()}`);
            onSupervisorSubmitted?.();
          }}
        />
      ) : isClubOwner(membership?.role) ? (
        <section className="panel">
          <h2>Teacher supervisor request</h2>
          <p className="muted">
            Supervisor requests unlock while the club is ACTIVE or pending
            teacher supervisor approval.
          </p>
        </section>
      ) : null}

      {canArchive && !isArchived ? (
        <section
          className="panel danger-zone"
          aria-labelledby="owner-archive-title"
        >
          <div className="danger-zone__header">
            <div>
              <p className="eyebrow">Danger zone</p>
              <h2 id="owner-archive-title">Archive club</h2>
              <p className="lede">
                Archives this club for the current school year and keeps it
                available for re-registration. Clubs cannot be hard-deleted
                from the database.
              </p>
            </div>
          </div>
          <div className="danger-zone__actions">
            <div className="danger-zone__action">
              <div>
                <h3>Archive club</h3>
                <p>
                  Removes the club from Explore and active operations, marks
                  memberships inactive, and keeps the club available for
                  re-registration.
                </p>
              </div>
              <button
                type="button"
                className="button button--danger"
                onClick={onOpenArchive}
              >
                Archive Club
              </button>
            </div>
          </div>
        </section>
      ) : null}
    </div>
  );
}
