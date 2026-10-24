# Access Control & Cost Containment

This is the source-of-truth document for how the API decides who may call it and how it stops any
caller, approved or not, from running up processing time or cost. Read this before onboarding a
new consumer, before tuning any limit, and before responding to a cost or abuse alert.

**Governing constraint:** this project is meant to cost $0 (see
[`docs/adr/0001-free-per-consumer-secrets.md`](adr/0001-free-per-consumer-secrets.md) for why the
auth model is what it is). The API runs on the Cloudflare Workers Free plan, which never bills.
The converter runs inside AWS Lambda's always-free allowance. Every control described here is
free.

---

## 1. Overview & goals

Two goals, in this order:

1. **Only approved sources can call the API.** Software the owner hasn't explicitly approved
   must not be able to get a useful response from it.
2. **No caller, approved or not, can run up processing time or cost.** Even a legitimate,
   approved consumer that misbehaves (bug, retry storm, leaked credential) must be bounded.

A hard constraint shapes the design: **the whole thing must cost $0**. That ruled out the
strongest design considered (Amazon Cognito machine-to-machine authentication, which has no free
tier) in favor of a weaker but free one: per-consumer static secrets checked inside the API. The
API is now the Cloudflare Worker `nzimages-api`, on a plan that cannot bill, so abuse of the API
costs availability, not money. The converter is the only part that could cost money if abused,
and it stays on AWS behind a kill switch, an alarm and a budget. The trade-offs are listed in §3 and in the
ADR.

---

## 2. Architecture

```
Website (https://nzimages.iolab.nz, Worker nzimages-web)

  Browser  ──same-origin /api/*──▶  nzimages-web Worker  ──service binding (RPC)──▶  nzimages-api
  (no secret)                       (no secret)                                      ImageApi entrypoint,
                                                                                     same account only

Any other consumer (public HTTP API, https://nzimages-api.iolab.nz)

  Browser / app  ──HTTPS──▶  Consumer's OWN backend  ──secret header──▶  GET /image, GET /collections
  (no secret)                (holds THIS consumer's                      checked against
                              random secret)                             API_CLIENT_SECRETS,
                                                                         401 before any work

Converter images: the browser loads the HMAC-signed converter URL directly (gated independently,
see §10).
```

There are **three separate request paths**, and they're gated differently:

- **Image metadata over HTTP** (`GET /image`, `GET /collections` on
  `https://nzimages-api.iolab.nz`). Returns JSON describing a randomly chosen image (title,
  description, thumbnail and large-image URLs). Gated by the per-consumer secret (§4). This is the
  path any consumer other than the website uses, from its own backend.
- **Image metadata over RPC** (`ImageApi.image()`, `ImageApi.collections()`). The website's path.
  A service binding only connects Workers on the same Cloudflare account, so it has no secret
  check. The website's browser code calls the website Worker's own `/api/image` and
  `/api/collections`, same-origin.
- **Image bytes**, for collections that need format conversion (JP2/TIFF to JPEG). The metadata
  contains a URL pointing at `Jp2ConverterFunction`'s public Function URL. That URL is HMAC-signed
  by the API Worker (unrelated to `API_CLIENT_SECRETS`) and is loaded directly by the end user's
  browser, not proxied. See §10.

The API has no `workers.dev` hostname (`workers_dev: false`). Its only public address is the
custom domain.

**Why the browser or app never holds a secret:** anything shipped to a browser page
(view-source) or a mobile app binary (decompilation) is effectively public. A static secret
embedded in either is not secret. So every HTTP consumer must run *some* backend or edge
component, even a few lines in a serverless function, that holds its `API_CLIENT_SECRETS` entry
and is the only thing that ever sends the `secret` header. The website meets this through the
service binding instead, so it holds no secret at all. See §7.

Because consumers call the API from their own backend, and the website uses RPC, **no CORS
configuration is needed on the API** (and none exists).

---

## 3. Threat model

**Defended against:**
- An unapproved caller (random internet traffic, a scraper, a copycat site) getting a useful
  response from the HTTP API. Blocked by the secret check (§4).
- An outside caller using the RPC entrypoint. Only Workers on the same Cloudflare account can hold
  a service binding to it.
- Any cost from the API. The Workers Free plan never bills. Over its limits, requests fail
  instead (§8).
