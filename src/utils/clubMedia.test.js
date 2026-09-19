import { describe, expect, it } from "vitest";
import { resolveClubLogoUrl } from "./clubMedia.js";

const ORIGIN = "https://www.johnfrasersac.com";

describe("resolveClubLogoUrl", () => {
  it("builds a stable authenticated storage URL for a storage path", () => {
    expect(
      resolveClubLogoUrl(
        "club-profile-logos/user/club/logo.png",
        ORIGIN,
      ),
    ).toBe(
      `/api/x/f/v1/object/authenticated/club-logos/club-profile-logos/user/club/logo.png`,
    );
  });

  it("rewrites an absolute public Storage URL onto the same-origin proxy", () => {
    expect(
      resolveClubLogoUrl(
        "https://nvpxsuafdcrobnackhnd.supabase.co/storage/v1/object/public/club-logos/example.png",
        ORIGIN,
      ),
    ).toBe(`${ORIGIN}/api/x/f/v1/object/public/club-logos/example.png`);
  });

  it("rejects unsafe values", () => {
    expect(resolveClubLogoUrl("javascript:alert(1)", ORIGIN)).toBeNull();
    expect(resolveClubLogoUrl("http://example.com/logo.png", ORIGIN)).toBeNull();
    expect(resolveClubLogoUrl("data:image/png;base64,abc", ORIGIN)).toBeNull();
    expect(resolveClubLogoUrl("", ORIGIN)).toBeNull();
    expect(resolveClubLogoUrl(null, ORIGIN)).toBeNull();
  });
});
