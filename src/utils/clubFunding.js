export const FUNDING_SIGNATURE_MAX_BYTES = 10 * 1024 * 1024;
export const FUNDING_SIGNATURE_ALLOWED_TYPES = [
  "image/jpeg",
  "image/png",
  "image/webp",
  "application/pdf",
];

export function countWords(value) {
  const text = String(value || "").trim();
  return text ? text.split(/\s+/).length : 0;
}

function toCents(value) {
  const amount = Number(value);
  return Number.isFinite(amount) ? Math.round(amount * 100) : 0;
}

export function getFundingRowTotal(row) {
  const priceCents = toCents(row?.unitPrice ?? row?.unit_price);
  const quantity = Number(row?.quantity);
  if (!Number.isInteger(quantity) || quantity < 0) return 0;
  return (priceCents * quantity) / 100;
}

export function calculateFundingTotal(rows = []) {
  const cents = rows.reduce((total, row) => {
    const rowTotal = getFundingRowTotal(row);
    return total + Math.round(rowTotal * 100);
  }, 0);

  return cents / 100;
}

export function normalizeFundingRows(rows = []) {
  return rows.map((row) => ({
    item: String(row?.item || "").trim(),
    unit_price: Number(row?.unitPrice ?? row?.unit_price),
    quantity: Number(row?.quantity),
  }));
}

export function validateFundingRows(rows = []) {
  const rowErrors = rows.map((row) => {
    const errors = {};
    const item = String(row?.item || "").trim();
    const unitPrice = Number(row?.unitPrice ?? row?.unit_price);
    const quantity = Number(row?.quantity);

    if (!item) {
      errors.item = "Describe the item and include a product link if possible.";
    }
    if (!Number.isFinite(unitPrice) || unitPrice <= 0) {
      errors.unitPrice = "Enter a value greater than $0.";
    }
    if (!Number.isInteger(quantity) || quantity < 1) {
      errors.quantity = "Enter a whole-number quantity of at least 1.";
    }

    return errors;
  });

  return {
    rowErrors,
    hasErrors:
      rows.length === 0 ||
      rowErrors.some((errors) => Object.keys(errors).length > 0),
  };
}

export function validateFundingForm({
  usageOfFunding,
  costRows,
  signedForm,
}) {
  const errors = {};
  const usage = String(usageOfFunding || "").trim();
  const wordCount = countWords(usage);

  if (!usage) {
    errors.usageOfFunding = "Explain how the school or students will benefit.";
  } else if (wordCount > 300) {
    errors.usageOfFunding = `Keep this response to 300 words or fewer (${wordCount} entered).`;
  }

  const rowValidation = validateFundingRows(costRows);
  if (rowValidation.hasErrors) {
    errors.costRows = rowValidation.rowErrors;
  }

  if (!signedForm) {
    errors.signedForm = "Attach the signed Teacher Approval Form.";
  }

  return {
    errors,
    total: calculateFundingTotal(costRows),
    requiresPrincipalReview: calculateFundingTotal(costRows) > 500,
    isValid: Object.keys(errors).length === 0,
  };
}
