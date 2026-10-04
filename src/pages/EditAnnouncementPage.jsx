import { useEffect, useMemo, useState } from "react";
import { Link, Navigate, useNavigate, useParams } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { AnnouncementForm } from "../components/announcements/AnnouncementForm";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { LoadingScreen } from "../components/ui/LoadingScreen";
import {
  editAnnouncement,
  getAnnouncementById,
} from "../services/announcements";
import {
  canEditAnnouncement,
  getAllowedEditActions,
  toDateOnlyValue,
  validateAnnouncementForm,
} from "../utils/announcementPermissions";
import { getErrorMessage } from "../utils/errors";

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const ACTION_LABELS = {
  SAVE: "Save",
  SUBMIT: "Submit for Review",
};

export function EditAnnouncementPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const {
    user,
    isSacAdmin,
    isFacultyAdvisor,
    ownedClubs,
  } = useAuth();

  const [announcement, setAnnouncement] = useState(null);
  const [values, setValues] = useState(null);
  const [loading, setLoading] = useState(true);
  const [fieldErrors, setFieldErrors] = useState({});
  const [error, setError] = useState("");
  const [submittingAction, setSubmittingAction] = useState(null);
  const [unauthorized, setUnauthorized] = useState(false);

  useEffect(() => {
    let active = true;

    async function load() {
      setLoading(true);
      setError("");

      if (!UUID_PATTERN.test(id || "")) {
        setError("Invalid announcement link.");
        setLoading(false);
        return;
      }

      try {
        const data = await getAnnouncementById(id);
        if (!active) return;

        if (!data) {
          setUnauthorized(true);
          return;
        }

        const allowed = canEditAnnouncement({
          announcement: data,
          userId: user.id,
          isSacAdmin,
          isFacultyAdvisor,
          ownedClubs,
        });

        if (!allowed) {
          setUnauthorized(true);
          return;
        }

        setAnnouncement(data);
        setValues({
          title: data.title || "",
          summary: data.summary || "",
          body: data.body || "",
          clubId: data.club_id || "",
          visibility: data.visibility || "PUBLIC",
          clubName: data.clubs?.name || "",
          scheduledPostingDate: toDateOnlyValue(data.scheduled_posting_date),
          status: data.status,
        });
      } catch (loadError) {
        if (!active) return;
        setError(
          getErrorMessage(
            loadError,
            "The announcement could not be found or you do not have permission to edit it.",
          ),
        );
      } finally {
        if (active) setLoading(false);
      }
    }

    load();
    return () => {
      active = false;
    };
  }, [
    id,
    user.id,
    isSacAdmin,
    isFacultyAdvisor,
    ownedClubs,
  ]);

  const allowedActions = useMemo(
    () =>
      getAllowedEditActions({
        announcement,
        userId: user.id,
        isSacAdmin,
        isFacultyAdvisor,
        ownedClubs,
      }),
    [
      announcement,
      user.id,
      isSacAdmin,
      isFacultyAdvisor,
      ownedClubs,
    ],
  );

  const formActions = allowedActions.map((action) => ({
    value: action,
    label:
      action === "SUBMIT" && announcement?.status === "CHANGES_REQUESTED"
        ? "Resubmit"
        : ACTION_LABELS[action] || action,
    primary: action !== "SAVE",
  }));

  if (loading) {
    return <LoadingScreen message="Loading announcement…" />;
  }

  if (unauthorized) {
    return <Navigate to="/my-requests/announcements" replace />;
  }

  if (error || !values) {
    return (
      <div className="page narrow-page">
        <ErrorMessage>{error || "Unable to edit this announcement."}</ErrorMessage>
        <Link className="text-link" to="/my-requests/announcements">
          Back to My Announcements
        </Link>
      </div>
    );
  }

  async function handleSubmitAction(action) {
    if (submittingAction) return;

    const validation = validateAnnouncementForm(values, {
      requirePostingDate: action === "SUBMIT",
    });
    setFieldErrors(validation.errors);
    setError("");

    if (!validation.isValid) {
      setError("Please fix the highlighted fields before continuing.");
      return;
    }

    setSubmittingAction(action);

    try {
      await editAnnouncement(id, validation.data, action);

      navigate("/my-requests/announcements", {
        replace: true,
        state: {
          notice:
            action === "SUBMIT"
              ? "Announcement submitted for SAC review."
              : "Announcement saved.",
        },
      });
    } catch (submitError) {
      if (submitError.fieldErrors) {
        setFieldErrors(submitError.fieldErrors);
      }
      setError(
        getErrorMessage(submitError, "Could not update the announcement."),
      );
    } finally {
      setSubmittingAction(null);
    }
  }

  return (
    <div className="page narrow-page">
      <header className="page-header">
        <div>
          <p className="eyebrow">Edit</p>
          <h1>Edit announcement</h1>
          <p className="lede">
            Club association cannot be changed after creation. Choosing today’s
            posting date publishes immediately on approval; future dates go live
            at midnight that day.
          </p>
        </div>
      </header>

      {error ? <ErrorMessage>{error}</ErrorMessage> : null}

      <AnnouncementForm
        mode="edit"
        values={values}
        onChange={setValues}
        fieldErrors={fieldErrors}
        clubReadOnly
        reviewNotes={
          announcement.status === "CHANGES_REQUESTED"
            ? announcement.review_notes
            : null
        }
        actions={formActions}
        submittingAction={submittingAction}
        onSubmitAction={handleSubmitAction}
      />
    </div>
  );
}
