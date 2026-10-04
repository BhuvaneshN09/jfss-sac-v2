import { useEffect, useRef, useState } from "react";
import { AnnouncementForm } from "../announcements/AnnouncementForm";
import { ErrorMessage } from "../ui/ErrorMessage";
import { createAnnouncement } from "../../services/announcements";
import { validateAnnouncementForm } from "../../utils/announcementPermissions";
import {
  getClubRequestBlockedMessage,
  isClubOwner,
} from "../../utils/clubPermissions";
import { getErrorMessage } from "../../utils/errors";

const EMPTY_ANNOUNCEMENT = {
  title: "",
  summary: "",
  body: "",
  clubId: "",
  visibility: "PUBLIC",
  scheduledPostingDate: "",
};

export function ClubAnnouncementsPanel({
  club,
  membership,
  annual,
  isSacAdmin = false,
}) {
  const operationsAllowed =
    club?.status === "APPROVED" && annual?.status === "ACTIVE";
  const isOwner =
    isClubOwner(membership?.role) && membership?.status === "ACTIVE";
  const canSubmitAnnouncement = isOwner && operationsAllowed;
  const canViewAnnouncementForm = isSacAdmin || canSubmitAnnouncement;
  const blockedMessage = getClubRequestBlockedMessage({
    clubStatus: club?.status,
    annualStatus: annual?.status,
    noun: "announcements",
    isSacAdmin,
  });

  const [values, setValues] = useState({
    ...EMPTY_ANNOUNCEMENT,
    clubId: club.id,
    clubName: club.name,
  });
  const [fieldErrors, setFieldErrors] = useState({});
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [submittingAction, setSubmittingAction] = useState(null);
  const successRef = useRef(null);

  useEffect(() => {
    if (!success || !successRef.current) return;

    const notification = successRef.current;
    const top =
      window.scrollY + notification.getBoundingClientRect().top - 112;
    window.scrollTo({ top: Math.max(0, top), behavior: "smooth" });
  }, [success]);

  const actions = canSubmitAnnouncement
    ? [{ value: "SUBMIT", label: "Submit for Review", primary: true }]
    : [];

  async function handleSubmitAction(action) {
    if (submittingAction || !canSubmitAnnouncement) return;

    const validation = validateAnnouncementForm(
      { ...values, clubId: club.id },
      { requireClub: true, requirePostingDate: action === "SUBMIT" },
    );

    if (!validation.isValid) {
      setFieldErrors(validation.errors);
      setError(Object.values(validation.errors)[0] || "Check the form.");
      return;
    }

    setFieldErrors({});
    setError("");
    setSuccess("");
    setSubmittingAction(action);

    try {
      await createAnnouncement(
        { ...validation.data, clubId: club.id, requireClub: true },
        action,
      );
      setValues({
        ...EMPTY_ANNOUNCEMENT,
        clubId: club.id,
        clubName: club.name,
      });
      setSuccess(
        action === "SUBMIT"
          ? "Announcement submitted for review. It will post on the scheduled date once approved."
          : "Announcement draft saved.",
      );
    } catch (submitError) {
      if (submitError.fieldErrors) {
        setFieldErrors(submitError.fieldErrors);
      }
      setError(
        getErrorMessage(submitError, "Could not create the announcement."),
      );
    } finally {
      setSubmittingAction(null);
    }
  }

  return (
    <div
      id="manage-panel-announcements"
      role="tabpanel"
      aria-labelledby="manage-tab-announcements"
      className="stack"
    >
      <section className="panel">
        <h2>Announcement request</h2>
        <p className="muted">
          Use announcements for club news and events. Every request needs a
          posting date. Choose today to request publish now once
          approved, or a future date to schedule midnight go-live.
        </p>

        {!canSubmitAnnouncement ? (
          <p
            className={canViewAnnouncementForm ? "alert alert--warning" : "muted"}
            role={canViewAnnouncementForm ? "status" : undefined}
          >
            {blockedMessage}
          </p>
        ) : null}

        {canViewAnnouncementForm ? (
          <>
            {error ? <ErrorMessage>{error}</ErrorMessage> : null}
            {success ? (
              <div
                ref={successRef}
                className="alert alert--success manage-announcement-success"
                role="status"
              >
                <strong>Success</strong>
                <p>{success}</p>
              </div>
            ) : null}
            <AnnouncementForm
              mode="create"
              values={values}
              onChange={setValues}
              fieldErrors={fieldErrors}
              clubs={[club]}
              clubReadOnly
              disabled={!canSubmitAnnouncement}
              actions={actions}
              submittingAction={submittingAction}
              onSubmitAction={handleSubmitAction}
              error=""
            />
          </>
        ) : isOwner ? null : (
          <p className="muted">
            Only club owners can draft and submit announcements for this club.
          </p>
        )}
      </section>
    </div>
  );
}
