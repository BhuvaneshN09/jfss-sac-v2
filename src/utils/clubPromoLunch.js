export const PROMO_LUNCH_DEADLINE_TEXT = "October 1, 2026";

export const PROMO_LUNCH_DAYS = [
  { value: "OCTOBER_6", label: "October 6th" },
  { value: "OCTOBER_7", label: "October 7th" },
  { value: "BOTH", label: "Both" },
];

const PROMO_LUNCH_DAY_LABELS = {
  OCTOBER_6: "October 6th",
  OCTOBER_7: "October 7th",
  BOTH: "Both",
  OCTOBER_1: "October 6th",
  OCTOBER_2: "October 7th",
};

export function getPromoLunchDaysLabel(value) {
  return PROMO_LUNCH_DAY_LABELS[value] || value || "—";
}

export function validateClubPromoLunchForm(values) {
  const errors = {};
  const boothDays = String(values.boothDays || "").trim();
  const representatives = String(values.representatives || "").trim();

  if (!PROMO_LUNCH_DAYS.some((day) => day.value === boothDays)) {
    errors.boothDays = "Choose which days your club will run a booth.";
  }
  if (values.approvalEmailReceived !== true && values.approvalEmailReceived !== false) {
    errors.approvalEmailReceived = "Choose Yes or No.";
  }
  if (representatives.length < 2 || representatives.length > 5000) {
    errors.representatives =
      "Provide at least one representative name and student email.";
  }

  return {
    isValid: Object.keys(errors).length === 0,
    errors,
    data: {
      boothDays,
      approvalEmailReceived: values.approvalEmailReceived,
      representatives,
    },
  };
}
