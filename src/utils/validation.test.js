import { describe, expect, it } from "vitest";
import { validateOptionalHttpsUrl, validateOwnerNames } from "./validation.js";

describe("validateOwnerNames", () => {
  it("requires names on applications", () => {
    expect(validateOwnerNames("")).toBe("List the full name of every club owner.");
    expect(validateOwnerNames("Ada Lovelace")).toBeNull();
  });

  it("allows empty names when optional", () => {
    expect(validateOwnerNames("", { required: false })).toBeNull();
  });
});

describe("validateOptionalHttpsUrl", () => {
  it("requires https for new application links", () => {
    expect(validateOptionalHttpsUrl("")).toBeNull();
    expect(validateOptionalHttpsUrl("https://docs.google.com/forms/d/x")).toBeNull();
    expect(validateOptionalHttpsUrl("javascript:alert(1)")).toMatch(/https/);
    expect(validateOptionalHttpsUrl("http://example.com")).toMatch(/https/);
  });
});
