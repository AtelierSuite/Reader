import { env, runInDurableObject } from "cloudflare:test";
import { afterEach, describe, expect, it, vi } from "vitest";
import { base64Encode } from "../src/bytes";
import type { Env } from "../src/env";
import worker from "../src/index";
import { Phone, call } from "./client";

const article = {
  title: "The quiet return of the paper map",
  site: "example.com",
  blocks: [
    "Paper maps are selling again.",
    "Sign up for our newsletter",
    "Shops say younger hikers want something that works without a signal.",
    "Share this story",
  ],
  candidates: [1, 3],
};

function jev(nouls: { [key: string]: number }, status = 200, usage = { input_tokens: 300, output_tokens: 4 }) {
  return vi.spyOn(globalThis, "fetch").mockImplementation(async () => new Response(JSON.stringify({
    model: "jev-1.13.0",
    answers: Object.fromEntries(Object.entries(nouls).map(([key, noul]) => [key, { type: "noul", noul }])),
    usage,
  }), { status }));
}

afterEach(() => vi.restoreAllMocks());

describe("routing", () => {
  it("serves health, redirects home, and rejects the rest", async () => {
    expect((await call(new Request("https://sakura.test/health"))).status).toBe(200);
    const home = await call(new Request("https://sakura.test/"));
    expect(home.status).toBe(302);
    expect(home.headers.get("Location")).toBe("https://github.com/katagaki/SakuraCloud");
    expect((await call(new Request("https://sakura.test/v1/classify"))).status).toBe(405);
    expect((await call(new Request("https://sakura.test/v1/nothing", { method: "POST" }))).status).toBe(404);
  });

  it("says so when a setting is missing", async () => {
    const challenge = new Request("https://sakura.test/v1/challenge", { method: "POST" });
    expect((await call(challenge, { CHALLENGE_SECRET: "" })).status).toBe(503);
    const classify = () => new Request("https://sakura.test/v1/classify", { method: "POST", body: JSON.stringify(article) });
    expect((await call(classify(), { JEV_API_KEY: "" })).status).toBe(503);
    expect((await call(classify(), { TOKENS_PER_MINUTE: "" })).status).toBe(503);
  });

  it("hands out challenges", async () => {
    const response = await call(new Request("https://sakura.test/v1/challenge", { method: "POST" }));
    expect(((await response.json()) as { challenge: string }).challenge).toMatch(/^[A-Za-z0-9_-]{75}$/);
  });
});

describe("attest", () => {
  it("rejects a stale challenge before reading the attestation", async () => {
    const response = await call(new Request("https://sakura.test/v1/attest", {
      method: "POST",
      body: JSON.stringify({ keyId: base64Encode(new Uint8Array(32)), attestation: "AA==", challenge: "nope" }),
    }));
    expect(response.status).toBe(401);
  });
});

describe("signing", () => {
  it("refuses a request without a valid assertion and leaves no trace of unknown keys", async () => {
    const phone = await Phone.create();
    expect((await phone.post("/v1/classify", article, { assertion: "AAAA" })).status).toBe(401);
    const stranger = await Phone.create(false);
    expect((await stranger.post("/v1/classify", article)).status).toBe(401);
    await runInDurableObject(stranger.stub(), (_, state) => {
      expect(state.storage.sql.exec("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE '_cf_%'").toArray()).toEqual([]);
    });
  });

  it("refuses a replayed assertion", async () => {
    const phone = await Phone.create();
    jev({ b2: 0.1, b4: 0.05 });
    const body = new TextEncoder().encode(JSON.stringify(article));
    const assertion = await phone.assertion(body);
    expect((await phone.post("/v1/classify", article, { assertion })).status).toBe(200);
    expect((await phone.post("/v1/classify", article, { assertion })).status).toBe(401);
  });

  it("skips App Attest only on localhost when told to", async () => {
    jev({ b2: 0.1, b4: 0.05 });
    const post = (host: string) => worker.fetch(
      new Request(`http://${host}/v1/classify`, { method: "POST", body: JSON.stringify(article) }),
      { ...env, SKIP_APP_ATTEST: "true" } as Env,
    );
    expect((await post("localhost:8787")).status).toBe(200);
    expect((await post("sakura.test")).status).toBe(401);
  });
});