- Unbounded converter cost. Bounded by the converter's kill switch, spike alarm and budget (§8).
- Decompression bombs and SSRF via the converter. The converter's HMAC signature, host allowlist,
  and pixel, size and time ceilings (§10).
- A single leaked or compromised consumer secret. Revocable on its own, and the change takes
  effect at once (§6).
- One IP hammering the API or the website's `/api/*`. Blocked by the WAF rate-limiting rule (§8).

**Explicitly out of scope, and why:**
- **Availability under abuse.** The Free plan's 100,000 requests a day are shared by every Worker
  on the account. Requests the API rejects with `401` still run the Worker, so they count. Once
  the limit is spent, every Worker on the account, the website included, returns error 1027 until
  00:00 UTC. The WAF rule stops a single IP, not a distributed flood. This costs availability,
  never money.
- **The website's own endpoints.** `https://nzimages.iolab.nz/api/image` and `/api/collections`
  are public, like the backend of any login-free site. Anyone can call them and get an image. They
  are bounded by the WAF rule and the daily limit, not by a secret.
- **A fully-public, direct-from-browser path with real access control.** Impossible by
  construction, since a browser cannot keep a secret. If a truly public (unauthenticated) read
  path is ever wanted on the API itself, that's a deliberate product decision, not a gap in this
  design.
- **Long-lived-secret compromise detection.** There's no automatic detection of secret misuse.
  The only signal is the `Authorized consumer: <name>` log line (§9).

---

## 4. Auth model

**Format.** One Worker secret, `API_CLIENT_SECRETS`, holds a comma-separated list of
`name:secret` pairs, one per approved consumer:

```
API_CLIENT_SECRETS=site:3f9a...,mobile:7bc1...
```

**Generation.** Each secret is a random hex string:

```bash
openssl rand -hex 32
```

Hex-only is deliberate. The format uses `:` to separate name from secret and `,` to separate
entries, so neither character may appear inside a name or secret.

**Check.** On every HTTP request, `worker/src/index.ts`:
1. Returns `404` for anything other than `GET /image` or `GET /collections`, before the check.
2. Reads `API_CLIENT_SECRETS`. If unset or empty, fails closed with `500` (misconfiguration, not
   silently open).
3. Reads the request's `secret` header. If absent, `401`.
4. Calls `authorizedConsumer(presented, allowed)` (`worker/src/api.ts`), which SHA-256 hashes the
   presented value and each entry's secret, then compares them with
   `crypto.subtle.timingSafeEqual` across **every** configured entry. It does not return early on
   the first match, so response timing can't reveal which or how many entries matched.
5. On a match, logs `Authorized consumer: <name>` (Workers Logs, see §9) and proceeds. No match
   gives `401`.

RPC calls through `ImageApi` skip this check and log `Authorized consumer: service binding`.

**Storage.** The pairs live in the `API_CLIENT_SECRETS` Worker secret, set from `worker/` with
`npx wrangler secret put API_CLIENT_SECRETS`. A new value takes effect immediately, with no
redeploy. `secrets.required` in `worker/wrangler.jsonc` makes `wrangler deploy` fail if the secret
is missing. `wrangler secret put` replaces the whole value, so keep the current full list
somewhere outside the repo (a password manager, or the gitignored `.consumer-secrets/`) and edit
that. For local development, `worker/.dev.vars` (gitignored, copied from `.dev.vars.example`)
holds a dev value. Never commit a real one.

**Deliberate trade-offs vs. Cognito M2M** (the design this replaced, see the ADR):
- Secrets are **long-lived** and rotated manually, not auto-expiring 1-hour OAuth tokens.
- The check happens **inside the Worker**, not at a gateway in front of it. An unauthorized
  request still runs the Worker briefly (the check comes before any DigitalNZ call) and counts
  toward the daily request limit (§8).
- No standard OAuth scopes, token introspection, or central revocation UI. Just one Worker secret.
  Fine while consumers are few. Revisit if that stops being true (§9, ADR "triggers to revisit").

---

## 5. Onboarding a new consumer

1. Generate a secret: `openssl rand -hex 32`.
2. Append `,<name>:<secret>` to the current full `API_CLIENT_SECRETS` value. Choose a short,
   stable `name`. It's what shows up in logs.
3. From `worker/`, run `npx wrangler secret put API_CLIENT_SECRETS` and paste the full new value.
   It takes effect immediately. No redeploy is needed.
