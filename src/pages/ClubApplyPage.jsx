import { useEffect, useRef, useState } from "react";
import { Link } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { ClubApplyNotice } from "../components/clubs/ClubApplyNotice";
import { ClubLogoUpload } from "../components/clubs/ClubLogoUpload";
import { TeacherSupervisorSection } from "../components/clubs/TeacherSupervisorSection";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { TextArea } from "../components/ui/TextArea";
import { TextInput } from "../components/ui/TextInput";
import { Spinner } from "../components/ui/Spinner";
import {
  CLUB_APPLICATION_SCHOOL_YEAR,
  MEETING_DAYS,
} from "../config/clubApplications";
import {
  deleteClubApplicationDocument,
  uploadClubApplicationDocument,
} from "../services/clubDocuments";
import {
  deleteClubLogo,
  uploadNewClubLogo,
} from "../services/clubLogos";
import { isClubNameTaken, submitClubRegistrationApplication } from "../services/clubRequests";
import { isValidPdsbEmail, normalizePdsbEmail } from "../utils/clubPermissions";
import { getErrorMessage, CLUB_NAME_TAKEN_MESSAGE } from "../utils/errors";
import { validateOptionalHttpsUrl, validateOwnerNames } from "../utils/validation";

const INITIAL = {
  proposed_name: "",
  description: "",
  student_benefit: "",
  leader_details: "",
  owner_names: "",
  public_email: "",
  instagram_handle: "",
  member_application_url: "",
  exec_application_url: "",
  meeting_days: [],
  meeting_time_details: "",
  meeting_location: "",
  potential_event_ideas: "",
};

function isValidEmail(value) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(value || "").trim());
}

