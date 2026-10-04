import { useState } from "react";
import { Link } from "react-router-dom";
import { useAuth } from "../../context/AuthContext";
import { ErrorMessage } from "../ui/ErrorMessage";
import { FilePicker } from "../ui/FilePicker";
import { LocalFilePreview } from "../ui/LocalFilePreview";
import { Spinner } from "../ui/Spinner";
import { TextArea } from "../ui/TextArea";
import { TextInput } from "../ui/TextInput";
import { EVENT_APPROVAL_FORM_URL } from "../../config/clubApplications";
import {
  deleteClubEventPhoto,
  deleteClubEventSignature,
  submitClubEventRequest,
  uploadClubEventPhoto,
  uploadClubEventSignature,
  validateClubEventPhoto,
  validateClubEventSignatureFile,
} from "../../services/clubEvents";
import { validateClubEventForm } from "../../utils/clubEvents";
import { getTorontoTodayYmd } from "../../utils/torontoDate";
import { getErrorMessage } from "../../utils/errors";

function SignatureUpload({
  id,
  label,
  file,
  error,
  disabled,
  onChange,
  onRemove,
}) {
  return (
    <div className="stack">
      <FilePicker
        id={id}
        label={label}
        accept="image/jpeg,image/png,image/webp,application/pdf"
        required
        disabled={disabled}
        files={file}
        buttonLabel="Choose file"
        emptyLabel="No form file chosen"
        hint="Upload the completed signed form as an image or PDF (max 10 MB)."
        error={error}
        onChange={onChange}
      />
      {file ? (
        <LocalFilePreview
          file={file}
          disabled={disabled}
          alt={label}
          removeLabel="Remove file"
          onRemove={onRemove}
        />
      ) : null}
    </div>
  );
}