4. Hand the secret to the consumer **over a channel that isn't this repo or a public issue
   tracker** (for example a password manager share or an encrypted message). It must be stored
   server-side only by the consumer (§7), never in client-side, browser or app code.
5. Smoke-test: have the consumer's backend make one real request and confirm `200`. Check
   Workers Logs for `Authorized consumer: <name>` to confirm it's attributed correctly (§9), or
   run:
   ```bash
   API_URL="https://nzimages-api.iolab.nz" \
   API_SECRET="<the new secret>" \
   ./scripts/smoke-test-access-control.sh
   ```
   which asserts `200` with the valid secret and `401` for missing or wrong secrets. Pass
   `--throttle` to also fire 40 parallel `/collections` requests and expect a `429` from the WAF
   rule (§8). Those requests count toward the daily limit, so it's opt-in.

A consumer that is another Worker on the same Cloudflare account doesn't need a secret. Give it a
service binding instead (§7).

---

## 6. Revoking / rotating

**Revoke** (consumer no longer approved, or secret suspected leaked):
1. Remove that `name:secret` entry from the full value.
2. Run `npx wrangler secret put API_CLIENT_SECRETS` with the new value.
3. Verify: a request using the removed secret now returns `401`.

**Rotate** (planned, no compromise):
1. Generate a new secret for that consumer.
2. Put a value that holds **both** the old and the new entry for that consumer (same `name`).
3. Hand the new secret to the consumer and have them switch over.
4. Once the logs show they've switched, put the value again without the old entry.

Skipping step 2 and replacing the entry directly also works, but the old secret stops working
the moment the put completes, so the consumer fails until they switch.

**Emergency rotation under suspected compromise:**
1. Immediately remove the compromised entry and `wrangler secret put` the new value. This takes
   effect at once, even before a replacement is ready.
2. Generate and distribute a new secret to the legitimate consumer per §5.
3. Check Workers Logs (§9) around the suspected leak window for `Authorized consumer: <name>`
   lines to gauge impact (how many requests, over what period).
4. The leak can't have cost money on the API, since the Free plan never bills. Its cost is
   requests against the daily limit (§8). The converter has its own alarm and budget emails.

---

## 7. Proxy reference implementations

Every HTTP consumer runs a thin backend or edge component that holds its secret and is the only
thing that ever calls the API directly. The browser or app talks only to that component.

### The website (service binding, no secret)

The website `nzimages-web` (separate repo, `https://nzimages.iolab.nz`) is Static Assets plus a
small Worker for `/api/*`. That Worker calls `nzimages-api` through a service binding to the
`ImageApi` entrypoint, so it holds no secret:

```jsonc
"services": [{ "binding": "API", "service": "nzimages-api", "entrypoint": "ImageApi" }]
```

It is still listed as `web` in `API_CLIENT_SECRETS`, for history only. It no longer sends the
header, so removing that entry (§6) would not affect it. This only works for Workers on the same
Cloudflare account. See `worker/README.md` ("RPC for the website") for the call shapes.

### A third-party web consumer (its own backend)

A consumer outside the account can't use a service binding. It needs its own backend holding a
secret:

```js
// Server-side only (a Next.js route handler, or a Worker on another account).
// The browser calls THIS endpoint, same-origin, never the API directly.
export async function GET() {
  const res = await fetch(`${process.env.IMAGE_API_URL}/image`, {
    headers: { secret: process.env.NZIMAGE_API_SECRET }, // this consumer's API_CLIENT_SECRETS entry
  })
  return new Response(await res.text(), {
    status: res.status,
    headers: { "content-type": "application/json" },
  })
}
```

`IMAGE_API_URL` (`https://nzimages-api.iolab.nz`) and `NZIMAGE_API_SECRET` are server-side
environment variables in the consumer's own deployment (for example its hosting project's
settings), never sent to the client.

### Mobile app

Same shape: **app → your backend → the API**, with the backend holding the secret. The extra
question a mobile app raises is trusting the **app → backend** hop, since the app binary can't
hold a secret either (it can be decompiled). Options, in order of recommendation for a
login-free public app:

