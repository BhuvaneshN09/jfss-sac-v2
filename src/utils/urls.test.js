import { describe, expect, it } from "vitest";
import {
  isAllowedApplicationUrl,
  isSafeExternalHref,
  isSafeHttpsUrl,
  safeExternalHref,
} from "./urls.js";

describe("isSafeHttpsUrl", () => {
  it("accepts ordinary https links", () => {
    expect(isSafeHttpsUrl("https://docs.google.com/forms/d/abc")).toBe(true);
  });

  it("rejects javascript, data, credentials, and private hosts", () => {
    expect(isSafeHttpsUrl("javascript:alert(1)")).toBe(false);
    expect(isSafeHttpsUrl("http://example.com")).toBe(false);
    expect(isSafeHttpsUrl("https://user:pass@example.com")).toBe(false);
    expect(isSafeHttpsUrl("https://127.0.0.1/secret")).toBe(false);
    expect(isSafeHttpsUrl("https://localhost/admin")).toBe(false);
  });
});

describe("safeExternalHref", () => {
  it("allows existing http links, same-origin paths, and blob URLs", () => {
    expect(isSafeExternalHref("http://example.com/form")).toBe(true);
    expect(isSafeExternalHref("/api/x/f/v1/object/sign/club-logos/a.png")).toBe(
      true,
    );
    expect(isSafeExternalHref("blob:https://www.johnfrasersac.com/uuid")).toBe(
      true,
    );
    expect(safeExternalHref("javascript:alert(1)")).toBeNull();
    expect(safeExternalHref("data:text/html,hi")).toBeNull();
  });
});

describe("isAllowedApplicationUrl", () => {
  it("grandfathers an unchanged http link and requires https for edits", () => {
    expect(
      isAllowedApplicationUrl("http://example.com/form", "http://example.com/form"),
    ).toBe(true);
    expect(
      isAllowedApplicationUrl("http://example.com/other", "http://example.com/form"),
    ).toBe(false);
    expect(isAllowedApplicationUrl("https://forms.gle/abc")).toBe(true);
  });
});
