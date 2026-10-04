import { describe, expect, it } from "vitest";
import { getErrorMessage } from "./errors.js";

describe("getErrorMessage", () => {
  it("explains 502 and empty {} auth errors instead of showing raw JSON", () => {
    expect(getErrorMessage({ message: "{}", status: 502 })).toMatch(
      /school Wi-Fi/i,
    );
    expect(getErrorMessage({ message: "{}", status: 0 })).toMatch(/school Wi-Fi/i);
    expect(getErrorMessage({ message: "Bad Gateway", status: 502 })).toMatch(
      /school Wi-Fi/i,
    );
  });

  it("keeps existing business-rule messages", () => {
    expect(getErrorMessage("duplicate key value violates unique constraint")).toMatch(
      /already in use/i,
    );
  });

  it("maps a blocking re-application unique constraint to a progress message", () => {
    expect(
      getErrorMessage(
        'duplicate key value violates unique constraint "club_reapp_v2_blocking_club_year_uidx"',
      ),
    ).toBe("A re-application for this club is already in progress.");
  });

  it("asks signed-out users to sign in instead of showing a permission warning", () => {
    expect(getErrorMessage("permission denied for table profiles")).toBe(
      "Sign in to see this.",
    );
    expect(
      getErrorMessage({ message: "new row violates row-level security", code: "42501" }),
    ).toBe("Sign in to see this.");
  });

  it("keeps archived and unofficial-club request blocks visible", () => {
    expect(getErrorMessage("Archived clubs cannot submit requests")).toBe(
      "Archived clubs cannot submit requests",
    );
    expect(
      getErrorMessage(
        "Requests are available only after the club is officially active. Current status: PENDING_SUPERVISOR",
      ),
    ).toMatch(/officially active/i);
  });

  it("maps existing club names to a clear application error", () => {
    expect(getErrorMessage("A club with that name already exists")).toBe(
      "A club with that name already exists.",
    );
  });

  it("maps Vercel 413 upload failures to a file-size message", () => {
    expect(getErrorMessage("HTTP 413 error")).toMatch(/too large to upload/i);
    expect(getErrorMessage({ message: "Payload Too Large", status: 413 })).toMatch(
      /smaller JPEG/i,
    );
    expect(
      getErrorMessage({
        message: "FUNCTION_PAYLOAD_TOO_LARGE",
        statusCode: 413,
      }),
    ).toMatch(/too large to upload/i);
  });

  it("hides Vercel NOT_FOUND page text", () => {
    expect(
      getErrorMessage({ message: "The page could not be found NOT_FOUND iad1::abc", status: 404 }),
    ).toMatch(/reach the API/i);
  });

  it("maps mutation rate-limit errors to a wait message", () => {
    expect(
      getErrorMessage("Too many submissions. Please wait and try again."),
    ).toMatch(/wait and try again/i);
  });
});
