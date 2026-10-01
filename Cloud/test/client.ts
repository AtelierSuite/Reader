import { env } from "cloudflare:test";
import { base64Encode, concat, sha256, utf8 } from "../src/bytes";
import type { Env } from "../src/env";
import worker from "../src/index";

export const APP_ID = "TEAMTEAM99.com.tsubuzaki.SakuraRSS";

function head(major: number, length: number): Uint8Array {
  if (length < 24) return new Uint8Array([(major << 5) | length]);
  if (length < 256) return new Uint8Array([(major << 5) | 24, length]);
  return new Uint8Array([(major << 5) | 25, length >> 8, length & 255]);
}

export function cbor(value: { [key: string]: Uint8Array | string }): Uint8Array {
  const parts: Uint8Array[] = [head(5, Object.keys(value).length)];
  for (const [key, item] of Object.entries(value)) {
    parts.push(head(3, utf8(key).length), utf8(key));
    const bytes = typeof item === "string" ? utf8(item) : item;
    parts.push(head(typeof item === "string" ? 3 : 2, bytes.length), bytes);
  }
  return concat(...parts);
}

function integer(bytes: Uint8Array): Uint8Array {
  let start = 0;
  while (start < bytes.length - 1 && bytes[start] === 0) start++;
  const trimmed = bytes.subarray(start);
  const padded = trimmed[0] & 0x80 ? concat(new Uint8Array([0]), trimmed) : trimmed;
  return concat(new Uint8Array([0x02, padded.length]), padded);
}

export function derSignature(raw: Uint8Array): Uint8Array {
  const body = concat(integer(raw.subarray(0, raw.length / 2)), integer(raw.subarray(raw.length / 2)));
  return concat(new Uint8Array([0x30, body.length]), body);
}

export class Phone {
  counter = 0;
  private constructor(readonly keyId: Uint8Array, readonly point: Uint8Array, private readonly key: CryptoKey) {}

  static async create(register = true): Promise<Phone> {
    const pair = (await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"])) as CryptoKeyPair;
    const point = new Uint8Array((await crypto.subtle.exportKey("raw", pair.publicKey)) as ArrayBuffer);
    const phone = new Phone(await sha256(point), point, pair.privateKey);
    if (register) await phone.stub().register(point);
    return phone;
  }

  stub() {
    let raw = "";
    for (const byte of this.keyId) raw += String.fromCharCode(byte);
    const name = btoa(raw).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
    return env.DEVICE.get(env.DEVICE.idFromName(name));
  }

  async assertion(body: Uint8Array, counter = ++this.counter, appId = APP_ID): Promise<string> {
    const count = new Uint8Array(4);
    new DataView(count.buffer).setUint32(0, counter);
    const authenticatorData = concat(await sha256(utf8(appId)), new Uint8Array([0x40]), count);
    const nonce = await sha256(concat(authenticatorData, await sha256(body)));
    const raw = new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, this.key, nonce));
    return base64Encode(cbor({ signature: derSignature(raw), authenticatorData }));
  }

  async post(path: string, payload: unknown, options: { assertion?: string } = {}): Promise<Response> {
    const body = utf8(JSON.stringify(payload));
    const request = new Request(`https://sakura.test${path}`, {
      method: "POST",
      body,
      headers: {
        "Content-Type": "application/json",
        "X-Sakura-Key-Id": base64Encode(this.keyId),
        "X-Sakura-Assertion": options.assertion ?? (await this.assertion(body)),
      },
    });
    return call(request);
  }
}

export function call(request: Request, overrides: Partial<Env> = {}): Promise<Response> {
  return worker.fetch(request, { ...env, ...overrides } as Env);
}
