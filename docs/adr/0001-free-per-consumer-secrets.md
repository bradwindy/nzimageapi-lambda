# ADR 0001: Free per-consumer static secrets instead of Cognito M2M

**Status:** Accepted

## Context

`/image` (an API Gateway HTTP API in front of a Swift Lambda) was gated by a single static
`secret` header shared by every caller — anyone who knew it, or who was handed it for one
purpose, could use it for any purpose, and revoking it broke every caller at once. The stack was
also unbounded on request volume and concurrency: nothing stopped a caller (approved or not) from
running up processing time.

The owner's requirements, gathered during planning:

1. Only approved sources should be able to call `/image`.
2. No caller should be able to run up unbounded processing time or cost.
3. Callers are (or will be) a public website's browser-side code and possibly a mobile app —
   both are *public clients*: anything shipped to a browser page or an app binary is extractable
   (view-source; decompilation), so neither can hold a real secret directly.
4. ~2 consumers expected, each independently revocable.
5. **The whole project must cost $0**, using only AWS's perpetual free tiers. The owner explicitly
   said they'd accept a *less secure* design to guarantee this.

## Options considered

**A. Amazon Cognito machine-to-machine (OAuth2 client-credentials) + API Gateway native JWT
authorizer.** The strongest option investigated: short-lived (≈1h) auto-expiring tokens, per-client
scopes, rejection at the API Gateway edge (before the Lambda is even invoked), standard tooling.
**Rejected on cost**: AWS Cognito has **no free tier for M2M token requests** — every successful
`client_credentials` token request is billed ($0.00225 per 1,000 as of the pricing structure in
effect when this was written, after AWS removed the earlier $6/app-client/month fee in November
2025). At the traffic this project expects, with hourly token caching, the actual bill would be a
fraction of a cent per month — but the requirement was **completely free**, not "negligibly
cheap," so this was cut.

**B. Free per-consumer static secrets, checked in-Lambda (chosen).** One environment variable
(`API_CLIENT_SECRETS`) holding `name:secret` pairs; the Lambda constant-time-compares the
presented `secret` header against every entry and authorizes on a match. $0 to operate — it's just
an env var and a comparison. Individually revocable (remove an entry) and attributable (the
matched name is logged). Paired with free-tier cost ceilings (API Gateway stage throttling,
per-function reserved concurrency, CloudWatch alarms, an AWS Budget) to satisfy requirement 2
without Cognito's per-request billing.

**C. Single shared secret (status quo, hardened only with cost ceilings).** Simplest possible
change — keep one secret for everyone, add only the free cost controls. Also $0. Rejected because
it doesn't satisfy requirement 4 (revoking one consumer means rotating the secret for all of
them) — the owner explicitly wanted per-consumer revocability even at ~2 consumers.

## Decision

Adopt **Option B**: free per-consumer static secrets (`API_CLIENT_SECRETS`), checked inside the
Swift Lambda, combined with free-tier cost ceilings:
- API Gateway stage throttling (`ThrottlingRateLimit`/`ThrottlingBurstLimit` on the now-explicit
  `ServerlessHttpApi` resource).
- `ReservedConcurrentExecutions` on both `NZImageApiFunction` and `Jp2ConverterFunction`.
- Two CloudWatch alarms (per-function invocation-count thresholds) and one AWS Budget, all
  emailing `AlarmEmail` via a shared SNS topic.

Full design, onboarding/revocation procedure, and operational runbook:
[`docs/ACCESS-CONTROL.md`](../ACCESS-CONTROL.md).

## Consequences / accepted trade-offs

Compared to Option A (Cognito), this decision knowingly accepts:

- **Long-lived secrets**, rotated manually, instead of auto-expiring ~1-hour OAuth tokens. A
  leaked secret remains valid until someone notices and rotates it (see
  `docs/ACCESS-CONTROL.md` §6, "Emergency rotation under suspected compromise").
- **Rejection happens inside the Lambda, not at the API Gateway edge.** An unauthorized request
  still invokes `NZImageApiFunction` for a few milliseconds (the secret check is the first thing
  `handle` does, before any DigitalNZ API call) rather than being rejected before invocation.
  Bounded by the throttling and reserved-concurrency ceilings either way.
- **No standard OAuth machinery** — no scopes, no token introspection endpoint, no centralized
  revocation UI. Onboarding/revoking is an env-var edit and a redeploy.
- **The 12-month API Gateway HTTP API free-tier window** (1M requests/month) still applies
  regardless of this decision — it's a property of API Gateway, not of the auth model. After that
  window, requests cost ~$1/million. See `docs/ACCESS-CONTROL.md` §8 for the noted (not
  implemented) Lambda-Function-URL migration that would remove this ceiling entirely.

## Triggers to revisit this decision

Reconsider Cognito M2M (or a Lambda authorizer with a similar edge-rejection model) if **either**:

- The number of approved consumers grows past a small handful, such that hand-editing
  `API_CLIENT_SECRETS` and redeploying for every onboard/revoke becomes operationally painful, or
- The sub-cent-per-month Cognito M2M cost stops being a hard blocker (i.e., "completely free" is
  relaxed to "cheap"), since Option A was otherwise the stronger design on every axis except price.

Do not silently revert to Option A without re-reading this ADR — the free-tier cost analysis that
ruled it out was current as of when this was written and should be re-verified (Cognito, API
Gateway, and Lambda pricing all change over time).
