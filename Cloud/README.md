# SakuraCloud

The server side of Sakura: one Cloudflare Worker that asks TypeSafe's Jev whether the blocks Sakura's extractor is unsure of belong to an article. Every call is signed with App Attest, and each device has a Durable Object that holds its key, its assertion counter, and the tokens it spent in the last minute.

## Develop and deploy

```bash
npm install && npm test
npm run dev
npm run deploy:staging
npm run deploy:production
```

CI tests every push and deploys on published GitHub Releases: a prerelease goes to staging (`sakura-cloud-beta`), a full release to production (`sakura-cloud`), using a `CLOUDFLARE_API_TOKEN` secret scoped to Edit Cloudflare Workers.

The deploy jobs run in the `staging` and `production` GitHub Environments. Each environment holds the vars below as Variables and the secrets below as Secrets; CI exports both to `cf deploy`, which reads the vars in `cloudflare.config.ts` and uploads the secrets with `--secrets-file`.

## Settings

Plain vars are read from the environment by `cloudflare.config.ts` at deploy time, and are empty until set. An endpoint that needs a missing setting answers 503 rather than running unchecked.

| Var | Meaning |
| --- | --- |
| `APPLE_TEAM_ID` | The 10-character Apple team ID |
| `APP_BUNDLE_ID` | The app's bundle ID, `com.tsubuzaki.SakuraRSS` |
| `APP_ATTEST_ENVIRONMENT` | `development` for debug builds, `production` for TestFlight and the App Store |
| `TOKENS_PER_MINUTE` | Jev tokens a device may spend in any rolling 60 seconds, for example `20000` |

The limit is a default. A device whose Durable Object has a row in its `limits` table (`kind` is `tokens`, `per_minute` a whole number) uses that instead, so one device can be given more or fewer tokens without a deploy, and `0` shuts a device out. Each device's Durable Object is named by its App Attest key ID in base64url, and `limits` is its only SQL table: the key, the counter, and the spent tokens stay in its key-value storage.

For example, `INSERT OR REPLACE INTO limits (kind, per_minute) VALUES ('tokens', 200000)` gives a device 200,000 tokens a minute.

Outside CI, secrets are uploaded with `npm run deploy:staging -- --secrets-file secrets.json` (or `deploy:production`), or kept in a gitignored `.dev.vars` copied from `.dev.vars.example`:

| Secret | Where it comes from |
| --- | --- |
| `CHALLENGE_SECRET` | Any long random string; signs attestation challenges |
| `JEV_API_KEY` | A TypeSafe API key |
| `SKIP_APP_ATTEST` | `true` to accept unsigned requests to `localhost`, so a debug build in Simulator can call `npm run dev`. Ignored on any other host; never set it in a deploy |

`.dev.vars.example` also sets `TOKENS_PER_MINUTE`, since `npm run dev` has no deploy environment to read it from.

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

`blocks` holds up to 400 blocks of up to 4,000 characters, 60,000 in all, and `candidates` up to 120 distinct indexes into it. Only the candidates are asked about; the other blocks are context.

Before calling Jev the Worker sets aside an estimate of the tokens, then settles on the `usage` Jev reports. A call that fails upstream is given back. Every classify response carries `X-Sakura-Remaining`. A call that would go past the limit gets 429 with `Retry-After` in seconds, and one bigger than the whole limit gets 413.
