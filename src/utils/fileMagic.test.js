import { describe, expect, it } from "vitest";
import { fileMatchesDeclaredType } from "./fileMagic.js";

function fileFromBytes(bytes, type, name = "upload.bin") {
  return new File([new Uint8Array(bytes)], name, { type });
}

describe("fileMatchesDeclaredType", () => {
  it("accepts a JPEG header declared as JPEG", async () => {
    const file = fileFromBytes([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10], "image/jpeg");
    await expect(fileMatchesDeclaredType(file, ["image/jpeg"])).resolves.toBe(
      true,
    );
  });

  it("rejects HTML labeled as JPEG", async () => {
    const html = Array.from(new TextEncoder().encode("<!doctype html>"));
    const file = fileFromBytes(html, "image/jpeg");
    await expect(fileMatchesDeclaredType(file, ["image/jpeg"])).resolves.toBe(
      false,
    );
  });
});
