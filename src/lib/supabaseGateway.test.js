import { describe, expect, it } from "vitest";
import { AUTH_SESSION_BROWSER_PATH } from "./supabaseAuthProxy.js";
import {
  isAllowedUpstreamGatewayPath,
  rewriteBrowserGatewayUrl,
  resolveIncomingGatewayUrl,
  toUpstreamGatewayUrl,
} from "./supabaseGateway.js";

const ORIGIN = "https://www.johnfrasersac.com";

describe("supabaseGateway", () => {
  it("aliases REST, Auth, and Storage onto bland /api/x paths", () => {
    expect(
      rewriteBrowserGatewayUrl(
        `${ORIGIN}/api/x/rest/v1/profiles?select=id`,
        ORIGIN,
      ),
    ).toBe(`${ORIGIN}/api/x/q/v1/profiles?select=id`);

    expect(
      rewriteBrowserGatewayUrl(`${ORIGIN}/api/x/auth/v1/user`, ORIGIN),
    ).toBe(`${ORIGIN}/api/x/a/v1/user`);

    expect(
      rewriteBrowserGatewayUrl(
        `${ORIGIN}/api/x/storage/v1/object/public/club-logos/a.png`,
        ORIGIN,
      ),
    ).toBe(`${ORIGIN}/api/x/f/v1/object/public/club-logos/a.png`);
  });

  it("still sends token grants to /api/sf/go", () => {
    expect(
      rewriteBrowserGatewayUrl(
        `${ORIGIN}/api/x/auth/v1/token?grant_type=refresh_token`,
        ORIGIN,
      ),
    ).toBe(`${ORIGIN}${AUTH_SESSION_BROWSER_PATH}?g=2`);
  });

  it("maps bland proxy paths back to GoTrue/PostgREST/Storage", () => {
    expect(toUpstreamGatewayUrl(`${ORIGIN}/api/x/q/v1/profiles?select=id`)).toBe(
      "https://nvpxsuafdcrobnackhnd.supabase.co/rest/v1/profiles?select=id",
    );
    expect(toUpstreamGatewayUrl(`${ORIGIN}/api/x/a/v1/user`)).toBe(
      "https://nvpxsuafdcrobnackhnd.supabase.co/auth/v1/user",
    );
    expect(
      toUpstreamGatewayUrl(
        `${ORIGIN}/api/x/f/v1/object/public/club-logos/a.png`,
      ),
    ).toBe(
      "https://nvpxsuafdcrobnackhnd.supabase.co/storage/v1/object/public/club-logos/a.png",
    );
    expect(
      toUpstreamGatewayUrl(
        resolveIncomingGatewayUrl(
          `${ORIGIN}/api/gateway?_px=q/v1/profiles&select=id`,
        ),
      ),
    ).toBe(
      "https://nvpxsuafdcrobnackhnd.supabase.co/rest/v1/profiles?select=id",
    );
    expect(
      toUpstreamGatewayUrl(
        `${ORIGIN}/api/x/q/v1/profiles?select=id&_px=q/v1/profiles`,
      ),
    ).toBe("https://nvpxsuafdcrobnackhnd.supabase.co/rest/v1/profiles?select=id");
    expect(
      toUpstreamGatewayUrl(
        `${ORIGIN}/api/x/q/v1/user_system_roles?select=role&_px=q/v1/user_system_roles`,
      ),
    ).toBe(
      "https://nvpxsuafdcrobnackhnd.supabase.co/rest/v1/user_system_roles?select=role",
    );
    expect(
      toUpstreamGatewayUrl(
        resolveIncomingGatewayUrl(
          `${ORIGIN}/api/x/q/v1/profiles?select=id&q/v1/profiles`,
        ),
      ),
    ).toBe("https://nvpxsuafdcrobnackhnd.supabase.co/rest/v1/profiles?select=id");
  });

  it("allows REST, Auth, and Storage and blocks admin/functions/realtime", () => {
    expect(isAllowedUpstreamGatewayPath("/rest/v1/profiles")).toBe(true);
    expect(isAllowedUpstreamGatewayPath("/auth/v1/user")).toBe(true);
    expect(isAllowedUpstreamGatewayPath("/storage/v1/object/sign/x")).toBe(true);
    expect(isAllowedUpstreamGatewayPath("/auth/v1/admin/users")).toBe(false);
    expect(isAllowedUpstreamGatewayPath("/functions/v1/secret")).toBe(false);
    expect(isAllowedUpstreamGatewayPath("/realtime/v1/websocket")).toBe(false);
    expect(isAllowedUpstreamGatewayPath("/rest/v1/%2e%2e/auth/v1/admin")).toBe(
      false,
    );
  });
});
