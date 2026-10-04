import { describe, expect, it } from "vitest";
import {
  getBrowserSupabaseUrl,
  SUPABASE_AUTH_STORAGE_KEY,
  SUPABASE_PROXY_PATH,
} from "./supabaseConfig.js";

describe("same-origin API client configuration", () => {
  it("builds the browser base URL from the current origin plus /api/x", () => {
    expect(getBrowserSupabaseUrl("https://www.johnfrasersac.com")).toBe(
      "https://www.johnfrasersac.com/api/x",
    );
    expect(getBrowserSupabaseUrl("https://preview-deployment.vercel.app")).toBe(
      "https://preview-deployment.vercel.app/api/x",
    );
    expect(getBrowserSupabaseUrl("http://localhost:5173")).toBe(
      "http://localhost:5173/api/x",
    );
    expect(SUPABASE_PROXY_PATH).toBe("/api/x");
  });

  it("uses a session key that does not include the project ref", () => {
    expect(SUPABASE_AUTH_STORAGE_KEY).toBe("jfss-sac-session");
  });
});
