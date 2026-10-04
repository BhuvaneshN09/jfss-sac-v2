import { getTorontoTodayYmd } from "./torontoDate";

export function validateClubEventForm(values) {
  const errors = {};
  const eventName = String(values.eventName || "").trim();
  const eventDescription = String(values.eventDescription || "").trim();
  const eventStartDate = String(values.eventStartDate || "").trim();
  const eventEndDate = String(values.eventEndDate || "").trim();
  const requestedMaterials = String(values.requestedMaterials || "").trim();
  const isCharitableEvent = Boolean(values.isCharitableEvent);

  if (eventName.length < 2 || eventName.length > 160) {
    errors.eventName = "Event name must be between 2 and 160 characters.";
  }
  if (eventDescription.length < 10 || eventDescription.length > 10000) {
    errors.eventDescription =
      "Description must be between 10 and 10,000 characters.";
  }
  if (!eventStartDate) {
    errors.eventStartDate = "Choose a start date.";
  } else if (eventStartDate < getTorontoTodayYmd()) {
    errors.eventStartDate = "The event start date cannot be in the past.";
  }
  if (!eventEndDate) {
    errors.eventEndDate = "Choose an end date.";
  } else if (eventStartDate && eventEndDate < eventStartDate) {
    errors.eventEndDate = "The end date cannot be before the start date.";
  }
  if (requestedMaterials.length < 2 || requestedMaterials.length > 5000) {
    errors.requestedMaterials =
      "Requested materials must be between 2 and 5,000 characters.";
  }
  if (!values.signedForm) {
    errors.signedForm = "Attach the signed Event Approval Form.";
  }

  return {
    isValid: Object.keys(errors).length === 0,
    errors,
    data: {
      eventName,
      eventDescription,
      eventStartDate,
      eventEndDate,
      requestedMaterials,
      isCharitableEvent,
    },
  };
}
