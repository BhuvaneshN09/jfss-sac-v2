import { useEffect, useId, useMemo, useRef, useState } from "react";
import { Link, useSearchParams } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { ClubApplyNotice } from "../components/clubs/ClubApplyNotice";
import { ClubLogoUpload } from "../components/clubs/ClubLogoUpload";
import { TeacherSupervisorSection } from "../components/clubs/TeacherSupervisorSection";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { TextArea } from "../components/ui/TextArea";
import { TextInput } from "../components/ui/TextInput";
import { Spinner } from "../components/ui/Spinner";
import {
  CLUB_APPLICATION_DOCUMENTS_BUCKET,
  CLUB_LOGOS_BUCKET,
  CLUB_APPLICATION_SCHOOL_YEAR,
  MEETING_DAYS,
  REAPP_LOGO_ALLOWED_TYPES,
  REAPP_LOGO_MAX_BYTES,
  SIGNED_FORM_ALLOWED_TYPES,
} from "../config/clubApplications";
import { supabase } from "../lib/supabase";
import { validateSignedFormFile } from "../services/clubDocuments";
import { validateClubLogoFile } from "../services/clubLogos";
import {
  listEligibleClubsForReapplication,
  submitClubReapplication,
  validateSupervisorEntries,
} from "../services/clubReapplications";
import { getVisibleMeetingSchedule } from "../utils/clubSchedule";
import { getErrorMessage } from "../utils/errors";
import { assertFileMatchesDeclaredType } from "../utils/fileMagic";
import { prepareImageFileForUpload } from "../utils/imageUpload";
import { validateOptionalHttpsUrl, validateOwnerNames } from "../utils/validation";

const INITIAL = {
  club_id: "",
  description: "",
  owner_names: "",
  public_email: "",
  instagram_handle: "",
  member_application_url: "",
  exec_application_url: "",
  meeting_days: [],
  meeting_time_details: "",
  meeting_location: "",
  is_seeking_teacher_supervisor: false,
  declaration_accepted: false,
};

function emptySupervisor() {
  return { name: "", email: "" };
}

function isValidEmail(value) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(value || "").trim());
}

function isClubIdParam(value) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
    String(value || ""),
  );
}

/** Backend still stores short_description separately — derive from the one field. */
function deriveShortDescription(description) {
  const text = String(description || "")
    .trim()
    .replace(/\s+/g, " ");
  if (text.length <= 500) return text;
  return `${text.slice(0, 497).trimEnd()}…`;
}

