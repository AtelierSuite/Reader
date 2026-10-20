import { base64Decode, base64UrlEncode, concat, equal, sha256, utf8 } from "./bytes";
import { type CBOR, decodeCBOR, field } from "./cbor";
import { type Certificate, child, parseCertificate, parseDER, rawSignature, verifySignedBy } from "./der";

const APPLE_ROOT = `MIICITCCAaegAwIBAgIQC/O+DvHN0uD7jG5yH2IXmDAKBggqhkjOPQQDAzBSMSYw
JAYDVQQDDB1BcHBsZSBBcHAgQXR0ZXN0YXRpb24gUm9vdCBDQTETMBEGA1UECgwK
QXBwbGUgSW5jLjETMBEGA1UECAwKQ2FsaWZvcm5pYTAeFw0yMDAzMTgxODMyNTNa
Fw00NTAzMTUwMDAwMDBaMFIxJjAkBgNVBAMMHUFwcGxlIEFwcCBBdHRlc3RhdGlv
biBSb290IENBMRMwEQYDVQQKDApBcHBsZSBJbmMuMRMwEQYDVQQIDApDYWxpZm9y
bmlhMHYwEAYHKoZIzj0CAQYFK4EEACIDYgAERTHhmLW07ATaFQIEVwTtT4dyctdh
NbJhFs/Ii2FdCgAHGbpphY3+d8qjuDngIN3WVhQUBHAoMeQ/cLiP1sOUtgjqK9au
Yen1mMEvRq9Sk3Jm5X8U62H+xTD3FE9TgS41o0IwQDAPBgNVHRMBAf8EBTADAQH/
MB0GA1UdDgQWBBSskRBTM72+aEH/pwyp5frq5eWKoTAOBgNVHQ8BAf8EBAMCAQYw
CgYIKoZIzj0EAwMDaAAwZQIwQgFGnByvsiVbpTKwSga0kP0e8EeDS4+sQmTvb7vn
53O5+FRXgeLhpJ06ysC5PrOyAjEAp5U4xDgEgllF7En3VcE3iexZZtKeYnpqtijV
oyFraWVIyd/dganmrduC1bmTBGwD`;

const NONCE_EXTENSION = "1.2.840.113635.100.8.2";
const CHALLENGE_TTL_MS = 5 * 60 * 1000;
const AAGUIDS: { [environment: string]: Uint8Array } = {
  development: utf8("appattestdevelop"),
  production: concat(utf8("appattest"), new Uint8Array(7)),
};

export function appleRoot(): Certificate {
  return parseCertificate(base64Decode(APPLE_ROOT.replace(/\s/g, ""))!);
}

async function hmac(secret: string, data: Uint8Array): Promise<Uint8Array> {
  const key = await crypto.subtle.importKey("raw", utf8(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return new Uint8Array(await crypto.subtle.sign("HMAC", key, data));
}

export async function issueChallenge(secret: string, now = Date.now()): Promise<string> {
  const payload = new Uint8Array(24);
  crypto.getRandomValues(payload.subarray(0, 16));
  new DataView(payload.buffer).setFloat64(16, now);
  return base64UrlEncode(concat(payload, await hmac(secret, payload)));
}

export async function checkChallenge(secret: string, challenge: string, now = Date.now()): Promise<boolean> {
  const bytes = base64Decode(challenge);
  if (!bytes || bytes.length !== 56) return false;
  const payload = bytes.subarray(0, 24);
  if (!equal(bytes.subarray(24), await hmac(secret, payload))) return false;
  const issued = new DataView(payload.buffer, payload.byteOffset).getFloat64(16);
  return issued <= now && now - issued <= CHALLENGE_TTL_MS;
}

function bytesField(value: CBOR, key: string): Uint8Array {
  const found = field(value, key);
  if (!(found instanceof Uint8Array)) throw new Error(`missing ${key}`);
  return found;
}

export async function verifyAttestation(
  attestation: Uint8Array,
  keyId: Uint8Array,
  challenge: string,
  appId: string,
  environment: string,
  now = new Date(),
): Promise<Uint8Array> {
  const object = decodeCBOR(attestation);
  if (field(object, "fmt") !== "apple-appattest") throw new Error("wrong format");
  const statement = field(object, "attStmt") ?? null;
  const chain = field(statement, "x5c");
  if (!Array.isArray(chain) || chain.length < 2 || !chain.every((cert) => cert instanceof Uint8Array)) {
    throw new Error("missing certificate chain");
  }
  const [leaf, intermediate] = (chain as Uint8Array[]).map(parseCertificate);
  const root = appleRoot();
  for (const cert of [leaf, intermediate, root]) {
    if (now < cert.notBefore || now > cert.notAfter) throw new Error("certificate out of date");
  }
  if (!(await verifySignedBy(intermediate, root)) || !(await verifySignedBy(leaf, intermediate))) {
    throw new Error("certificate chain does not verify");
  }

  const authData = bytesField(object, "authData");
  const nonce = await sha256(concat(authData, await sha256(utf8(challenge))));
  const extension = leaf.extensions.get(NONCE_EXTENSION);
  if (!extension) throw new Error("missing nonce");
  const tagged = child(parseDER(extension), 0, 0xa1);
  if (!equal(child(tagged, 0, 0x04).value, nonce)) throw new Error("nonce mismatch");
  if (!equal(await sha256(leaf.point), keyId)) throw new Error("key id mismatch");

  if (authData.length < 55) throw new Error("auth data truncated");
  if (!equal(authData.subarray(0, 32), await sha256(utf8(appId)))) throw new Error("wrong app");
  if (new DataView(authData.buffer, authData.byteOffset).getUint32(33) !== 0) throw new Error("counter not zero");
  const aaguid = AAGUIDS[environment];
  if (!aaguid || !equal(authData.subarray(37, 53), aaguid)) throw new Error("wrong environment");
  const idLength = new DataView(authData.buffer, authData.byteOffset).getUint16(53);
  if (!equal(authData.subarray(55, 55 + idLength), keyId)) throw new Error("credential id mismatch");
  return leaf.point;
}

export async function verifyAssertion(
  assertion: Uint8Array,
  clientData: Uint8Array,
  point: Uint8Array,
  appId: string,
  lastCounter: number,
): Promise<number> {
  const object = decodeCBOR(assertion);
  const signature = bytesField(object, "signature");
  const authData = bytesField(object, "authenticatorData");
  if (authData.length < 37) throw new Error("auth data truncated");
  if (!equal(authData.subarray(0, 32), await sha256(utf8(appId)))) throw new Error("wrong app");
  const counter = new DataView(authData.buffer, authData.byteOffset).getUint32(33);
  if (counter <= lastCounter) throw new Error("counter did not increase");
  const nonce = await sha256(concat(authData, await sha256(clientData)));
  const key = await crypto.subtle.importKey("raw", point, { name: "ECDSA", namedCurve: "P-256" }, false, ["verify"]);
  const valid = await crypto.subtle.verify({ name: "ECDSA", hash: "SHA-256" }, key, rawSignature(signature, 32), nonce);
  if (!valid) throw new Error("bad signature");
  return counter;
}