export function ClubApplyPage() {
  const { user, profile } = useAuth();
  const [values, setValues] = useState(INITIAL);
  const [supervisorName, setSupervisorName] = useState("");
  const [supervisorEmail, setSupervisorEmail] = useState("");
  const [file, setFile] = useState(null);
  const [logoFile, setLogoFile] = useState(null);
  const [fieldErrors, setFieldErrors] = useState({});
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [successId, setSuccessId] = useState(null);
  const [statusTick, setStatusTick] = useState(0);
  const alertRef = useRef(null);

  useEffect(() => {
    if (!statusTick) return;

    const frame = window.requestAnimationFrame(() => {
      window.scrollTo({ top: 0, left: 0, behavior: "smooth" });
      alertRef.current?.scrollIntoView({
        behavior: "smooth",
        block: "start",
      });
    });

    return () => window.cancelAnimationFrame(frame);
  }, [statusTick]);

  function revealStatus() {
    setStatusTick((tick) => tick + 1);
  }

  function showError(message) {
    setSuccessId(null);
    setError(message);
    revealStatus();
  }

  const respondentEmail = profile?.email || user?.email || "";

  function updateField(event) {
    const { name, value } = event.target;
    setValues((current) => ({ ...current, [name]: value }));
  }

  function toggleMeetingDay(day) {
    setValues((current) => {
      const selected = current.meeting_days.includes(day);
      return {
        ...current,
        meeting_days: selected
          ? current.meeting_days.filter((item) => item !== day)
          : [...current.meeting_days, day],
      };
    });
  }

  function validate() {
    const errors = {};
    if (values.proposed_name.trim().length < 2) {
      errors.proposed_name = "Enter your club name.";
    }
    if (values.description.trim().length < 10) {
      errors.description =
        "Provide a detailed description of your club.";
    }
    if (values.student_benefit.trim().length < 10) {
      errors.student_benefit =
        "Explain how the club benefits JFSS students.";
    }
    if (values.leader_details.trim().length < 5) {
      errors.leader_details = "Include each leader’s full name and grade.";
    }
    const ownerNamesError = validateOwnerNames(values.owner_names);
    if (ownerNamesError) {
      errors.owner_names = ownerNamesError;
    }
    if (!isValidEmail(values.public_email)) {
      errors.public_email = "Enter a valid public club email.";
    }
    if (!values.instagram_handle.trim()) {
      errors.instagram_handle = "Enter the club Instagram handle.";
    }
    const memberUrlError = validateOptionalHttpsUrl(
      values.member_application_url,
      { label: "member application link" },
    );
    if (memberUrlError) errors.member_application_url = memberUrlError;
    const execUrlError = validateOptionalHttpsUrl(values.exec_application_url, {
      label: "executive application link",
    });
    if (execUrlError) errors.exec_application_url = execUrlError;

    if (supervisorName.trim().length < 2) {
      errors.supervisor_name = "Enter the teacher’s full name.";
    }
    const email = normalizePdsbEmail(supervisorEmail);
    if (!isValidPdsbEmail(email)) {
      errors.supervisor_email =
        "Enter an exact teacher @pdsb.net email address.";
    }
    if (!file) {
      errors.signed_form = "Upload the signed Teacher Supervisor Form image.";
    }

    return { errors, email };
  }

  async function handleSubmit(event) {
    event.preventDefault();
    if (submitting) return;

    setError("");
    setSuccessId(null);

    const { errors, email } = validate();
    setFieldErrors(errors);
    if (Object.keys(errors).length > 0) {
      showError("Please fix the highlighted fields before submitting.");
      return;
    }

    try {
      if (await isClubNameTaken(values.proposed_name)) {
        setFieldErrors({
          proposed_name: CLUB_NAME_TAKEN_MESSAGE,
        });
        showError(CLUB_NAME_TAKEN_MESSAGE);
        return;
      }
    } catch (checkError) {
      showError(
        getErrorMessage(checkError, "Could not verify the club name."),
      );
      return;
    }

    const requestId = crypto.randomUUID();
    let uploadedPath = null;
    let uploadedLogoPath = null;
    setSubmitting(true);

    try {
      uploadedPath = await uploadClubApplicationDocument({
        folder: "new-club-applications",
        userId: user.id,
        submissionId: requestId,
        file,
      });

      if (logoFile) {
        uploadedLogoPath = await uploadNewClubLogo({
          userId: user.id,
          requestId,
          file: logoFile,
        });
      }

      await submitClubRegistrationApplication({
        requestId,
        proposedName: values.proposed_name,
        description: values.description,
        studentBenefit: values.student_benefit,
        leaderDetails: values.leader_details,
        ownerNames: values.owner_names,
        teacherSupervisorEmails: [email],
        clubContactInformation: values.public_email.trim().toLowerCase(),
        instagramHandle: values.instagram_handle.trim().replace(/^@+/, ""),
        meetingDays: values.meeting_days,
        meetingTimeDetails: values.meeting_time_details,
        meetingLocation: values.meeting_location,
        memberApplicationUrl: values.member_application_url.trim() || null,
        execApplicationUrl: values.exec_application_url.trim() || null,
        logoStoragePath: uploadedLogoPath,
        facultyAdvisorName: supervisorName.trim(),
        teacherSupervisorFormStoragePath: uploadedPath,
        potentialEventIdeas: values.potential_event_ideas,
        schoolYear: CLUB_APPLICATION_SCHOOL_YEAR,
      });

      setSuccessId(requestId);
      revealStatus();
      setValues(INITIAL);
      setSupervisorName("");
      setSupervisorEmail("");
      setFile(null);
      setLogoFile(null);
      setFieldErrors({});
    } catch (submitError) {
      if (uploadedPath) {
        await deleteClubApplicationDocument(uploadedPath);
      }
      if (uploadedLogoPath) {
        await deleteClubLogo(uploadedLogoPath);
      }
      showError(
        getErrorMessage(submitError, "Could not submit your club application."),
      );
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="page narrow-page">
      <div ref={alertRef} className="club-apply-status">
        {error ? <ErrorMessage>{error}</ErrorMessage> : null}

        {successId ? (
          <div className="alert alert--success" role="status">
            <strong>Application submitted</strong>
            <p>
              Your new club application was submitted successfully.{" "}
              <Link className="text-link" to="/my-requests/applications">
                View my requests
              </Link>
            </p>
          </div>
        ) : null}
      </div>

      <ClubApplyNotice accountEmail={respondentEmail} />

      <form className="stack" onSubmit={handleSubmit} noValidate>
        <div className="panel form-stack">
          <TextInput
            id="proposed_name"
            name="proposed_name"
            label="What is your club name?"
            value={values.proposed_name}
            onChange={updateField}
            error={fieldErrors.proposed_name}
            required
            disabled={submitting}
          />

          <TextArea
            id="description"
            name="description"
            label="Description"
            value={values.description}
            onChange={updateField}
            error={fieldErrors.description}
            rows={5}
            required
            disabled={submitting}
          />

          <TextArea
            id="student_benefit"
            name="student_benefit"
            label="How does this club benefit students at JFSS?"
            value={values.student_benefit}
            onChange={updateField}
            error={fieldErrors.student_benefit}
            rows={4}
            required
            disabled={submitting}
          />

          <TextArea
            id="leader_details"
            name="leader_details"
            label="Who are/is your club leader(s)? Include each leader’s full name and grade."
            value={values.leader_details}
            onChange={updateField}
            error={fieldErrors.leader_details}
            rows={4}
            required
            disabled={submitting}
          />

          <TextArea
            id="owner_names"
            name="owner_names"
            label="Names of all club owners"
            value={values.owner_names}
            onChange={updateField}
            error={fieldErrors.owner_names}
            rows={3}
            required
            disabled={submitting}
            hint="List the full name of every owner. A club may have at most three owners."
          />

          <TextInput
            id="public_email"
            name="public_email"
            type="email"
            label="Public club email"
            value={values.public_email}
            onChange={updateField}
            error={fieldErrors.public_email}
            required
            disabled={submitting}
          />

          <TextInput
            id="instagram_handle"
            name="instagram_handle"
            label="Instagram handle"
            value={values.instagram_handle}
            onChange={updateField}
            error={fieldErrors.instagram_handle}
            required
            disabled={submitting}
          />

          <TextInput
            id="member_application_url"
            name="member_application_url"
            type="url"
            label="Link to member application"
            value={values.member_application_url}
            onChange={updateField}
            error={fieldErrors.member_application_url}
            disabled={submitting}
            hint="Optional. Use an https:// link."
          />

          <TextInput
            id="exec_application_url"
            name="exec_application_url"
            type="url"
            label="Link to executive application"
            value={values.exec_application_url}
            onChange={updateField}
            error={fieldErrors.exec_application_url}
            disabled={submitting}
            hint="Optional. Use an https:// link."
          />

          <fieldset className="form-field meeting-day-picker">
            <legend>
              Meeting days <span className="muted">(optional)</span>
            </legend>
            <div className="meeting-day-picker__row" role="group">
              {MEETING_DAYS.map((day) => {
                const selected = values.meeting_days.includes(day);
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
                    disabled={submitting}
                    onClick={() => toggleMeetingDay(day)}
                  >
                    {day.slice(0, 3)}
                  </button>
                );
              })}
            </div>
          </fieldset>

          <TextInput
            id="meeting_time_details"
            name="meeting_time_details"
            label="Meeting time / details"
            placeholder="e.g. lunch, before school, after school"
            value={values.meeting_time_details}
            onChange={updateField}
            disabled={submitting}
            hint="Optional"
          />

          <TextInput
            id="meeting_location"
            name="meeting_location"
            label="Meeting location"
            value={values.meeting_location}
            onChange={updateField}
            disabled={submitting}
            hint="Optional"
          />

          <ClubLogoUpload
            file={logoFile}
            onChange={setLogoFile}
            disabled={submitting}
          />

          <TextArea
            id="potential_event_ideas"
            name="potential_event_ideas"
            label="Does your club have any planned or potential event ideas for the upcoming year? If yes, provide rough details, including what, when, and where."
            value={values.potential_event_ideas}
            onChange={updateField}
            rows={4}
            disabled={submitting}
            hint="Optional"
          />

        </div>

        <TeacherSupervisorSection
          name={supervisorName}
          email={supervisorEmail}
          onNameChange={(event) => setSupervisorName(event.target.value)}
          onEmailChange={(event) => setSupervisorEmail(event.target.value)}
          file={file}
          onFileChange={setFile}
          nameError={fieldErrors.supervisor_name}
          emailError={fieldErrors.supervisor_email}
          fileError={fieldErrors.signed_form}
          disabled={submitting}
          required
        >
          <button
            type="submit"
            className="button button--primary"
            disabled={submitting}
          >
            {submitting ? (
              <>
                <Spinner size="sm" label="Submitting" /> Submitting…
              </>
            ) : (
              "Submit club application"
            )}
          </button>
        </TeacherSupervisorSection>
      </form>
    </div>
  );
}
