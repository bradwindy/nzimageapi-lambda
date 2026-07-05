# Access Control & Cost Containment

This is the source-of-truth document for how the `nzimageapi` stack decides who may call it and
how it stops any caller — approved or not — from running up processing time or cost. Read this
before onboarding a new consumer, before tuning any limit, and before responding to a cost or
abuse alert.

**Governing constraint:** this project is meant to run entirely within AWS's perpetual free tiers
(see [`docs/adr/0001-free-per-consumer-secrets.md`](adr/0001-free-per-consumer-secrets.md) for why).
Every control described here was chosen because it is free. Nothing in this document costs money
to operate at the traffic levels this project expects.

---

## 1. Overview & goals

Two goals, in this order:

1. **Only approved sources can call `/image`.** Software the owner hasn't explicitly approved
   must not be able to get a useful response.
2. **No caller — approved or not — can run up processing time or cost.** Even a legitimate,
   approved consumer that misbehaves (bug, retry storm, leaked credential) must be bounded.

A hard constraint shapes the design: **the whole thing must cost $0**, using only AWS's perpetual
free tiers. That constraint ruled out the strongest available design (Amazon Cognito
machine-to-machine authentication, which has no free tier) in favor of a weaker but genuinely free
one: per-consumer static secrets checked inside the Lambda, backed by free-tier cost ceilings
(stage throttling, the account-wide Lambda concurrency limit, alarms, a budget). The trade-offs
this accepts are listed in §3 and in the ADR.

---

## 2. Architecture

```
Browser / mobile app  ──HTTPS──▶  Consumer's OWN backend/edge  ──secret header──▶  /image (HTTP API)
(public client:                   (Next.js route / CF Worker /   │                   in-Lambda check vs
 holds NO secret)                  small server; holds THIS       │                   API_CLIENT_SECRETS;
      ▲                            consumer's random secret)      │                   401 before any work
      │  same-origin JSON                                         │
      └─────────────────────────────────────────────────────────┘

Converter images: the browser loads the HMAC-signed converter URL directly (unchanged; already
gated independently — see §10).
```

There are **two separate request paths**, and they're gated differently:

- **Image metadata** (`GET /image`) — returns JSON describing a randomly chosen image (title,
  description, thumbnail/large-image URLs). Gated by the per-consumer secret (§4). This is the
  path a consumer's backend calls.
- **Image bytes**, for collections that need format conversion (JP2/TIFF → JPEG) — the metadata
  response contains a URL pointing at `Jp2ConverterFunction`'s public Function URL. That URL is
  itself HMAC-signed by the Swift Lambda (unrelated to `API_CLIENT_SECRETS`) and is meant to be
  loaded directly by the end user's browser, not proxied. See §10.

**Why the browser/app never holds a secret:** anything shipped to a browser page (view-source) or
a mobile app binary (decompilation) is effectively public. A static secret embedded in either is
not secret. So every consumer must run *some* backend or edge component — even a few lines in a
serverless function — that holds its `API_CLIENT_SECRETS` entry and is the only thing that ever
sends the `secret` header. See §7 for reference implementations.

Because each consumer's proxy calls `/image` same-origin from its own backend, and the browser
only ever talks to that proxy, **no CORS configuration is needed on `/image`** (and none exists).

---

## 3. Threat model

**Defended against:**
- An unapproved caller (random internet traffic, a scraper, a copycat site) getting a useful
  response from `/image` — blocked by the secret check (§4).
- Unbounded cost from *any* caller, approved or not — bounded by stage throttling + reserved
  concurrency on both Lambdas (§8).
- Decompression bombs and SSRF via the converter — the converter's existing HMAC signature, host
  allowlist, and pixel/size/time ceilings, unchanged by this work (§10).
- A single leaked/compromised consumer secret — revocable independently of other consumers (§6),
  and bounded in the meantime by the same throttling/concurrency ceilings.

**Explicitly out of scope, and why:**
- **DDoS / volumetric attack mitigation.** AWS WAF is not available on an HTTP API (API Gateway
  v2) without fronting it with CloudFront, which is out of scope for a $0 design. Stage throttling
  provides a cost ceiling but not attack absorption.
- **A fully-public, direct-from-browser path with real access control.** Impossible by
  construction — a browser cannot keep a secret. If a truly public (unauthenticated) read path is
  ever wanted, that's a deliberate product decision, not a gap in this design.
- **Long-lived-secret compromise detection.** There's no automatic anomaly detection on secret
  misuse beyond the invocation-count alarms (§8/§9), which are coarse (hourly sums, not per-secret).

---

## 4. Auth model

**Format.** One environment variable, `API_CLIENT_SECRETS`, holds a comma-separated list of
`name:secret` pairs — one per approved consumer:

```
API_CLIENT_SECRETS=site:3f9a...,mobile:7bc1...
```

