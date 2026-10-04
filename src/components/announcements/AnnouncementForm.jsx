import { useState } from "react";
import { FormField } from "../ui/FormField";
import { Select } from "../ui/Select";
import { TextArea } from "../ui/TextArea";
import { TextInput } from "../ui/TextInput";
import { Spinner } from "../ui/Spinner";
import { AnnouncementStatusBadge } from "./AnnouncementStatusBadge";
import { getTorontoTodayYmd } from "../../utils/torontoDate";

export function AnnouncementForm({
  mode = "create",
  values,
  onChange,
  fieldErrors = {},
  clubs = [],
  showTypeSelector = false,
  clubReadOnly = false,
  disabled = false,
  reviewNotes = null,
  actions = [],
  submittingAction = null,
  onSubmitAction,
  error = "",
}) {
  const minPostingDate = getTorontoTodayYmd();
  const isPublishNow =
    Boolean(values.scheduledPostingDate) &&
    values.scheduledPostingDate === minPostingDate;
  const [announcementType, setAnnouncementType] = useState(
    values.clubId ? "CLUB" : "GENERAL",
  );

  function updateField(event) {
    if (disabled) return;
    const { name, value } = event.target;
    onChange?.({ ...values, [name]: value });
  }

  function handleTypeChange(event) {
    if (disabled) return;
    const nextType = event.target.value;
    setAnnouncementType(nextType);
    if (nextType === "GENERAL") {
      onChange?.({ ...values, clubId: "", visibility: "PUBLIC" });
    }
  }

  const fieldsDisabled = disabled || Boolean(submittingAction);

  return (
    <form
      className="panel form-stack"
      onSubmit={(event) => event.preventDefault()}
      noValidate
    >
      {reviewNotes ? (
        <div className="alert alert--warning" role="status">
          <strong>Review notes</strong>
          <p>{reviewNotes}</p>
        </div>
      ) : null}

      {mode === "edit" && values.status ? (
        <div className="badge-row">
          <AnnouncementStatusBadge status={values.status} />
        </div>
      ) : null}

      {showTypeSelector ? (
        <Select
          id="announcement-type"
          label="Announcement type"
          value={announcementType}
          onChange={handleTypeChange}
          disabled={fieldsDisabled}
        >
          <option value="GENERAL">General announcement</option>
          <option value="CLUB">Club announcement</option>
        </Select>
      ) : null}

      {(announcementType === "CLUB" || (!showTypeSelector && clubs.length > 0)) &&
      !clubReadOnly ? (
        <Select
          id="clubId"
          name="clubId"
          label="Club"
          value={values.clubId || ""}
          onChange={updateField}
          error={fieldErrors.clubId}
          required={!showTypeSelector || announcementType === "CLUB"}
          disabled={fieldsDisabled}
        >
          <option value="">Select a club</option>
          {clubs.map((club) => (
            <option key={club.id} value={club.id}>
              {club.name}
            </option>
          ))}
        </Select>
      ) : null}

      {clubReadOnly && values.clubName ? (
        <FormField id="club-readonly" label="Club">
          <input
            id="club-readonly"
            className="input"
            value={values.clubName}
            disabled
            readOnly
          />
        </FormField>
      ) : null}

      {clubReadOnly && !values.clubName ? (
        <FormField id="scope-readonly" label="Scope">
          <input
            id="scope-readonly"
            className="input"
            value="General announcement"
            disabled
            readOnly
          />
        </FormField>
      ) : null}

      {values.clubId || announcementType === "CLUB" ? (
        <Select
          id="announcement-visibility"
          name="visibility"
          label="Who can see this announcement?"
          value={values.visibility || "PUBLIC"}
          onChange={updateField}
          error={fieldErrors.visibility}
          required
          disabled={fieldsDisabled}
        >
          <option value="PUBLIC">Public announcement (everyone can see)</option>
          <option value="CLUB_MEMBERS">
            Club announcement (club members only)
          </option>
        </Select>
      ) : null}

      <TextInput
        id="title"
        name="title"
        label="Title"
        value={values.title}
        onChange={updateField}
        error={fieldErrors.title}
        required
        maxLength={160}
        disabled={fieldsDisabled}
      />

      <TextArea
        id="body"
        name="body"
        label="Body"
        value={values.body}
        onChange={updateField}
        error={fieldErrors.body}
        required
        rows={8}
        disabled={fieldsDisabled}
      />

      <TextInput
        id="scheduledPostingDate"
        name="scheduledPostingDate"
        type="date"
        label="Announcement posting date"
        value={values.scheduledPostingDate || ""}
        onChange={updateField}
        error={fieldErrors.scheduledPostingDate}
        min={minPostingDate}
        disabled={fieldsDisabled}
        hint={
          isPublishNow
            ? "Today selected — once approved, this announcement publishes immediately."
            : "Required to submit. Calendar date. Choose today to request publish now, or a future day to schedule."
        }
      />

      {error ? (
        <p className="form-error" role="alert">
          {error}
        </p>
      ) : null}

      {actions.length > 0 ? (
        <div className="button-row">
          {actions.map((action) => (
            <button
              key={action.value}
              type="button"
              className={
                action.primary
                  ? "button button--primary"
                  : "button button--secondary"
              }
              disabled={fieldsDisabled}
              onClick={() => onSubmitAction?.(action.value)}
            >
              {submittingAction === action.value ? (
                <>
                  <Spinner size="sm" label="Saving" /> Working…
                </>
              ) : (
                action.label
              )}
            </button>
          ))}
        </div>
      ) : null}
    </form>
  );
}