1. **App attestation**: iOS [App Attest](https://developer.apple.com/documentation/devicecheck/establishing-your-app-s-integrity)
   or Android [Play Integrity](https://developer.android.com/google/play/integrity/overview). The
   app proves to your backend it's a genuine, unmodified instance on a real device. The backend
   verifies with Apple or Google before calling the API.
2. **User login**, if or when the app grows accounts. A per-user session token instead of a
   shared app-wide credential.
3. **Minimal**: rate-limit the backend endpoint and accept it's effectively public. Weakest
   option, and doesn't fully meet "approved sources only". Optionally add TLS certificate pinning
   in the app as a defense against a MitM-modified client either way.

---

## 8. Cost controls

The API can't cost money: the Workers Free plan never bills, and over its limits requests fail
instead. So the controls below protect **availability** on the Cloudflare side and **spend** on
the AWS side, where the converter runs. Each caps a different failure mode.

| Control | What it caps | Current value | Where |
|---|---|---|---|
| Workers Free plan | API **spend** (never bills) and daily **volume** | 100,000 requests/day for the whole account, reset 00:00 UTC. 10 ms CPU and 50 subrequests per request | Cloudflare account plan |
| WAF rate-limiting rule | Request **rate** per IP | More than 30 requests in 10 s to `/image`, `/collections`, `/api/image` or `/api/collections` blocks that IP for 10 s | `iolab.nz` zone, not in this repo |
| Subrequest budget | Outbound fetches per API request | 50, each redirect hop counted | `worker/src/http.ts` |
| CloudWatch alarm (converter) | Notifies on, and stops, a converter **spike** | >100 invocations in 5 minutes → email + kill switch | `Jp2ConverterInvocationsAlarm` |
| Converter kill switch | Converter **spend**: sets its concurrency to 0 on a spike, or when month-to-date usage nears the free tier | 250,000 GB-s, 800,000 requests or 20,000 converter calls a month | `ConverterGuardFunction` (`guard/app.py`), see `.claude/rules/converter.md` |
| Monthly budget | Notifies on any **real AWS spend** | >$1 actual or forecasted → email | `MonthlyCostBudget` |

The alarm, the kill switch's emails and the budget all notify through the `nzimageapi-cost-alarms`
SNS topic.

The website also limits its own traffic: it pauses polling in hidden tabs and backs off from 1 s
to 60 s on failures.

**The kill switch is the only reserved concurrency, and it is set at runtime.**
`ConverterGuardFunction` sets the converter's reserved concurrency to **0** to switch it off (a
reservation of 0 doesn't lower the unreserved pool) and deletes it to switch it back on. Nothing in
`template.yaml` reserves concurrency.

**No positive reserved concurrency.** This AWS account's total Lambda concurrent-executions quota
is **10** (not the usual 1,000 default), and is fully unreserved. Setting
`ReservedConcurrentExecutions` on any function, even a small value, would push the account's
unreserved pool below its own floor and the deploy is rejected (`InvalidRequest`: "decreases
account's UnreservedConcurrentExecution below its minimum value of [10]"). The converter and the
guard share that pool of 10. If the quota is ever increased (`aws service-quotas
request-service-quota-increase --service-code lambda --quota-code L-B99A9384 --desired-value <N>
--region ap-southeast-2`, free to request, AWS approval is not instant), a positive reservation on
the converter would give it its own ceiling.

**Tuning:** raise `ConverterSpikeThreshold` or the `Guard*` limits (stack parameters) if they fire
on normal traffic. Raise the WAF rule's threshold on the `iolab.nz` zone if legitimate users get
blocked (see §9).

**Verified free-tier facts this design relies on** (re-verify on the vendors' pricing pages if
tuning years after this was written):
- **Cloudflare Workers Free**: 100,000 requests a day per account, reset at 00:00 UTC, 10 ms CPU
  and 50 subrequests per request. It never bills. Over the daily limit, every Worker on the
  account returns error 1027 until the reset.
- **Cloudflare WAF**: the rate-limiting rule above is available on the zone's free plan.
- **Lambda**: perpetual free tier, 1M requests + 400,000 GB-seconds/month, every account, never
  expires.
- **Data transfer out**: 100 GB/month free. `GuardMaxConverterInvocations` keeps the converter
  under it.
- **Reserved concurrency**: no charge to configure.
- **CloudWatch alarms**: first 10 per account are free (this stack uses 1).
- **AWS Budgets**: basic cost budgets with email notifications are free.

---

## 9. Operations / runbook

**Where the logs are.** The API's logs are in Workers Logs (`observability.enabled` in
`worker/wrangler.jsonc`), under the `nzimages-api` Worker in the Cloudflare dashboard. Stream them
live with `npx wrangler tail` from `worker/`. Every authorized HTTP request logs
`Authorized consumer: <name>`, and every RPC call logs `Authorized consumer: service binding`.

**You get an alarm or budget email. What do you do?**

1. **Identify which fired.** The subject line names the alarm
   (`nzimageapi-converter-invocations-high`) or the budget (`nzimageapi-monthly-cost-tripwire`).
   A guard email means the kill switch switched the converter off or on.
2. **If the converter spiked**, the guard has already switched it off. It switches back on by
   itself once month-to-date usage is under the limits and the alarm has been quiet for
   `GuardSpikeCooldownHours` (6). To keep it off, or switch it on by hand, see
   `.claude/rules/converter.md`. While it's off, converter URLs fail and the slideshow skips those
   images.
3. **If the budget alarm fired** (real spend, not just volume), check the AWS Billing console's
   cost breakdown by service. With the kill switch in place, the likely causes are that the
   guard's limits were raised or its schedule disabled, that Lambdas run in another region (the
   guard only reads `ap-southeast-2`), or that the spend comes from something outside this stack.

**The API or website starts failing. What do you do?**

1. **Error 1027 from every Worker** means the account's 100,000 daily requests are spent. Nothing
   is billed. It clears at 00:00 UTC. To see what used them, check the Workers analytics in the
   Cloudflare dashboard, then the API's logs:
   - `Authorized consumer: <name>` lines show which consumer drove the volume. If it's an approved
     consumer misbehaving (bug, retry loop), contact them. There's no per-consumer limit (the WAF
     rule is per IP, the daily limit per account), so the blunt option is to revoke (§6) until they
     fix it.
   - A flood of `401`s with no `Authorized consumer` line is unapproved traffic being correctly
     rejected. It's not a breach, but each rejected request still counted. Tighten the WAF rule if
     it keeps happening.
