import { afterEach, beforeEach, describe, expect, it } from "vitest";
import {
  consumeAuthReturnTo,
  normalizeAuthReturnPath,
  rememberAuthReturnTo,
} from "./authRedirect.js";

function mockSessionStorage() {
  const store = new Map();
  globalThis.sessionStorage = {
    getItem(key) {
      return store.has(key) ? store.get(key) : null;
    },
    setItem(key, value) {
      store.set(key, String(value));
    },
    removeItem(key) {
      store.delete(key);
    },
    clear() {
      store.clear();
    },
  };
}

describe("normalizeAuthReturnPath", () => {
  it("keeps in-app paths", () => {
    expect(normalizeAuthReturnPath("/clubs/chess")).toBe("/clubs/chess");
    expect(normalizeAuthReturnPath("/exec-dashboard?tab=1")).toBe(
      "/exec-dashboard?tab=1",
    );
  });

  it("rejects open redirects and the login page", () => {
    expect(normalizeAuthReturnPath("//evil.example")).toBeNull();
    expect(normalizeAuthReturnPath("/\\evil.example")).toBeNull();
    expect(normalizeAuthReturnPath("https://evil.example")).toBeNull();
    expect(normalizeAuthReturnPath("/login?next=/clubs")).toBeNull();
  });
});

describe("consumeAuthReturnTo", () => {
  beforeEach(() => {
    mockSessionStorage();
  });

  afterEach(() => {
    sessionStorage.clear();
  });

  it("re-validates stored paths before returning them", () => {
    sessionStorage.setItem("jfss_sac_auth_return_to", "//evil.example");
    expect(consumeAuthReturnTo("/clubs")).toBe("/clubs");
  });

  it("returns a remembered safe path", () => {
    rememberAuthReturnTo("/clubs/chess");
    expect(consumeAuthReturnTo(null)).toBe("/clubs/chess");
  });
});
