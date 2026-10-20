import { describe, expect, it } from "vitest";
import { base64Encode, utf8 } from "../src/bytes";
import { Phone, call } from "./client";

const MAX_BYTES = 262144;

function streamed(path: string, chunks: Uint8Array[], headers: HeadersInit = {}) {
  let reads = 0;
  let cancelled = false;
  const body = new ReadableStream<Uint8Array>({
    pull(controller) {
      if (reads < chunks.length) controller.enqueue(chunks[reads++]);
      else controller.close();
    },
    cancel() { cancelled = true; },
  }, { highWaterMark: 0 });
  const request = new Request(`https://service.test${path}`, { method: "POST", body, headers });
  return { request, reads: () => reads, cancelled: () => cancelled };
}

describe("request body limits", () => {
  it.each(["/v1/attest", "/v1/classify", "/v1/limits"])("rejects oversized bodies at %s before authentication or upstream work", async (path) => {
    const input = streamed(path, [new Uint8Array(MAX_BYTES + 1), new Uint8Array(1)]);
    expect((await call(input.request)).status).toBe(413);
    expect(input.reads()).toBe(1);
    expect(input.cancelled()).toBe(true);
  });

  it("counts bytes across chunks without trusting Content-Length", async () => {
    const input = streamed("/v1/limits", [new Uint8Array(MAX_BYTES), new Uint8Array(1), new Uint8Array(1)], { "Content-Length": "1" });
    expect((await call(input.request)).status).toBe(413);
    expect(input.reads()).toBe(2);
    expect(input.cancelled()).toBe(true);
  });

  it("preserves signed bytes and accepts the exact size limit", async () => {
    const phone = await Phone.create();
    const bytes = utf8(JSON.stringify({ padding: "a".repeat(MAX_BYTES - 14) }));
    expect(bytes.length).toBe(MAX_BYTES);
    const input = streamed("/v1/limits", [bytes.subarray(0, 7), bytes.subarray(7)], {
      "X-Sakura-Key-Id": base64Encode(phone.keyId),
      "X-Sakura-Assertion": await phone.assertion(bytes),
    });
    expect((await call(input.request)).status).toBe(200);
    expect(input.cancelled()).toBe(false);
  });

  it("accepts empty signed request bodies", async () => {
    const phone = await Phone.create();
    const request = new Request("https://service.test/v1/limits", {
      method: "POST",
      headers: {
        "X-Sakura-Key-Id": base64Encode(phone.keyId),
        "X-Sakura-Assertion": await phone.assertion(new Uint8Array()),
      },
    });
    expect((await call(request)).status).toBe(200);
  });
});
