import { beforeEach, describe, expect, it, vi } from "vitest";

const authApi = vi.hoisted(() => ({
  signInWithIdToken: vi.fn(),
  signInWithOAuth: vi.fn(),
  signOut: vi.fn(),
  getUser: vi.fn(),
}));

vi.mock("../lib/supabase", () => ({
  supabase: {
    auth: authApi,
  },
}));

import { signInWithGoogle, signOut } from "./auth.js";

describe("auth service", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    authApi.signInWithIdToken.mockResolvedValue({
      data: { user: { id: "user-1" }, session: {} },
      error: null,
    });
    authApi.signOut.mockResolvedValue({ error: null });
  });

  it("exchanges a Google ID token with signInWithIdToken", async () => {
    await signInWithGoogle("google-id-token");

    expect(authApi.signInWithIdToken).toHaveBeenCalledWith({
      provider: "google",
      token: "google-id-token",
    });
    expect(authApi.signInWithOAuth).not.toHaveBeenCalled();
  });

  it("rejects a missing Google ID token without calling OAuth", async () => {
    await expect(signInWithGoogle()).rejects.toThrow(/ID token/i);
    expect(authApi.signInWithIdToken).not.toHaveBeenCalled();
    expect(authApi.signInWithOAuth).not.toHaveBeenCalled();
  });

  it("calls Supabase signOut and disables Google auto-select", async () => {
    const disableAutoSelect = vi.fn();
    globalThis.google = {
      accounts: {
        id: {
          disableAutoSelect,
        },
      },
    };

    await signOut();

    expect(disableAutoSelect).toHaveBeenCalled();
    expect(authApi.signOut).toHaveBeenCalled();
    delete globalThis.google;
  });
});
