import { describe, expect, it } from "vitest";
import {
  toAuthenticatedStorageObjectUrl,
  toSameOriginSupabaseUrl,
} from "./proxiedSupabaseUrl.js";

const ORIGIN = "https://www.johnfrasersac.com";
const PROJECT_ORIGIN = "https://nvpxsuafdcrobnackhnd.supabase.co";

describe("toSameOriginSupabaseUrl", () => {
  it("rewrites a legacy absolute public Storage URL onto the bland proxy path", () => {
    expect(
      toSameOriginSupabaseUrl(
        `${PROJECT_ORIGIN}/storage/v1/object/public/club-logos/example.png`,
        ORIGIN,
      ),
    ).toBe(`${ORIGIN}/api/x/f/v1/object/public/club-logos/example.png`);
  });

  it("preserves signed-URL query parameters", () => {
    const input = `${PROJECT_ORIGIN}/storage/v1/object/sign/club-application-documents/form.png?token=abc.def&download=form.png`;
    expect(toSameOriginSupabaseUrl(input, ORIGIN)).toBe(
      `${ORIGIN}/api/x/f/v1/object/sign/club-application-documents/form.png?token=abc.def&download=form.png`,
    );
  });

  it("migrates the old /supabase proxy path", () => {
    expect(
      toSameOriginSupabaseUrl(
        `${ORIGIN}/supabase/storage/v1/object/public/club-logos/example.png`,
        ORIGIN,
      ),
    ).toBe(`${ORIGIN}/api/x/f/v1/object/public/club-logos/example.png`);
  });

  it("leaves non-Supabase URLs unchanged", () => {
    const google =
      "https://lh3.googleusercontent.com/a/example-avatar";
    expect(toSameOriginSupabaseUrl(google, ORIGIN)).toBe(google);
    expect(toSameOriginSupabaseUrl("https://instagram.com/fraser_sac", ORIGIN)).toBe(
      "https://instagram.com/fraser_sac",
    );
  });

  it("does not rewrite a different Supabase project host", () => {
    const other =
      "https://pvmmozukpihjpyekxwhl.supabase.co/storage/v1/object/public/club-logos/old.png";
    expect(toSameOriginSupabaseUrl(other, ORIGIN)).toBe(other);
  });

  it("leaves an already aliased proxy URL unchanged", () => {
    const proxied = `${ORIGIN}/api/x/f/v1/object/public/club-logos/example.png`;
    expect(toSameOriginSupabaseUrl(proxied, ORIGIN)).toBe(proxied);
  });

  it("does not crash on null, undefined, or invalid values", () => {
    expect(toSameOriginSupabaseUrl(null, ORIGIN)).toBeNull();
    expect(toSameOriginSupabaseUrl(undefined, ORIGIN)).toBeUndefined();
    expect(toSameOriginSupabaseUrl("", ORIGIN)).toBe("");
    expect(toSameOriginSupabaseUrl("club-logos/example.png", ORIGIN)).toBe(
      "club-logos/example.png",
    );
    expect(toSameOriginSupabaseUrl("not a url", ORIGIN)).toBe("not a url");
    expect(toSameOriginSupabaseUrl(42, ORIGIN)).toBe(42);
  });
});

describe("toAuthenticatedStorageObjectUrl", () => {
  it("builds a bland same-origin authenticated object path", () => {
    expect(
      toAuthenticatedStorageObjectUrl(
        "club-logos",
        "club-profile-logos/user/club/logo.png",
      ),
    ).toBe(
      "/api/x/f/v1/object/authenticated/club-logos/club-profile-logos/user/club/logo.png",
    );
  });

  it("encodes path segments and rejects empty paths", () => {
    expect(toAuthenticatedStorageObjectUrl("club-logos", "a b/c.png")).toBe(
      "/api/x/f/v1/object/authenticated/club-logos/a%20b/c.png",
    );
    expect(toAuthenticatedStorageObjectUrl("club-logos", "")).toBeNull();
    expect(toAuthenticatedStorageObjectUrl("", "a.png")).toBeNull();
  });
});
