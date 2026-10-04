import { TEACHER_SUPERVISOR_FORM_URL } from "../../config/clubApplications";
import { SignedFormUpload } from "./SignedFormUpload";
import { TextInput } from "../ui/TextInput";

/**
 * Shared teacher supervisor panel for new-club and re-application forms.
 * Collects full name, PDSB email, and signed form attachment.
 */
export function TeacherSupervisorSection({
  nameId = "teacher-supervisor-name",
  emailId = "teacher-supervisor-email",
  name,
  email,
  onNameChange,
  onEmailChange,
  file,
  onFileChange,
  nameError,
  emailError,
  fileError,
  error,
  disabled = false,
  required = true,
  seeking = false,
  onSeekingChange,
  showSeekingOption = false,
  children,
}) {
  const fieldsRequired = required && !seeking;

  return (
    <section className="panel form-stack teacher-supervisor-section">
      <h2 className="teacher-supervisor-section__title">Teacher supervisor</h2>

      {showSeekingOption ? (
        <label className="checkbox">
          <input
            type="checkbox"
            name="is_seeking_teacher_supervisor"
            checked={seeking}
            onChange={onSeekingChange}
            disabled={disabled}
          />
          We are still searching for our club teacher supervisor.
        </label>
      ) : null}

      <p className="muted teacher-supervisor-section__link-line">
        <a
          className="text-link"
          href={TEACHER_SUPERVISOR_FORM_URL}
          target="_blank"
          rel="noopener noreferrer"
        >
          Open the Teacher Supervisor Form
        </a>
        {fieldsRequired
          ? " — complete, sign, and upload the form below."
          : " — upload optional if you already have a signed copy."}
      </p>

      <TextInput
        id={nameId}
        label="Teacher full name"
        value={name}
        onChange={onNameChange}
        error={nameError}
        required={fieldsRequired}
        disabled={disabled}
      />

      <TextInput
        id={emailId}
        type="email"
        label="Teacher email"
        value={email}
        onChange={onEmailChange}
        error={emailError}
        required={fieldsRequired}
        disabled={disabled}
        hint="Must be an exact @pdsb.net address."
      />

      <SignedFormUpload
        label="Teacher Supervisor Form attachment"
        file={file}
        onChange={onFileChange}
        error={fileError}
        disabled={disabled}
        required={fieldsRequired}
      />

      {error ? <p className="form-error">{error}</p> : null}

      {children}
    </section>
  );
}
