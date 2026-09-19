import { describe, expect, it } from "vitest";
import {
  getPublicCdnCacheControl,
  hasUserAccessToken,
  withPublicCdnCache,
} from "./publicGatewayCache.js";

function requestWithAuth(value) {
  return { headers: new Headers(value ? { authorization: value } : {}) };
}

describe("publicGatewayCache", () => {
  it("treats dummy publishable keys as anonymous", () => {
    expect(hasUserAccessToken(requestWithAuth("Bearer public"))).toBe(false);
    expect(
      hasUserAccessToken(requestWithAuth("Bearer sb_publishable_test")),
    ).toBe(false);
    expect(hasUserAccessToken(requestWithAuth(""))).toBe(false);
  });

  it("detects a user JWT", () => {
    expect(
      hasUserAccessToken(requestWithAuth("Bearer aaa.bbb.ccc")),
    ).toBe(true);
  });

  it("caches public storage and shared REST reads even when a JWT is present", () => {
    expect(
      getPublicCdnCacheControl({
        method: "GET",
        pathname: "/storage/v1/object/public/athlete-photos/a.jpg",
        status: 200,
        hasUserToken: true,
      }),
    ).toMatch(/s-maxage=86400/);

    expect(
      getPublicCdnCacheControl({
        method: "GET",
        pathname: "/rest/v1/rpc/get_public_club_events",
        status: 200,
        hasUserToken: true,
      }),
    ).toMatch(/s-maxage=120/);

    expect(
      getPublicCdnCacheControl({
        method: "GET",
        pathname: "/rest/v1/athletes_of_the_month",
        status: 200,
        hasUserToken: true,
      }),
    ).toMatch(/s-maxage=300/);

    expect(
      getPublicCdnCacheControl({
        method: "GET",
        pathname: "/rest/v1/public_active_clubs",
        status: 200,
        hasUserToken: true,
      }),
    ).toMatch(/s-maxage=120/);
  });

  it("does not cache personalized REST or private storage when a JWT is present", () => {
    expect(
      getPublicCdnCacheControl({
        method: "GET",
        pathname: "/rest/v1/announcements",
        status: 200,
        hasUserToken: true,
      }),
    ).toBeNull();

    expect(
      getPublicCdnCacheControl({
        method: "GET",
        pathname: "/rest/v1/clubs",
        status: 200,
        hasUserToken: true,
      }),
    ).toBeNull();

    expect(
      getPublicCdnCacheControl({
        method: "GET",
        pathname: "/storage/v1/object/authenticated/club-logos/a.png",
        status: 200,
        hasUserToken: true,
      }),
    ).toBeNull();

    expect(
      getPublicCdnCacheControl({
        method: "GET",
        pathname: "/rest/v1/rpc/get_effective_school_day",
        status: 200,
        hasUserToken: true,
      }),
    ).toBeNull();
  });

  it("caches anonymous public-read private-bucket objects and school day", () => {
    expect(
      getPublicCdnCacheControl({
        method: "GET",
        pathname: "/storage/v1/object/authenticated/club-logos/club-profile-logos/a.png",
        status: 200,
        hasUserToken: false,
      }),
    ).toMatch(/s-maxage=86400/);

    expect(
      getPublicCdnCacheControl({
        method: "GET",
        pathname: "/rest/v1/rpc/get_effective_school_day",
        status: 200,
        hasUserToken: false,
      }),
    ).toMatch(/s-maxage=60/);
  });

  it("never caches mutations, errors, private documents, or adjacent REST collections", () => {
    expect(
      getPublicCdnCacheControl({
        method: "POST",
        pathname: "/rest/v1/public_active_clubs",
        status: 200,
        hasUserToken: false,
      }),
    ).toBeNull();

    expect(
      getPublicCdnCacheControl({
        method: "GET",
        pathname: "/rest/v1/public_active_clubs",
        status: 403,
        hasUserToken: false,
      }),
    ).toBeNull();

    expect(
      getPublicCdnCacheControl({
        method: "GET",
        pathname: "/storage/v1/object/authenticated/club-application-documents/form.png",
        status: 200,
        hasUserToken: false,
      }),
    ).toBeNull();

    expect(
      getPublicCdnCacheControl({
        method: "GET",
        pathname: "/rest/v1/club_memberships",
        status: 200,
        hasUserToken: false,
      }),
    ).toBeNull();

    expect(
      getPublicCdnCacheControl({
        method: "GET",
        pathname: "/auth/v1/user",
        status: 200,
        hasUserToken: false,
      }),
    ).toBeNull();
  });

  it("does not cache Range requests", () => {
    expect(
      getPublicCdnCacheControl({
        method: "GET",
        pathname: "/storage/v1/object/public/athlete-photos/a.jpg",
        status: 200,
        hasUserToken: false,
        hasRange: true,
      }),
    ).toBeNull();
  });

  it("sets CDN cache headers without exposing Set-Cookie", async () => {
    const cached = withPublicCdnCache(
      new Response("ok", {
        headers: { "set-cookie": "secret=1", "content-type": "text/plain" },
      }),
      "public, max-age=0, s-maxage=120, stale-while-revalidate=300",
    );

    expect(cached.headers.get("CDN-Cache-Control")).toMatch(/s-maxage=120/);
    expect(cached.headers.get("Vercel-CDN-Cache-Control")).toMatch(/s-maxage=120/);
    expect(cached.headers.get("set-cookie")).toBeNull();
    expect(await cached.text()).toBe("ok");
  });
});