export function ClubEventForm({
  club,
  canSubmit = true,
  canView = false,
  blockedMessage,
  onSubmitted,
}) {
  const { user } = useAuth();
  const [eventName, setEventName] = useState("");
  const [eventDescription, setEventDescription] = useState("");
  const [eventStartDate, setEventStartDate] = useState("");
  const [eventEndDate, setEventEndDate] = useState("");
  const [requestedMaterials, setRequestedMaterials] = useState("");
  const [isCharitableEvent, setIsCharitableEvent] = useState(false);
  const [signedForm, setSignedForm] = useState(null);
  const [photo, setPhoto] = useState(null);
  const [fieldErrors, setFieldErrors] = useState({});
  const [signatureError, setSignatureError] = useState("");
  const [photoError, setPhotoError] = useState("");
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [uploadProgress, setUploadProgress] = useState("");
  const [success, setSuccess] = useState(false);

  function updateSignedForm(file) {
    const nextError = file ? validateClubEventSignatureFile(file) : null;
    setSignatureError(nextError || "");
    if (nextError) return;
    setSignedForm(file);
  }

  function handlePhotoChange(file) {
    const nextError = validateClubEventPhoto(file);
    setPhotoError(nextError || "");
    if (!nextError) setPhoto(file);
  }

  async function handleSubmit(event) {
    event.preventDefault();
    if (submitting || !canSubmit || !club) return;

    const validation = validateClubEventForm({
      eventName,
      eventDescription,
      eventStartDate,
      eventEndDate,
      requestedMaterials,
      isCharitableEvent,
      signedForm,
    });
    setFieldErrors(validation.errors);
    setError("");

    if (!validation.isValid || signatureError || photoError) {
      setError("Please fix the highlighted fields before submitting.");
      return;
    }

    const requestId = crypto.randomUUID();
    let signedFormPath = null;
    let photoPath = null;
    setSubmitting(true);

    try {
      setUploadProgress("Uploading signed Event Approval Form…");
      signedFormPath = await uploadClubEventSignature({
        userId: user.id,
        requestId,
        file: signedForm,
      });

      if (photo) {
        setUploadProgress("Uploading event photo…");
        photoPath = await uploadClubEventPhoto({
          userId: user.id,
          requestId,
          file: photo,
        });
      }

      setUploadProgress("Submitting event proposal…");
      await submitClubEventRequest({
        requestId,
        clubId: club.id,
        eventName: validation.data.eventName,
        eventDescription: validation.data.eventDescription,
        eventStartDate: validation.data.eventStartDate,
        eventEndDate: validation.data.eventEndDate,
        requestedMaterials: validation.data.requestedMaterials,
        isCharitableEvent: validation.data.isCharitableEvent,
        signedFormStoragePath: signedFormPath,
        photoStoragePath: photoPath,
      });

      setSuccess(true);
      setFieldErrors({});
      onSubmitted?.();
    } catch (submitError) {
      if (signedFormPath) await deleteClubEventSignature(signedFormPath);
      if (photoPath) await deleteClubEventPhoto(photoPath);
      setError(
        getErrorMessage(submitError, "Could not submit the event proposal."),
      );
    } finally {
      setUploadProgress("");
      setSubmitting(false);
    }
  }

  if (!canSubmit && !canView) {
    return (
      <p className="muted">
        {blockedMessage ||
          "Only active club owners can submit event proposals."}
      </p>
    );
  }

  if (success) {
    return (
      <div className="alert alert--success" role="status">
        <strong>Event proposal submitted</strong>
        <p>
          Your proposal for {club.name} was submitted for review.
        </p>
        <Link className="text-link" to="/my-requests/events">
          View my event proposals
        </Link>
      </div>
    );
  }

  const fieldsDisabled = submitting || !canSubmit;

  return (
    <form className="stack" onSubmit={handleSubmit} noValidate>
      {!canSubmit ? (
        <p className="alert alert--warning" role="status">
          {blockedMessage ||
            "Only active club owners can submit event proposals."}
        </p>
      ) : null}
      {error ? <ErrorMessage>{error}</ErrorMessage> : null}

      <section
        className="panel funding-guidelines"
        aria-labelledby={`event-guidelines-title-${club.id}`}
      >
        <h3 id={`event-guidelines-title-${club.id}`}>Hey Jags,</h3>
        <p>
          Are you interested in planning an event for your club? If so, please
          complete the form below to submit your event proposal for review and
          potential approval.
        </p>
        <p>
          Please note that submitting this form does not guarantee that your
          event will be approved. Additionally, your event must be approved
          before you submit a Club Funding Request Form.
        </p>
        <p>
          We encourage you to provide as much detail as possible to help us
          review your proposal efficiently.
        </p>
        <ul>
          <li>Club fundraisers may only be scheduled for Fridays.</li>
        </ul>
        <p>
          If you have any questions, please contact our club liaisons through
          email or Instagram:
        </p>
        <ul>
          <li>
            Eshaal Cheema (Email: 778345@pdsb.net | Instagram: eshaal_0009)
          </li>
          <li>
            Rasleen Kaur (Email: 1099702@pdsb.net | Instagram: rasleenk._b)
          </li>
        </ul>
      </section>

      <section className="panel form-stack">
        <p className="muted teacher-supervisor-section__link-line">
          <a
            className="text-link"
            href={EVENT_APPROVAL_FORM_URL}
            target="_blank"
            rel="noopener noreferrer"
          >
            Open the Event Approval Signature Form
          </a>
          {" — complete, sign, and upload the form below."}
        </p>
        <SignatureUpload
          id={`event-signed-form-${club.id}`}
          label="Event Approval Form attachment"
          file={signedForm}
          error={signatureError || fieldErrors.signedForm}
          disabled={fieldsDisabled}
          onChange={updateSignedForm}
          onRemove={() => updateSignedForm(null)}
        />
        <TextInput
          id={`event-club-name-${club.id}`}
          label="Name of club"
          value={club.name}
          disabled
        />
        <TextInput
          id={`event-name-${club.id}`}
          label="Name of event"
          value={eventName}
          onChange={(event) => setEventName(event.target.value)}
          error={fieldErrors.eventName}
          required
          disabled={fieldsDisabled}
        />
        <TextArea
          id={`event-description-${club.id}`}
          label="Detailed description of the event"
          value={eventDescription}
          onChange={(event) => setEventDescription(event.target.value)}
          error={fieldErrors.eventDescription}
          hint="Include what the event is and where you would like it to be held."
          rows={7}
          required
          disabled={fieldsDisabled}
        />
        <TextInput
          id={`event-start-date-${club.id}`}
          label="Start date"
          type="date"
          value={eventStartDate}
          onChange={(event) => setEventStartDate(event.target.value)}
          error={fieldErrors.eventStartDate}
          min={getTorontoTodayYmd()}
          required
          disabled={fieldsDisabled}
        />
        <TextInput
          id={`event-end-date-${club.id}`}
          label="End date"
          type="date"
          value={eventEndDate}
          onChange={(event) => setEventEndDate(event.target.value)}
          error={fieldErrors.eventEndDate}
          min={eventStartDate || getTorontoTodayYmd()}
          required
          disabled={fieldsDisabled}
        />
        <TextArea
          id={`event-materials-${club.id}`}
          label="What SAC/school material will you be using?"
          value={requestedMaterials}
          onChange={(event) => setRequestedMaterials(event.target.value)}
          error={fieldErrors.requestedMaterials}
          hint="For example: tables, chairs, or other school equipment."
          rows={4}
          required
          disabled={fieldsDisabled}
        />
        <label className="checkbox" htmlFor={`event-charitable-${club.id}`}>
          <input
            id={`event-charitable-${club.id}`}
            type="checkbox"
            name="is_charitable_event"
            checked={isCharitableEvent}
            onChange={(event) => setIsCharitableEvent(event.target.checked)}
            disabled={fieldsDisabled}
          />
          Is this a charitable event?
        </label>
        <FilePicker
          id={`event-photo-${club.id}`}
          label="Event photo"
          accept="image/jpeg,image/png,image/webp"
          files={photo}
          buttonLabel="Choose photo"
          emptyLabel="No photo chosen"
          hint="Optional. JPEG, PNG, or WebP up to 10 MB."
          error={photoError}
          disabled={fieldsDisabled}
          onChange={handlePhotoChange}
        />
        {photo ? (
          <LocalFilePreview
            file={photo}
            alt="Selected event photo"
            disabled={fieldsDisabled}
            removeLabel="Remove photo"
            onRemove={() => {
              setPhoto(null);
              setPhotoError("");
            }}
          />
        ) : null}
      </section>

      {uploadProgress ? <p className="form-hint">{uploadProgress}</p> : null}
      {canSubmit ? (
        <div className="button-row">
          <button
            type="submit"
            className="button button--primary"
            disabled={fieldsDisabled}
          >
            {submitting ? <Spinner size="sm" label="Submitting" /> : null}
            Submit event proposal
          </button>
        </div>
      ) : null}
    </form>
  );
}
