import { describe, expect, it } from "vitest";
import {
  AUTH_SESSION_BROWSER_PATH,
  isAllowedAuthGrant,
  rewriteBrowserAuthTokenUrl,
  toUpstreamAuthTokenPath,
  toUpstreamAuthTokenUrl,
} from "./supabaseAuthProxy.js";

const ORIGIN = "https://www.johnfrasersac.com";

describe("supabaseAuthProxy", () => {
  it("rewrites GoTrue token URLs onto /api/sf/go with a short grant code", () => {
    expect(
      rewriteBrowserAuthTokenUrl(
        `${ORIGIN}/api/x/auth/v1/token?grant_type=refresh_token`,
        ORIGIN,
      ),
    ).toBe(`${ORIGIN}${AUTH_SESSION_BROWSER_PATH}?g=2`);

    expect(
      rewriteBrowserAuthTokenUrl(
        `${ORIGIN}/api/x/auth/v1/token?grant_type=id_token`,
        ORIGIN,
      ),
    ).toBe(`${ORIGIN}${AUTH_SESSION_BROWSER_PATH}?g=1`);
  });

  it("leaves REST and Storage URLs unchanged", () => {
    const rest = `${ORIGIN}/api/x/rest/v1/profiles?select=id`;
    const storage = `${ORIGIN}/api/x/storage/v1/object/public/club-logos/a.png`;
    expect(rewriteBrowserAuthTokenUrl(rest, ORIGIN)).toBe(rest);
    expect(rewriteBrowserAuthTokenUrl(storage, ORIGIN)).toBe(storage);
  });

  it("maps the browser proxy path back to GoTrue /auth/v1/token", () => {
    expect(toUpstreamAuthTokenPath("/api/sf/go?g=2")).toBe(
      "/auth/v1/token?grant_type=refresh_token",
    );
    expect(
      toUpstreamAuthTokenUrl(`${ORIGIN}/api/sf/go?g=1`),
    ).toBe(
      "https://nvpxsuafdcrobnackhnd.supabase.co/auth/v1/token?grant_type=id_token",
    );
  });

  it("allows Google ID-token and refresh grants only", () => {
    expect(isAllowedAuthGrant("id_token")).toBe(true);
    expect(isAllowedAuthGrant("refresh_token")).toBe(true);
    expect(isAllowedAuthGrant("password")).toBe(false);
    expect(isAllowedAuthGrant("pkce")).toBe(false);
  });
});
