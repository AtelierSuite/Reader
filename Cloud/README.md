# SakuraCloud

The server side of Sakura: one Cloudflare Worker that asks Workers AI's Clef what role each block Sakura's extractor is unsure of plays on an article page. Every call is signed with App Attest, and each device has a Durable Object that holds its key, its assertion counter, and the tokens it spent in the last minute.

## Develop and deploy

```bash
npm install && npm test
npm run dev
npm run deploy
```

Cloudflare Workers Builds deploys the `sakura-cloud` Worker from the `Cloud` folder of this repository on every push to `main` that touches `Cloud/`, after `npm run typecheck` and `npm test` pass. Other branches only run the checks.

## Settings

Plain vars are set in `cloudflare.config.ts`. An endpoint that needs a missing setting answers 503 rather than running unchecked.

| Var | Meaning |
| --- | --- |
| `APPLE_TEAM_ID` | The 10-character Apple team ID, `YYM4Z6MU8F` |
| `APP_BUNDLE_ID` | The app's bundle ID, `com.tsubuzaki.SakuraRSS` |
| `APP_ATTEST_ENVIRONMENT` | `development` under `npm run dev`, `production` when deployed |
| `TOKENS_PER_MINUTE` | Clef tokens a device may spend in any rolling 60 seconds, `20000` |

The limit is a default. A device whose Durable Object has a row in its `limits` table (`kind` is `tokens`, `per_minute` a whole number) uses that instead, so one device can be given more or fewer tokens without a deploy, and `0` shuts a device out. Each device's Durable Object is named by its App Attest key ID in base64url, and `limits` is its only SQL table: the key, the counter, and the spent tokens stay in its key-value storage.

For example, `INSERT OR REPLACE INTO limits (kind, per_minute) VALUES ('tokens', 200000)` gives a device 200,000 tokens a minute.

Secrets are set on the Worker in the Cloudflare dashboard, or with `npm run deploy -- --secrets-file secrets.json`, and deploys keep them. For `npm run dev` they are kept in a gitignored `.dev.vars` copied from `.dev.vars.example`:

| Secret | Where it comes from |
| --- | --- |
| `CHALLENGE_SECRET` | Any long random string; signs attestation challenges |
| `SKIP_APP_ATTEST` | `true` to accept unsigned requests to `localhost`, so a debug build in Simulator can call `npm run dev`. Ignored on any other host; never set it in a deploy |

Clef runs through the Worker's `AI` binding, which needs no key, but even `npm run dev` calls Workers AI on the logged-in account and is billed.

## Endpoints

Everything is `POST` except `/health`. The signed endpoints take two headers:

| Header | Value |
| --- | --- |
| `X-Sakura-Key-Id` | The App Attest key ID, base64 |
| `X-Sakura-Assertion` | `DCAppAttestService.generateAssertion` over the SHA-256 of the exact request body, base64 |

| Path | Signed | What it does |
| --- | --- | --- |
| `/v1/challenge` | No | Returns `{ "challenge" }`, good for five minutes |
| `/v1/attest` | No | Takes `{ keyId, attestation, challenge }`. The attestation's client data hash is the SHA-256 of the challenge string's UTF-8 bytes. Registers the key once |
| `/v1/classify` | Yes | Takes `{ title, site, blocks: [string], candidates: [index] }` and returns `{ probabilities, remaining }`: for each candidate, in order, the probability that the block is part of the article |
| `/v1/limits` | Yes | Returns `{ tokens: { limit, used, remaining } }` for the last 60 seconds, without spending anything |

`title` and `site` are optional and not sent to Clef. `blocks` holds up to 400 blocks of up to 4,000 characters, 60,000 in all, counted as Swift's `String.count` counts them, and `candidates` up to 120 distinct indexes into it. Each candidate goes to `@cf/cloudflare/clef` in its own call, six at a time, as `{ "text": block }` with one `choice` question, `role`, over eight roles: `content`, `lead_in`, `heading`, and `caption`, which are part of the article, and `credit`, `promo`, `navigation`, and `meta`, which are not. A candidate's probability is the sum of the first four, rounded to four places. Clef sees only the candidates.

Before calling Clef the Worker sets aside an estimate of the tokens, then settles on the `usage` Clef reports. When a Clef call fails the request answers 502, and only the tokens of the calls Clef answered are kept. Every classify response carries `X-Sakura-Remaining`. A call that would go past the limit gets 429 with `Retry-After` in seconds, and one bigger than the whole limit gets 413.