**Generation.** Each secret is a random hex string:

```bash
openssl rand -hex 32
```

Hex-only is deliberate — the format uses `:` to separate name from secret and `,` to separate
entries, so neither character may appear inside a name or secret.

**Check.** On every request, `Sources/NZImageApiLambda/NZImageApiLambda.swift`:
1. Reads `API_CLIENT_SECRETS`. If unset or empty, fails closed with `500` (misconfiguration, not
   silently open).
2. Reads the request's `secret` header. If absent, `401`.
3. Calls `NZImageApiLambda.authorizedConsumer(presented:allowed:)`, which iterates **every**
   configured entry and constant-time-compares the presented value against each entry's secret —
   it does not return early on the first match, so response timing can't reveal which or how many
   entries matched.
4. On a match, logs `Authorized consumer: <name>` (CloudWatch Logs — see §9) and proceeds. No
   match → `401`.

**Storage.** The pairs live in the `ApiClientSecrets` CloudFormation parameter (`NoEcho: true`,
supplied via `--parameter-overrides` or the gitignored `samconfig.toml` — never committed), and
land in the Lambda as the `API_CLIENT_SECRETS` environment variable. An optional upgrade (still
free) is to store the pairs in an SSM Parameter Store **SecureString** and read it at cold start
instead — that makes onboarding/revoking a consumer an SSM edit with no redeploy. Not implemented
by default; the env var is simpler and matches the project's existing `NoEcho`-parameter pattern
(`DigitalNzApiKey`, `ConverterSigningKey`).

**Deliberate trade-offs vs. Cognito M2M** (the design this replaced — see the ADR):
- Secrets are **long-lived** and rotated manually, not auto-expiring 1-hour OAuth tokens.
- The check happens **inside the Lambda**, not at the API Gateway edge — an unauthorized request
  still invokes the Swift Lambda briefly (a few milliseconds; the check is the very first thing
  `handle` does, before any DigitalNZ API call) rather than being rejected before invocation.
  Bounded by the throttling/concurrency ceilings in §8.
- No standard OAuth scopes, token introspection, or centralized revocation UI — just an env var
  and a redeploy. Fine at the current scale (~2 consumers); revisit if that stops being true (§9,
  ADR "triggers to revisit").

---

## 5. Onboarding a new consumer

1. Generate a secret: `openssl rand -hex 32`.
2. Append `,<name>:<secret>` to the `ApiClientSecrets` value in `samconfig.toml` (or your
   `--parameter-overrides`). Choose a short, stable `name` — it's what shows up in logs.
3. Deploy: `sam build && sam deploy` (or, for a config-only change with no code change,
   `aws lambda update-function-configuration --function-name <NZImageApiFunction physical name>
   --environment "Variables={...,API_CLIENT_SECRETS=<new full value>,...}"` — but note this
   bypasses CloudFormation and will drift from the template until the next `sam deploy`; prefer a
   full deploy unless you need the change immediately).
4. Hand the secret to the consumer **over a channel that isn't this repo or a public issue
   tracker** (e.g. a password manager share, an encrypted message). It must be stored server-side
   only by the consumer (§7) — never in client-side/browser/app code.