2. **`429`s** mean the WAF rule blocked an IP that sent more than 30 requests in 10 s. If
   legitimate traffic trips it (for example many users behind one shared IP), raise the rule's
   threshold on the `iolab.nz` zone.
3. **`401`s for an approved consumer** mean its entry isn't in the current `API_CLIENT_SECRETS`.
   A `wrangler secret put` replaces the whole value, so check the last put didn't drop it, then
   put the full value again.

---

## 10. Converter security

`Jp2ConverterFunction` (`converter/app.py`) is a public, unauthenticated Function URL
(`AuthType: NONE`). "Unauthenticated" only means AWS doesn't gate it. The application layer does:

- **HMAC signature.** Every converter URL the API Worker emits is signed with
  `CONVERTER_SIGNING_KEY`, a Worker secret that matches the converter's env var (from the `NoEcho`
  `ConverterSigningKey` stack parameter). The converter recomputes the signature over the presented
  `url` parameter and rejects (`403`) anything that doesn't match (`hmac.compare_digest`). Only the
  Worker can mint a valid URL. A browser loading a Worker-issued link works, and anyone
  hand-crafting a converter URL does not.
- **Host allowlist.** `ALLOWED_HOSTS` restricts which origin the converter will fetch a master
  image from (NDHA, Feilding Library, Manawatū Heritage), bounding SSRF exposure even if the
  signature check were ever bypassed.
- **Resource ceilings.** `MAX_IMAGE_PIXELS = 500_000_000` (decompression-bomb guard), a download
  size cap, and a download timeout bound worst-case memory and time per invocation. Combined with
  the account-wide Lambda concurrency limit (§8), this bounds worst-case concurrent cost.
  `Cache-Control: public, max-age=31536000, immutable` on successful responses means a repeat
  request for the same image is served from cache (by the browser or any CDN in front) rather than
  re-invoking the converter at all. That's the main lever against repeat-recompute cost.
- **Kill switch.** `ConverterGuardFunction` switches the converter off on a spike or when
  month-to-date usage nears the free tier (§8, `.claude/rules/converter.md`).
- **No `API_CLIENT_SECRETS` involvement.** The converter is not part of the per-consumer-secret
  scheme in §4. It's called by the end user's browser with a URL the API Worker already
  authorized, not by a consumer's backend.
