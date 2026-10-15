import { describe, expect, it } from "vitest";
import { toOptimizedImageUrl } from "./optimizedImage";

const options = { enabled: true, origin: "https://sac.example" };

describe("toOptimizedImageUrl", () => {
  it("routes public storage images through the Vercel optimizer", () => {
    const src = "/api/x/f/v1/object/public/club-logos/club%20a/logo.png";

    expect(toOptimizedImageUrl(src, 256, options)).toBe(
      `/_vercel/image?url=${encodeURIComponent(src)}&w=256&q=75`,
    );
  });

  it("accepts absolute same-origin URLs", () => {
    expect(
      toOptimizedImageUrl(
        "https://sac.example/api/x/f/v1/object/authenticated/club-event-photos/a/b.jpg",
        1080,
        options,
      ),
    ).toContain("w=1080");
  });

  it("leaves unsupported sources alone", () => {
    expect(toOptimizedImageUrl("/images/SAC-LOGO.png", 256, options)).toBeNull();
    expect(
      toOptimizedImageUrl(
        "/api/x/f/v1/object/sign/club-logos/a.png?token=abc",
        256,
        options,
      ),
    ).toBeNull();
    expect(
      toOptimizedImageUrl(
        "https://other.example/api/x/f/v1/object/public/club-logos/a.png",
        256,
        options,
      ),
    ).toBeNull();
    expect(toOptimizedImageUrl("", 256, options)).toBeNull();
  });

  it("is disabled outside production builds", () => {
    expect(
      toOptimizedImageUrl("/api/x/f/v1/object/public/club-logos/a.png", 256, {
        ...options,
        enabled: false,
      }),
    ).toBeNull();
  });
});