5. Smoke-test: have the consumer's proxy make one real request and confirm `200`. Check
   CloudWatch Logs for `Authorized consumer: <name>` to confirm it's being attributed correctly
   (§9), or run:
   ```bash
   API_URL="https://<api-id>.execute-api.<region>.amazonaws.com" \
   API_SECRET="<the new secret>" \
   ./scripts/smoke-test-access-control.sh
   ```
   which asserts `200` with the valid secret and `401` for missing/wrong secrets. Pass
   `--throttle` to also confirm the stage throttle engages (fires ~30 rapid requests — real
   invocations, so it's opt-in, not run by default).

---

## 6. Revoking / rotating

**Revoke** (consumer no longer approved, or secret suspected leaked):
1. Remove that `name:secret` entry from `ApiClientSecrets`.
2. Deploy.
3. Verify: a request using the removed secret now returns `401`.

**Rotate** (planned, no compromise):
1. Generate a new secret for that consumer.
2. Replace the entry (same `name`, new secret) in `ApiClientSecrets`.
3. Deploy.
4. Hand the new secret to the consumer; have them switch over.
5. Old secret stops working the moment the deploy completes — there is no overlap window, so
   coordinate the consumer's switchover with the deploy if it must be zero-downtime for them
   (e.g. deploy first with **both** old and new entries present temporarily, confirm the consumer
   has switched, then deploy again removing the old entry).

**Emergency rotation under suspected compromise:**
1. Immediately remove the compromised entry from `ApiClientSecrets` and deploy — this is the fast
   path to cut off the leaked secret, even before the replacement is ready.
2. Generate and distribute a new secret to the legitimate consumer per §5.
3. Check CloudWatch Logs / the invocation alarms (§9) around the suspected leak window to gauge
   impact (how many requests, over what period, attributed to that consumer's `name`).
4. If cost impact is a concern, check the `nzimageapi-monthly-cost-tripwire` budget (§8) — it
   would have already emailed if actual/forecasted spend crossed $1.

---

## 7. Proxy reference implementations

Every consumer runs a thin backend/edge component that holds its secret and is the only thing
that ever calls `/image` directly. The browser or app talks only to that component.

### Web (Next.js route handler or Cloudflare Worker)

```js
// Server-side only (Next.js app/api/random-image/route.ts, or a Cloudflare Worker fetch handler).
// The browser calls THIS endpoint, same-origin — never /image directly.
export async function GET() {
  const res = await fetch(`${process.env.IMAGE_API_URL}/image`, {
    headers: { secret: process.env.NZIMAGE_API_SECRET }, // this consumer's API_CLIENT_SECRETS entry
  });
  return new Response(await res.text(), {
    status: res.status,
    headers: { "content-type": "application/json" },
  });
}
```

`IMAGE_API_URL` and `NZIMAGE_API_SECRET` are server-side environment variables in the consumer's
own deployment (e.g. Vercel/Cloudflare project settings) — never sent to the client.

### Mobile app

Same shape: **app → your backend → `/image`**, with the backend holding the secret. The extra
question a mobile app raises is trusting the **app → backend** hop, since the app binary can't
hold a secret either (it can be decompiled). Options, in order of recommendation for a
login-free public app:

1. **App attestation** — iOS [App Attest](https://developer.apple.com/documentation/devicecheck/establishing-your-app-s-integrity)
   / Android [Play Integrity](https://developer.android.com/google/play/integrity/overview). The
   app proves to your backend it's a genuine, unmodified instance on a real device; the backend
   verifies with Apple/Google before proxying to `/image`.
2. **User login**, if/when the app grows accounts — a per-user session token instead of a shared
   app-wide credential.
3. **Minimal** — rate-limit the backend endpoint and accept it's effectively public. Weakest
   option; doesn't fully meet "approved sources only." Optionally add TLS certificate pinning in
   the app as a defense against a MitM-modified client either way.

---

## 8. Cost controls

Every control below is free at this project's scale. Each caps a different failure mode.

| Control | What it caps | Current value | Where |
|---|---|---|---|
| Stage throttling | Request **rate** at the API Gateway edge | `ThrottlingRateLimit: 10`/s, `ThrottlingBurstLimit: 20` | `template.yaml` → `ServerlessHttpApi.Properties.DefaultRouteSettings` |
| Account-wide Lambda concurrency | Parallel executions across **both** functions combined | `10` (this AWS account's total quota — see below) | AWS account-level Service Quota, not this template |
| CloudWatch alarm (API) | Notifies on unexpected **volume** | >200 invocations/hour → email | `NZImageApiInvocationsAlarm` |
| CloudWatch alarm (converter) | Notifies on unexpected **volume** | >100 invocations/hour → email | `Jp2ConverterInvocationsAlarm` |
| Monthly budget | Notifies on any **real spend** | >$1 actual or forecasted → email | `MonthlyCostBudget` |

**Reserved concurrency was planned but isn't set.** This AWS account's total Lambda concurrent-
executions quota is **10** (not the usual 1,000 default), and is already fully unreserved. Setting
`ReservedConcurrentExecutions` on either function — even a small value — would push the account's
unreserved pool below its own floor and the deploy is rejected (`InvalidRequest`:
"decreases account's UnreservedConcurrentExecution below its minimum value of [10]"). In practice
this account-wide ceiling is *already* a tighter concurrency cap than the per-function
reservations in the original design (10 total vs. the planned 20+5=25), so nothing is lost today —
but it also means the two functions share one pool rather than having independent caps: a burst on
one can starve the other. If the quota is ever increased (`aws service-quotas
request-service-quota-increase --service-code lambda --quota-code L-B99A9384 --desired-value
<N> --region ap-southeast-2` — free to request; AWS approval is not instant), reintroduce
`ReservedConcurrentExecutions` on both functions (comments left in `template.yaml` marking where)
to subdivide the larger pool and restore independent per-function ceilings.

**Tuning:** raise the throttling numbers if legitimate traffic grows past them (watch for `429`s
in that case — see §9); raise the alarm thresholds if they start firing on normal traffic.

**Verified free-tier facts this design relies on** (re-verify at aws.amazon.com if tuning years
after this was written):
- **Lambda**: perpetual free tier, 1M requests + 400,000 GB-seconds/month, every account, never
  expires.
- **Reserved concurrency**: no charge to configure.
- **API Gateway HTTP API stage throttling**: configuration only, no charge.
- **CloudWatch alarms**: first 10 per account are free (this stack uses 2).
- **AWS Budgets**: basic cost budgets with email notifications are free.
- **SSM Parameter Store** (if the optional secret-storage upgrade in §4 is adopted): standard
  parameters at standard throughput are free.

**One honest, unavoidable caveat:** the **API Gateway HTTP API free tier (1,000,000 requests/month)
lasts only 12 months** from account/API creation; after that, requests cost ~$1/million (Lambda
compute itself stays free forever). At hobby traffic this is pennies/month, not a real cost
concern — but it is not literally $0 forever.

**Truly-$0-forever alternative (not implemented, noted for the future):** migrate `/image` off
API Gateway onto a **Lambda Function URL**, the same mechanism `Jp2ConverterFunction` already
uses. Function URLs have no per-request charge — only Lambda compute, which is free forever — so
the 12-month cliff disappears entirely. The handler barely changes (same
`APIGatewayV2Request`/`Response` payload shape). Trade-off: Function URLs cannot do API-Gateway-style
request-rate throttling, so reserved concurrency would become the sole rate/cost cap (the
`API_CLIENT_SECRETS` check is unaffected either way). Revisit this if staying literally $0 past the
12-month window becomes a firm requirement.

---

## 9. Operations / runbook

**You get an alarm or budget email. What do you do?**

1. **Identify which fired** — the subject line names the alarm (`nzimageapi-api-invocations-high`,
   `nzimageapi-converter-invocations-high`) or the budget (`nzimageapi-monthly-cost-tripwire`).
2. **Check who's calling** — CloudWatch Logs for `NZImageApiFunction`: filter for
   `Authorized consumer:` to see which consumer's secret is driving the volume. A flood of `401`s
   with no `Authorized consumer` line means unapproved traffic being correctly rejected (not a
   breach, but worth noting if the volume itself is concerning enough to also want IP-level
   blocking, which is out of scope — see §3).
3. **If it's an approved consumer** misbehaving (bug, retry loop): contact them; consider
   temporarily lowering their impact isn't possible per-consumer today (the throttle/concurrency
   caps are stack-wide, not per-secret) — the blunt option is to revoke (§6) until they fix it.
4. **If it's unapproved traffic**: confirm it's actually being rejected (`401`s in the logs, not
   `200`s). The throttling ceiling and the account-wide concurrency limit already bound the cost
   impact; no further action is required unless volume is high enough to be a nuisance, in which case
   consider the CloudFront + WAF escalation path noted in the ADR.
5. **If the budget alarm fired** (real spend, not just volume): check the AWS Billing console's
   cost breakdown by service. Given the free-tier ceilings in §8, the most likely causes are (a)
   the 12-month API Gateway free-tier window has lapsed (§8 caveat) or (b) a reserved-concurrency
   or throttling value was raised high enough to be pushing real usage past the 1M-request Lambda
   free tier — check actual invocation counts against the 1,000,000/month and 400,000 GB-second
   ceilings.

**Reading `429`s:** a `429` from `/image` means the stage throttle rejected the request (§8). If
these show up for legitimate traffic, raise `ThrottlingRateLimit`/`ThrottlingBurstLimit` and
redeploy.

---

## 10. Converter security (unchanged by this work, documented for completeness)

`Jp2ConverterFunction` (`converter/app.py`) is a public, unauthenticated Function URL
(`AuthType: NONE`) — but "unauthenticated" only means AWS doesn't gate it; the application layer
does:

- **HMAC signature.** Every converter URL the Swift Lambda emits is signed with
  `CONVERTER_SIGNING_KEY` (shared, `NoEcho` parameter). The converter recomputes the signature over
  the presented `url` parameter and rejects (`403`) anything that doesn't match
  (`hmac.compare_digest`). Only the Swift Lambda can mint a valid URL — a browser loading a
  Swift-Lambda-issued link works; anyone hand-crafting a converter URL does not.
- **Host allowlist.** `ALLOWED_HOSTS` restricts which origin the converter will fetch a master
  image from (NDHA, Feilding Library, Manawatū Heritage), bounding SSRF exposure even if the
  signature check were ever bypassed.
- **Resource ceilings.** `MAX_IMAGE_PIXELS = 500_000_000` (decompression-bomb guard), a download
  size cap, and a download timeout bound worst-case memory/time per invocation. Combined with the
  account-wide Lambda concurrency limit (§8), this bounds worst-case concurrent cost.
  `Cache-Control: public, max-age=31536000, immutable` on successful responses means a repeat
  request for the same image is served from cache (by the browser or any CDN in front) rather than
  re-invoking the converter at all — the main lever against repeat-recompute cost.
- **No `API_CLIENT_SECRETS` involvement.** The converter is not part of the per-consumer-secret
  scheme in §4 — it's called by the end user's browser with a URL the Swift Lambda already
  authorized, not by a consumer's backend.
