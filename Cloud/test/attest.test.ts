import { describe, expect, it } from "vitest";
import { appleRoot, checkChallenge, issueChallenge, verifyAssertion, verifyAttestation } from "../src/attest";
import { base64Decode, utf8 } from "../src/bytes";
import { decodeCBOR } from "../src/cbor";
import { rawSignature, verifySignedBy } from "../src/der";
import { APP_ID, Phone, cbor, derSignature } from "./client";

describe("certificates", () => {
  it("reads Apple's App Attest root and checks its own signature", async () => {
    const root = appleRoot();
    expect(root.curve.name).toBe("P-384");
    expect(root.notAfter.getUTCFullYear()).toBe(2045);
    expect(await verifySignedBy(root, root)).toBe(true);
  });

  it("turns a DER signature back into r and s", () => {
    const raw = new Uint8Array(64).map((_, i) => (i === 0 || i === 32 ? 0x80 : i));
    expect(rawSignature(derSignature(raw), 32)).toEqual(raw);
  });
});

describe("cbor", () => {
  it("decodes maps of text and bytes", () => {
    const decoded = decodeCBOR(cbor({ fmt: "apple-appattest", authData: new Uint8Array([1, 2, 3]) })) as Map<string, unknown>;
    expect(decoded.get("fmt")).toBe("apple-appattest");
    expect(decoded.get("authData")).toEqual(new Uint8Array([1, 2, 3]));
  });

  it("rejects trailing bytes", () => {
    expect(() => decodeCBOR(new Uint8Array([0x01, 0x02]))).toThrow();
  });
});

describe("challenges", () => {
  it("accepts a fresh challenge and rejects old or altered ones", async () => {
    const now = Date.now();
    const challenge = await issueChallenge("secret", now);
    expect(await checkChallenge("secret", challenge, now + 1000)).toBe(true);
    expect(await checkChallenge("secret", challenge, now + 6 * 60 * 1000)).toBe(false);
    expect(await checkChallenge("other", challenge, now)).toBe(false);
    expect(await checkChallenge("secret", challenge.slice(0, -2) + "AA", now)).toBe(false);
  });
});

describe("attestation", () => {
  it("rejects objects that are not App Attest", async () => {
    const keyId = new Uint8Array(32);
    await expect(verifyAttestation(cbor({ fmt: "packed" }), keyId, "c", APP_ID, "development")).rejects.toThrow("wrong format");
    await expect(verifyAttestation(new Uint8Array([0xff]), keyId, "c", APP_ID, "development")).rejects.toThrow();
  });
});

describe("assertions", () => {
  it("accepts a signed body once and only for this app", async () => {
    const phone = await Phone.create(false);
    const body = utf8("{}");
    const assertion = base64Decode(await phone.assertion(body, 5))!;
    expect(await verifyAssertion(assertion, body, phone.point, APP_ID, 4)).toBe(5);
    await expect(verifyAssertion(assertion, body, phone.point, APP_ID, 5)).rejects.toThrow("counter");
    await expect(verifyAssertion(assertion, utf8("{ }"), phone.point, APP_ID, 0)).rejects.toThrow("signature");
    await expect(verifyAssertion(assertion, body, phone.point, "TEAM.other", 0)).rejects.toThrow("wrong app");
  });
});