export function ClubReapplyPage() {
  const { user, profile } = useAuth();
  const [searchParams] = useSearchParams();
  const listboxId = useId();
  const comboboxRef = useRef(null);
  const appliedPresetClubRef = useRef(false);
  const presetClubId = isClubIdParam(searchParams.get("club"))
    ? searchParams.get("club")
    : "";

  const [search, setSearch] = useState("");
  const [options, setOptions] = useState([]);
  const [optionsLoading, setOptionsLoading] = useState(true);
  const [listOpen, setListOpen] = useState(false);
  const [activeIndex, setActiveIndex] = useState(0);
  const [selectedClub, setSelectedClub] = useState(null);

  const [values, setValues] = useState(INITIAL);
  const [supervisor, setSupervisor] = useState(emptySupervisor);
  const [logoFile, setLogoFile] = useState(null);
  const [signedFormFile, setSignedFormFile] = useState(null);
  const [fieldErrors, setFieldErrors] = useState({});
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [uploadProgress, setUploadProgress] = useState("");
  const [successId, setSuccessId] = useState(null);

  const applicantEmail = profile?.email || user?.email || "";

  useEffect(() => {
    let active = true;
    const handle = window.setTimeout(async () => {
      setOptionsLoading(true);
      try {
        const data = await listEligibleClubsForReapplication(search);
        if (active) {
          setOptions(data);
          setActiveIndex(0);
        }
      } catch (loadError) {
        if (active) {
          setOptions([]);
          setError(
            getErrorMessage(loadError, "Could not load eligible past clubs."),
          );
        }
      } finally {
        if (active) setOptionsLoading(false);
      }
    }, 200);

    return () => {
      active = false;
      window.clearTimeout(handle);
    };
  }, [search]);

  const selectedLabel = useMemo(() => {
    if (!selectedClub) return "";
    return selectedClub.name;
  }, [selectedClub]);
  const historicalMeetingSchedule = getVisibleMeetingSchedule(
    selectedClub?.historical_meeting_schedule,
  );

  function updateField(event) {
    const { name, value, type, checked } = event.target;
    setValues((current) => ({
      ...current,
      [name]: type === "checkbox" ? checked : value,
    }));
  }

  function toggleMeetingDay(day) {
    setValues((current) => {
      const has = current.meeting_days.includes(day);
      return {
        ...current,
        meeting_days: has
          ? current.meeting_days.filter((item) => item !== day)
          : [...current.meeting_days, day],
      };
    });
  }

  function selectClub(club) {
    setSelectedClub(club);
    setValues((current) => ({
      ...current,
      club_id: club.id,
      description: club.historical_description || "",
      meeting_location: club.historical_meeting_location || current.meeting_location,
    }));
    setSearch(club.name);
    setListOpen(false);
    setFieldErrors((current) => ({
      ...current,
      club_id: undefined,
      description: undefined,
    }));
  }

  useEffect(() => {
    if (!presetClubId || appliedPresetClubRef.current || optionsLoading) {
      return;
    }

    const match = options.find((club) => club.id === presetClubId);
    if (match) {
      appliedPresetClubRef.current = true;
      selectClub(match);
      return;
    }

    if (error) {
      return;
    }

    appliedPresetClubRef.current = true;
    setError("This club is not currently available for re-application.");
  }, [presetClubId, options, optionsLoading, error]);

  function clearClub() {
    setSelectedClub(null);
    setValues((current) => ({
      ...current,
      club_id: "",
      description: "",
    }));
    setSearch("");
  }

  function validate() {
    const errors = {};
    if (!values.club_id || !selectedClub) {
      errors.club_id = "Select an eligible past club.";
    }
    if (values.description.trim().length < 10) {
      errors.description = "Enter the club description.";
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
    if (logoFile) {
      if (!REAPP_LOGO_ALLOWED_TYPES.includes(logoFile.type)) {
        errors.logo = "Logo must be JPEG, PNG, or WebP.";
      } else if (logoFile.size > REAPP_LOGO_MAX_BYTES) {
        errors.logo = "Logo must be 5 MB or smaller.";
      }
    }

    const needsSupervisor = !values.is_seeking_teacher_supervisor;
    const { error: supervisorError } = validateSupervisorEntries(
      [supervisor],
      {
        required: needsSupervisor,
        max: 1,
      },
    );
    if (supervisorError) {
      errors.supervisors = supervisorError;
    }

    if (needsSupervisor) {
      const formError = validateSignedFormFile(signedFormFile);
      if (formError) {
        errors.signed_form = formError;
      }
    } else if (signedFormFile) {
      const formError = validateSignedFormFile(signedFormFile);
      if (formError) {
        errors.signed_form = formError;
      }
    }

    if (!values.declaration_accepted) {
      errors.declaration_accepted = "Confirm the declaration to submit.";
    }

    return errors;
  }

  async function uploadFile(bucket, path, file) {
    const validationError =
      bucket === CLUB_LOGOS_BUCKET
        ? validateClubLogoFile(file)
        : bucket === CLUB_APPLICATION_DOCUMENTS_BUCKET
          ? validateSignedFormFile(file)
          : "This file type cannot be uploaded here.";
    if (validationError) {
      throw new Error(validationError);
    }

    await assertFileMatchesDeclaredType(
      file,
      bucket === CLUB_LOGOS_BUCKET
        ? REAPP_LOGO_ALLOWED_TYPES
        : SIGNED_FORM_ALLOWED_TYPES,
    );

    const { error: uploadError } = await supabase.storage
      .from(bucket)
      .upload(path, file, {
        cacheControl: "3600",
        upsert: false,
        contentType: file.type,
      });
    if (uploadError) {
      throw new Error(
        getErrorMessage(uploadError, `Could not upload ${file.name}.`),
      );
    }
    return path;
  }

  async function handleSubmit(event) {
    event.preventDefault();
    if (submitting) return;

    setError("");
    const errors = validate();
    setFieldErrors(errors);
    if (Object.keys(errors).length > 0) {
      setError("Fix the highlighted fields and try again.");
      return;
    }

    const { supervisors: cleanSupervisors } = validateSupervisorEntries(
      [supervisor],
      {
        required: !values.is_seeking_teacher_supervisor,
        max: 1,
      },
    );

    const requestId = crypto.randomUUID();
    setSubmitting(true);
    const uploadedFiles = [];
    let logoPath = null;
    const uploadedAttachments = [];

    try {
      if (logoFile) {
        setUploadProgress("Uploading logo…");
        const preparedLogo = await prepareImageFileForUpload(logoFile);
        const ext =
          preparedLogo.type === "image/png"
            ? "png"
            : preparedLogo.type === "image/webp"
              ? "webp"
              : "jpg";
        logoPath = `reapplication-logos/${user.id}/${requestId}/${crypto.randomUUID()}.${ext}`;
        await uploadFile(CLUB_LOGOS_BUCKET, logoPath, preparedLogo);
        uploadedFiles.push({
          bucket: CLUB_LOGOS_BUCKET,
          path: logoPath,
        });
      }

      if (signedFormFile) {
        setUploadProgress("Uploading teacher supervisor form…");
        const preparedForm = await prepareImageFileForUpload(signedFormFile);
        const ext =
          preparedForm.type === "image/png"
            ? "png"
            : preparedForm.type === "image/webp"
              ? "webp"
              : "jpg";
        const path = `reapplications/${user.id}/${requestId}/${crypto.randomUUID()}.${ext}`;
        await uploadFile(CLUB_APPLICATION_DOCUMENTS_BUCKET, path, preparedForm);
        uploadedFiles.push({
          bucket: CLUB_APPLICATION_DOCUMENTS_BUCKET,
          path,
        });
        uploadedAttachments.push({
          storage_path: path,
          original_filename: preparedForm.name,
          mime_type: preparedForm.type,
          size_bytes: preparedForm.size,
        });
      }

      const description = values.description.trim();
      setUploadProgress("Submitting re-application…");
      await submitClubReapplication({
        requestId,
        clubId: values.club_id,
        shortDescription: deriveShortDescription(description),
        description,
        ownerNames: values.owner_names,
        publicEmail: values.public_email.trim().toLowerCase(),
        instagramHandle: values.instagram_handle.trim().replace(/^@+/, ""),
        memberApplicationUrl: values.member_application_url.trim() || null,
        execApplicationUrl: values.exec_application_url.trim() || null,
        meetingFrequency:
          values.meeting_days.length > 0 ? "Weekly" : "Other",
        meetingDays: values.meeting_days,
        meetingTimeDetails: values.meeting_time_details.trim() || null,
        meetingLocation: values.meeting_location.trim() || null,
        proposedLogoStoragePath: logoPath,
        isSeekingTeacherSupervisor: values.is_seeking_teacher_supervisor,
        declarationAccepted: true,
        supervisors: cleanSupervisors,
        attachments: uploadedAttachments,
      });

      setSuccessId(requestId);
    } catch (submitError) {
      await Promise.all(
        uploadedFiles.map(({ bucket, path }) =>
          supabase.storage.from(bucket).remove([path]),
        ),
      );
      setError(
        getErrorMessage(submitError, "Could not submit the re-application."),
      );
    } finally {
      setUploadProgress("");
      setSubmitting(false);
    }
  }

  if (successId) {
    return (
      <div className="page narrow-page">
        <div className="alert alert--success" role="status">
          <strong>Re-application submitted</strong>
          <p>
            Your Club Re-Application for {CLUB_APPLICATION_SCHOOL_YEAR} was
            received. Submission does not guarantee approval. Track status on{" "}
            <Link className="text-link" to="/my-requests/reapplications">
              My Requests
            </Link>
            . If approved, you become an OWNER of the existing club record.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="page narrow-page">
      <ClubApplyNotice accountEmail={applicantEmail} />

      {error ? <ErrorMessage>{error}</ErrorMessage> : null}

      <form className="stack" onSubmit={handleSubmit} noValidate>
        <div className="panel form-stack">
        <div
          className={`form-field${fieldErrors.club_id ? " form-field--error" : ""}`}
        >
          <label htmlFor="past-club-combobox">
            Past club
            <span className="required-mark"> *</span>
          </label>
          <div className="combobox" ref={comboboxRef}>
            <input
              id="past-club-combobox"
              className="input"
              role="combobox"
              aria-expanded={listOpen}
              aria-controls={listboxId}
              aria-autocomplete="list"
              aria-required="true"
              autoComplete="off"
              disabled={submitting}
              value={search}
              onChange={(event) => {
                setSearch(event.target.value);
                setListOpen(true);
                if (selectedClub) clearClub();
              }}
              onFocus={() => setListOpen(true)}
              onBlur={() => {
                window.setTimeout(() => setListOpen(false), 150);
              }}
              onKeyDown={(event) => {
                if (
                  !listOpen &&
                  (event.key === "ArrowDown" || event.key === "Enter")
                ) {
                  setListOpen(true);
                  return;
                }
                if (event.key === "ArrowDown") {
                  event.preventDefault();
                  setActiveIndex((i) =>
                    Math.min(i + 1, Math.max(options.length - 1, 0)),
                  );
                } else if (event.key === "ArrowUp") {
                  event.preventDefault();
                  setActiveIndex((i) => Math.max(i - 1, 0));
                } else if (
                  event.key === "Enter" &&
                  listOpen &&
                  options[activeIndex]
                ) {
                  event.preventDefault();
                  selectClub(options[activeIndex]);
                } else if (event.key === "Escape") {
                  setListOpen(false);
                }
              }}
              placeholder="Type a club name or alias…"
            />
            {listOpen ? (
              <ul id={listboxId} role="listbox" className="combobox__list">
                {optionsLoading ? (
                  <li className="combobox__empty">Searching…</li>
                ) : options.length === 0 ? (
                  <li className="combobox__empty">No eligible clubs match.</li>
                ) : (
                  options.map((club, index) => (
                    <li key={club.id}>
                      <button
                        type="button"
                        role="option"
                        aria-selected={selectedClub?.id === club.id}
                        className={
                          index === activeIndex
                            ? "combobox__option combobox__option--active"
                            : "combobox__option"
                        }
                        onMouseDown={(event) => event.preventDefault()}
                        onClick={() => selectClub(club)}
                      >
                        <span>{club.name}</span>
                        {club.aliases?.length ? (
                          <span className="muted">
                            {" "}
                            · aliases: {club.aliases.join(", ")}
                          </span>
                        ) : null}
                      </button>
                    </li>
                  ))
                )}
              </ul>
            ) : null}
          </div>
          {fieldErrors.club_id ? (
            <p className="form-error">{fieldErrors.club_id}</p>
          ) : null}
          {selectedClub ? (
            <div className="club-reapply-selected" aria-live="polite">
              <p>
                Selected <strong>{selectedLabel}</strong>
              </p>
              {historicalMeetingSchedule ? (
                <p className="muted">
                  Historical schedule:{" "}
                  {historicalMeetingSchedule}
                </p>
              ) : null}
              <button
                type="button"
                className="button button--secondary"
                onClick={clearClub}
                disabled={submitting}
              >
                Change club
              </button>
            </div>
          ) : null}
        </div>

        <TextArea
          id="description"
          name="description"
          label="Description"
          required
          rows={6}
          value={values.description}
          onChange={updateField}
          error={fieldErrors.description}
          disabled={submitting || !selectedClub}
          hint={
            selectedClub
              ? "Autofilled from the club record — edit as needed."
              : "Select a past club to autofill this description."
          }
        />

        <TextArea
          id="owner_names"
          name="owner_names"
          label="Names of all club owners"
          required
          rows={3}
          value={values.owner_names}
          onChange={updateField}
          error={fieldErrors.owner_names}
          disabled={submitting}
          hint="List the full name of every owner. A club may have at most three owners."
        />

        <TextInput
          id="public_email"
          name="public_email"
          type="email"
          label="Public club email"
          required
          value={values.public_email}
          onChange={updateField}
          error={fieldErrors.public_email}
          disabled={submitting}
        />

        <TextInput
          id="instagram_handle"
          name="instagram_handle"
          label="Instagram handle"
          required
          value={values.instagram_handle}
          onChange={updateField}
          error={fieldErrors.instagram_handle}
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

        <fieldset
          className={`form-field meeting-day-picker${
            fieldErrors.meeting_days ? " form-field--error" : ""
          }`}
        >
          <legend>
            Meeting days
            <span className="muted"> (optional)</span>
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
          {fieldErrors.meeting_days ? (
            <p className="form-error">{fieldErrors.meeting_days}</p>
          ) : null}
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
          error={fieldErrors.logo}
          disabled={submitting}
        />
        </div>

        <TeacherSupervisorSection
          name={supervisor.name}
          email={supervisor.email}
          onNameChange={(event) =>
            setSupervisor((current) => ({
              ...current,
              name: event.target.value,
            }))
          }
          onEmailChange={(event) =>
            setSupervisor((current) => ({
              ...current,
              email: event.target.value,
            }))
          }
          file={signedFormFile}
          onFileChange={setSignedFormFile}
          fileError={fieldErrors.signed_form}
          error={fieldErrors.supervisors}
          disabled={submitting}
          required={!values.is_seeking_teacher_supervisor}
          seeking={values.is_seeking_teacher_supervisor}
          onSeekingChange={updateField}
          showSeekingOption
        >
          <label className="checkbox">
            <input
              type="checkbox"
              name="declaration_accepted"
              checked={values.declaration_accepted}
              onChange={updateField}
              required
              disabled={submitting}
            />
            I confirm that I am authorized to submit this re-application on
            behalf of this club and that the information provided is accurate.
          </label>
          {fieldErrors.declaration_accepted ? (
            <p className="form-error">{fieldErrors.declaration_accepted}</p>
          ) : null}

          {uploadProgress ? <p role="status">{uploadProgress}</p> : null}

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
              "Submit re-application"
            )}
          </button>
        </TeacherSupervisorSection>
      </form>
    </div>
  );
}
