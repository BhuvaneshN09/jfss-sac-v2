import { describe, expect, it } from "vitest";
import { prepareImageFileForUpload } from "./imageUpload.js";

function fileFromBytes(bytes, type, name = "upload.bin") {
  return new File([new Uint8Array(bytes)], name, { type });
}

describe("prepareImageFileForUpload", () => {
  it("leaves non-images unchanged", async () => {
    const file = fileFromBytes([0x25, 0x50, 0x44, 0x46], "application/pdf", "form.pdf");
    await expect(prepareImageFileForUpload(file)).resolves.toBe(file);
  });

  it("leaves small images unchanged", async () => {
    const file = fileFromBytes([0xff, 0xd8, 0xff, 0xe0], "image/jpeg", "photo.jpg");
    await expect(prepareImageFileForUpload(file)).resolves.toBe(file);
  });

  it("does not throw on large images when canvas compression is unavailable", async () => {
    const file = fileFromBytes(
      new Uint8Array(4 * 1024 * 1024),
      "image/png",
      "screenshot.png",
    );
    await expect(prepareImageFileForUpload(file)).resolves.toBe(file);
  });
});
