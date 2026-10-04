import { useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { useAuth } from "../../context/AuthContext";
import { ErrorMessage } from "../ui/ErrorMessage";
import { FilePicker } from "../ui/FilePicker";
import { LocalFilePreview } from "../ui/LocalFilePreview";
import { Spinner } from "../ui/Spinner";
import { TextArea } from "../ui/TextArea";
import { TextInput } from "../ui/TextInput";
import { FUNDING_REQUEST_FORM_URL } from "../../config/clubApplications";
import {
  deleteFundingSignature,
  submitClubFundingRequest,
  uploadFundingSignature,
  validateFundingSignatureFile,
} from "../../services/clubFunding";
import {
  calculateFundingTotal,
  countWords,
  validateFundingForm,
} from "../../utils/clubFunding";
import { getErrorMessage } from "../../utils/errors";

const INITIAL_ROW = {
  item: "",
  unitPrice: "",
  quantity: "1",
};

function formatCurrency(value) {
  return `$${Number(value || 0).toFixed(2)}`;
}

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

export function ClubFundingForm({
  club,
  canSubmit = true,
  canView = false,
  blockedMessage,
  onSubmitted,
}) {
  const { user } = useAuth();
  const [usageOfFunding, setUsageOfFunding] = useState("");
  const [costRows, setCostRows] = useState([INITIAL_ROW]);
  const [signedForm, setSignedForm] = useState(null);
  const [fieldErrors, setFieldErrors] = useState({});
  const [signatureError, setSignatureError] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [uploadProgress, setUploadProgress] = useState("");
  const [error, setError] = useState("");
  const [success, setSuccess] = useState(false);

  const total = useMemo(() => calculateFundingTotal(costRows), [costRows]);

  function updateCostRow(index, field, value) {
    setCostRows((current) =>
      current.map((row, rowIndex) =>
        rowIndex === index ? { ...row, [field]: value } : row,
      ),
    );
  }

  function addCostRow() {
    setCostRows((current) => [...current, { ...INITIAL_ROW }]);
  }

  function removeCostRow(index) {
    setCostRows((current) =>
      current.length === 1
        ? current
        : current.filter((_, rowIndex) => rowIndex !== index),
    );
  }

  function updateSignedForm(file) {
    const validationError = file ? validateFundingSignatureFile(file) : null;
    setSignatureError(validationError || "");
    if (validationError) return;
    setSignedForm(file);
  }

  async function handleSubmit(event) {
    event.preventDefault();
    if (submitting || !canSubmit || !club) return;

    setError("");
    const validation = validateFundingForm({
      usageOfFunding,
      costRows,
      signedForm,
    });
    setFieldErrors(validation.errors);
    if (!validation.isValid || signatureError) {
      setError("Please fix the highlighted fields before submitting.");
      return;
    }

    const requestId = crypto.randomUUID();
    let signedFormPath = null;
    setSubmitting(true);

    try {
      setUploadProgress("Uploading signed Teacher Approval Form…");
      signedFormPath = await uploadFundingSignature({
        userId: user.id,
        requestId,
        kind: "form",
        file: signedForm,
      });

      setUploadProgress("Submitting funding request…");
      await submitClubFundingRequest({
        requestId,
        clubId: club.id,
        usageOfFunding,
        costRows,
        supervisorSignaturePath: signedFormPath,
        applicantSignaturePath: signedFormPath,
      });

      setSuccess(true);
      setFieldErrors({});
      onSubmitted?.();
    } catch (submitError) {
      if (signedFormPath) await deleteFundingSignature(signedFormPath);
      setError(
        getErrorMessage(submitError, "Could not submit the funding request."),
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
          "Only active club owners can submit funding requests."}
      </p>
    );
  }

  if (success) {
    return (
      <div className="alert alert--success" role="status">
        <strong>Funding request submitted</strong>
        <p>
          Your funding request for {club.name} was submitted for review.
          Requests over $500.00 require Principal review.
        </p>
        <Link className="text-link" to="/my-requests/funding">
          View my funding requests
        </Link>
      </div>
    );
  }

  const fieldsDisabled = submitting || !canSubmit;

  return (
    <div className="stack">
      {!canSubmit ? (
        <p className="alert alert--warning" role="status">
          {blockedMessage ||
            "Only active club owners can submit funding requests."}
        </p>
      ) : null}
      {error ? <ErrorMessage>{error}</ErrorMessage> : null}

      <section className="panel funding-guidelines" aria-labelledby="funding-guidelines-title">
        <h3 id="funding-guidelines-title">
          BEFORE FILLING OUT THIS FORM KINDLY REFER TO: CLUBS: Funding Form
          GUIDELINES 📑
        </h3>
        <p>
          Upon approval, funds will be transferred into your club&apos;s
          account by our Budget Secretary.
        </p>
        <ul>
          <li>
            Applications over $500.00 must be reviewed by the Principal.
            Clubs can receive up to $500; approval is not guaranteed.
          </li>
          <li>
            Funding cannot be used for food or beverages intended for internal
            club use (e.g., meeting snacks).
          </li>
          <li>Funding cannot be used for club outfits or clothing.</li>
          <li>
            Funding is exclusively for school-related purposes. Students may
            not keep items purchased with these funds.
          </li>
          <li>Requested materials must align with our Eco Policy 🌷.</li>
        </ul>
      </section>

      <form className="stack" onSubmit={handleSubmit} noValidate>
        <section className="panel form-stack">
          <h3>Part 2: Usage Of Funding</h3>
          <TextArea
            id={`funding-usage-${club.id}`}
            label="How will the school/students benefit from the funding you are being provided with?"
            value={usageOfFunding}
            onChange={(event) => setUsageOfFunding(event.target.value)}
            error={fieldErrors.usageOfFunding}
            rows={7}
            required
            disabled={fieldsDisabled}
            hint={`${countWords(usageOfFunding)} / 300 words`}
          />
        </section>

        <section className="panel form-stack">
          <h3>Part 3: Cost Breakdown</h3>
          <p className="muted">
            Include product links in the item description when possible.
          </p>
          <div className="funding-cost-breakdown">
            {costRows.map((row, index) => {
              const rowError = fieldErrors.costRows?.[index] || {};
              return (
                <div className="funding-cost-row" key={`funding-row-${index}`}>
                  <TextInput
                    id={`funding-item-${club.id}-${index}`}
                    label={`Item ${index + 1}`}
                    value={row.item}
                    onChange={(event) =>
                      updateCostRow(index, "item", event.target.value)
                    }
                    error={rowError.item}
                    disabled={fieldsDisabled}
                    hint="Add a hyperlink if possible."
                  />
                  <TextInput
                    id={`funding-price-${club.id}-${index}`}
                    label="Value per piece ($)"
                    type="number"
                    min="0.01"
                    step="0.01"
                    value={row.unitPrice}
                    onChange={(event) =>
                      updateCostRow(index, "unitPrice", event.target.value)
                    }
                    error={rowError.unitPrice}
                    disabled={fieldsDisabled}
                  />
                  <TextInput
                    id={`funding-quantity-${club.id}-${index}`}
                    label="Quantity"
                    type="number"
                    min="1"
                    step="1"
                    value={row.quantity}
                    onChange={(event) =>
                      updateCostRow(index, "quantity", event.target.value)
                    }
                    error={rowError.quantity}
                    disabled={fieldsDisabled}
                  />
                  <button
                    type="button"
                    className="button button--secondary"
                    onClick={() => removeCostRow(index)}
                    disabled={fieldsDisabled || costRows.length === 1}
                  >
                    Remove
                  </button>
                </div>
              );
            })}
          </div>
          <div className="button-row">
            <button
              type="button"
              className="button button--secondary"
              onClick={addCostRow}
              disabled={fieldsDisabled}
            >
              Add row
            </button>
          </div>
          <div className="funding-total">
            <strong>Total</strong>
            <output>{formatCurrency(total)}</output>
          </div>
          {total > 500 ? (
            <p className="alert alert--warning">
              This request is over $500.00 and will require Principal review.
            </p>
          ) : null}
        </section>

        <section className="panel form-stack">
          <h3>Part 4: Staff Supervision &amp; Club Leader Acknowledgement</h3>
          <p className="muted teacher-supervisor-section__link-line">
            <a
              className="text-link"
              href={FUNDING_REQUEST_FORM_URL}
              target="_blank"
              rel="noopener noreferrer"
            >
              Open the Teacher Approval Form
            </a>
            {" — complete, sign, and upload the form below."}
          </p>
          <SignatureUpload
            id={`funding-signed-form-${club.id}`}
            label="Teacher Approval Form attachment"
            file={signedForm}
            error={signatureError || fieldErrors.signedForm}
            disabled={fieldsDisabled}
            onChange={updateSignedForm}
            onRemove={() => updateSignedForm(null)}
          />
        </section>

        {canSubmit ? (
          <div className="button-row">
            <button
              type="submit"
              className="button button--primary"
              disabled={fieldsDisabled}
            >
              {submitting ? <Spinner size="sm" label="Submitting" /> : null}
              {submitting ? uploadProgress || "Submitting…" : "Submit funding request"}
            </button>
          </div>
        ) : null}
      </form>
    </div>
  );
}
