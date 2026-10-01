import { checkChallenge, issueChallenge, verifyAttestation } from "./attest";
import { base64Decode, base64UrlEncode } from "./bytes";
import { askJev, estimateTokens, parseClassification } from "./classify";
import { Device } from "./device";
import { type Env, appId, limit } from "./env";

export { Device };

const HOMEPAGE = "https://github.com/katagaki/SakuraCloud";
const MAX_BODY_BYTES = 256 * 1024;

function json(body: unknown, status = 200, headers: HeadersInit = {}): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json", ...headers } });
}

function failure(status: number, message: string, headers: HeadersInit = {}): Response {
  return json({ error: message }, status, headers);
}

async function body(request: Request): Promise<Uint8Array | null> {
  const bytes = new Uint8Array(await request.arrayBuffer());
  return bytes.length <= MAX_BODY_BYTES ? bytes : null;
}

function parse(bytes: Uint8Array): unknown {
  try {
    return JSON.parse(new TextDecoder().decode(bytes));
  } catch {
    return undefined;
  }
}

function device(env: Env, keyId: Uint8Array): DurableObjectStub<Device> {
  return env.DEVICE.get(env.DEVICE.idFromName(base64UrlEncode(keyId)));
}

function local(request: Request, env: Env): boolean {
  return env.SKIP_APP_ATTEST === "true" && ["localhost", "127.0.0.1"].includes(new URL(request.url).hostname);
}

async function authenticated(request: Request, env: Env, bytes: Uint8Array): Promise<DurableObjectStub<Device> | Response> {
  if (local(request, env)) return env.DEVICE.get(env.DEVICE.idFromName("local"));
  const app = appId(env);
  if (!app) return failure(503, "not configured");
  const keyId = base64Decode(request.headers.get("X-Sakura-Key-Id") ?? "");
  const assertion = base64Decode(request.headers.get("X-Sakura-Assertion") ?? "");
  if (!keyId || keyId.length !== 32 || !assertion || assertion.length === 0) return failure(401, "missing assertion");
  const stub = device(env, keyId);
  if (!(await stub.authenticate(assertion, bytes, app))) return failure(401, "assertion rejected");
  return stub;
}

async function challenge(env: Env): Promise<Response> {
  if (!env.CHALLENGE_SECRET) return failure(503, "not configured");
  return json({ challenge: await issueChallenge(env.CHALLENGE_SECRET) });
}

async function attest(request: Request, env: Env): Promise<Response> {
  const app = appId(env);
  if (!app || !env.CHALLENGE_SECRET || !env.APP_ATTEST_ENVIRONMENT) return failure(503, "not configured");
  const bytes = await body(request);
  const input = bytes ? parse(bytes) : undefined;
  const { keyId, attestation, challenge } = (input ?? {}) as { [key: string]: unknown };
  if (typeof keyId !== "string" || typeof attestation !== "string" || typeof challenge !== "string") {
    return failure(400, "keyId, attestation, and challenge are required");
  }
  if (!(await checkChallenge(env.CHALLENGE_SECRET, challenge))) return failure(401, "challenge expired or invalid");
  const id = base64Decode(keyId);
  const object = base64Decode(attestation);
  if (!id || id.length !== 32 || !object) return failure(400, "keyId and attestation must be base64");
  let point: Uint8Array;
  try {
    point = await verifyAttestation(object, id, challenge, app, env.APP_ATTEST_ENVIRONMENT);
  } catch (error) {
    return failure(401, `attestation rejected: ${(error as Error).message}`);
  }
  if (!(await device(env, id).register(point))) return failure(409, "key already registered");
  return json({ registered: true });
}

async function classify(request: Request, env: Env): Promise<Response> {
  const most = limit(env.TOKENS_PER_MINUTE);
  if (most === null || !env.JEV_API_KEY) return failure(503, "not configured");
  const key = env.JEV_API_KEY;
  const bytes = await body(request);
  if (!bytes) return failure(413, "request too large");
  const classification = parseClassification(parse(bytes));
  if (typeof classification === "string") return failure(400, classification);
  const stub = await authenticated(request, env, bytes);
  if (stub instanceof Response) return stub;
  const reservation = await stub.reserve(estimateTokens(classification), most);
  const remaining = { "X-Sakura-Remaining": String(reservation.remaining) };
  if (!reservation.allowed || !reservation.id) {
    if (reservation.retryAfter === undefined) return failure(413, "request is larger than the per-minute token limit", remaining);
    return failure(429, "token limit reached", { ...remaining, "Retry-After": String(reservation.retryAfter) });
  }
  try {
    const verdict = await askJev(classification, key);
    const left = await stub.settle(reservation.id, verdict.tokens, most);
    return json({ probabilities: verdict.probabilities, remaining: left }, 200, { "X-Sakura-Remaining": String(left) });
  } catch (error) {
    await stub.release(reservation.id);
    return failure(502, (error as Error).message);
  }
}

async function limits(request: Request, env: Env): Promise<Response> {
  const most = limit(env.TOKENS_PER_MINUTE);
  if (most === null) return failure(503, "not configured");
  const bytes = await body(request);
  if (!bytes) return failure(413, "request too large");
  const stub = await authenticated(request, env, bytes);
  if (stub instanceof Response) return stub;
  return json({ tokens: await stub.allowance(most) });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname === "/health") return new Response("ok");
    if (url.pathname === "/" && url.search === "") return Response.redirect(HOMEPAGE, 302);
    if (request.method !== "POST") return failure(405, "method not allowed");
    switch (url.pathname) {
      case "/v1/challenge":
        return challenge(env);
      case "/v1/attest":
        return attest(request, env);
      case "/v1/classify":
        return classify(request, env);
      case "/v1/limits":
        return limits(request, env);
      default:
        return failure(404, "not found");
    }
  },
};