describe("classifying", () => {
  it("asks Jev one yes/no question per candidate and returns the answers in order", async () => {
    const phone = await Phone.create();
    const fetch = jev({ b4: 0.02, b2: 0.07 });
    const response = await phone.post("/v1/classify", article);
    expect(await response.json()).toEqual({ probabilities: [0.07, 0.02], remaining: 1696 });
    expect(response.headers.get("X-Sakura-Remaining")).toBe("1696");
    expect(fetch.mock.calls[0][0]).toBe("https://api.typesafe.ai/v1/systemone");
    const sent = JSON.parse(fetch.mock.calls[0][1]!.body as string);
    expect(sent.model).toBe("jev-latest");
    expect(sent.state.blocks).toEqual({ b1: article.blocks[0], b2: article.blocks[1], b3: article.blocks[2], b4: article.blocks[3] });
    expect(Object.keys(sent.questions)).toEqual(["b2", "b4"]);
    expect(sent.questions.b2.type).toBe("noul");
    expect(sent.questions.b2.instructions).toContain("`blocks.b2`");
  });

  it("gives back the tokens of a failed call", async () => {
    const phone = await Phone.create();
    jev({}, 500);
    expect((await phone.post("/v1/classify", article)).status).toBe(502);
    vi.restoreAllMocks();
    jev({ b2: 0.5 });
    expect((await phone.post("/v1/classify", article)).status).toBe(502);
    expect(await (await phone.post("/v1/limits", {})).json()).toEqual({ tokens: { limit: 2000, used: 0, remaining: 2000 } });
  });

  it("rejects bodies it will not pass on", async () => {
    const phone = await Phone.create();
    expect((await phone.post("/v1/classify", { ...article, blocks: [] })).status).toBe(400);
    expect((await phone.post("/v1/classify", { ...article, candidates: [9] })).status).toBe(400);
    expect((await phone.post("/v1/classify", { ...article, candidates: [1, 1] })).status).toBe(400);
    expect((await phone.post("/v1/classify", { ...article, blocks: ["x".repeat(4001)] })).status).toBe(400);
  });
});

describe("limits", () => {
  it("stops at the per-minute token limit and says when to retry", async () => {
    const phone = await Phone.create();
    jev({ b2: 0.1, b4: 0.1 }, 200, { input_tokens: 900, output_tokens: 0 });
    expect((await phone.post("/v1/classify", article)).status).toBe(200);
    expect((await phone.post("/v1/classify", article)).status).toBe(200);
    const over = await phone.post("/v1/classify", article);
    expect(over.status).toBe(429);
    expect(Number(over.headers.get("Retry-After"))).toBeGreaterThan(0);
    expect(Number(over.headers.get("Retry-After"))).toBeLessThanOrEqual(60);
    expect(over.headers.get("X-Sakura-Remaining")).toBe("200");
  });

  it("rolls the window over a minute", async () => {
    const phone = await Phone.create();
    const stub = phone.stub();
    const start = Date.now();
    expect((await stub.reserve(1500, 2000, start)).allowed).toBe(true);
    expect((await stub.reserve(400, 2000, start + 30_000)).allowed).toBe(true);
    const blocked = await stub.reserve(400, 2000, start + 40_000);
    expect(blocked).toMatchObject({ allowed: false, remaining: 100, retryAfter: 20 });
    expect((await stub.reserve(400, 2000, start + 60_001)).allowed).toBe(true);
    expect(await stub.allowance(2000, start + 90_001)).toEqual({ limit: 2000, used: 400, remaining: 1600 });
  });

  it("refuses a request that could never fit in a minute", async () => {
    const phone = await Phone.create();
    const response = await phone.post("/v1/classify", { ...article, blocks: [...article.blocks, "x".repeat(3999), "x".repeat(3999)] });
    expect(response.status).toBe(413);
  });

  it("uses a limit set in the device's limits table over the default", async () => {
    const phone = await Phone.create();
    await runInDurableObject(phone.stub(), (_, state) => {
      state.storage.sql.exec("INSERT INTO limits (kind, per_minute) VALUES ('tokens', 50000)");
    });
    expect(await (await phone.post("/v1/limits", {})).json()).toEqual({ tokens: { limit: 50000, used: 0, remaining: 50000 } });
    await runInDurableObject(phone.stub(), (_, state) => {
      state.storage.sql.exec("UPDATE limits SET per_minute = 0 WHERE kind = 'tokens'");
    });
    expect((await phone.post("/v1/classify", article)).status).toBe(413);
  });

  it("ignores a limit that is not a whole number", async () => {
    const phone = await Phone.create();
    await runInDurableObject(phone.stub(), (_, state) => {
      state.storage.sql.exec("INSERT INTO limits (kind, per_minute) VALUES ('tokens', 'lots')");
    });
    expect(await (await phone.post("/v1/limits", {})).json()).toMatchObject({ tokens: { limit: 2000 } });
  });

  it("keeps each device's tokens apart", async () => {
    const phone = await Phone.create();
    const other = await Phone.create();
    jev({ b2: 0.1, b4: 0.1 }, 200, { input_tokens: 1900, output_tokens: 0 });
    expect((await phone.post("/v1/classify", article)).status).toBe(200);
    expect((await other.post("/v1/classify", article)).status).toBe(200);
  });
});
