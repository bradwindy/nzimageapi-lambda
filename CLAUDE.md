# nzimageapi-lambda

## Overview

The NZ Image API serves random images from the [DigitalNZ](https://digitalnz.org/) API. It is a
**pure URL builder**: it never returns image bytes, only JSON metadata pointing at the
highest-resolution image URL it can reach for a given collection.

It runs in two places, chosen so that nothing can bill:

- **The API** is the TypeScript Cloudflare Worker `nzimages-api` in `worker/`, on the Workers
  **Free** plan at `https://nzimages-api.iolab.nz`. The Free plan returns errors instead of
  billing when a limit is hit.
- **The JP2/TIFF converter** is a Python + Pillow AWS Lambda (`converter/`), the one job no
  Cloudflare Free product can do, kept inside Lambda's always-free allowance by a kill switch
  (`guard/`). It is deployed as the `nzimageapi` SAM stack (`template.yaml`).

The website (`nzimage-web`, a separate repo) is the Worker `nzimages-web` at
`https://nzimages.iolab.nz`. It calls the API over a service binding (RPC), not over HTTP.

The repo name is historical: the API was a Swift Lambda behind API Gateway until October 2026
(see git history before that).

## Repository layout

- `worker/` - the API Worker (the product). Its own `README.md` covers files, local dev, tests and deploy.
- `converter/` - Python Pillow Lambda (`app.py`, a .zip built by `converter/Makefile`) that decodes JP2/TIFF masters to JPEG behind a signed Function URL.
- `guard/` - the converter's free-tier kill switch Lambda (`app.py`): sets the converter's concurrency to 0 on a usage spike or when month-to-date usage nears the free tier.
- `collection-reviewer-web/` - Next.js app for triaging DigitalNZ collections. Its dev server also boots the API Worker with `wrangler dev`.
- `Research/highres/` - durable record of the (complete, 52-collection) high-resolution sweep. `progress.json` is the authoritative machine record. It refers to the old Swift files, which map one to one onto `worker/src`.
- `docs/` - access-control and cost-control design doc, and ADRs.
- `scripts/smoke-test-access-control.sh` - curl checks for the API's auth and rate limit.
- `template.yaml` - the SAM stack: converter, kill switch, spike alarm, cost-alarm topic, $1 budget.
- `infra/bootstrap.yaml` - the SAM artefact bucket and its retention policy (separate stack).

## Architecture essentials

- `worker/src/index.ts` handles `GET /image` and `GET /collections`, and exports the
  `ImageApi` RPC entrypoint (`image({ collection, exclude })`, `collections()`) that the
  website's service binding calls. RPC has no secret check: only Workers on the same account
  can call it.
- Every HTTP request must send a `secret` header matching one `name:secret` pair in the
  `API_CLIENT_SECRETS` Worker secret. It is checked in constant time across *all* entries.
  Missing/empty `API_CLIENT_SECRETS` -> 500 (fail closed), bad/missing header -> 401.
- Per-collection image-URL upgrading lives in `worker/src/urlProcessor.ts`: a strategy
  registry plus a legacy `switch` fallback, covering Recollect, eHive IIIF, Vernon Browser,
  NDHA/Rosetta, Flickr, CONTENTdm/V&A IIIF, and more.
- Collections whose masters need decoding (JP2/TIFF) get routed through the converter Lambda
  with an HMAC-signed URL (`CONVERTER_SIGNING_KEY` secret, `JP2_CONVERTER_URL` var).
- Random-collection selection weights are **derived from the counts table** in
  `worker/src/collections.ts`, not hand-set fractions: each collection's odds of being picked are
  its share of the total image count. This is a deliberate fix (hardcoded weights once summed to
  0.837 and gave the last entry an extra ~16%). Never replace the counts with pre-divided
  fractions. Refresh them with `DIGITALNZ_API_KEY=... npm run count-collections` in `worker/`
  and paste the output over the table.

Full request-flow detail: [`.claude/rules/architecture.md`](.claude/rules/architecture.md).

## Commands

```bash
# API Worker (in worker/)
npm ci
npm test                         # Vitest inside workerd, outbound fetches mocked
npm run typecheck
npm run dev                      # http://127.0.0.1:8787, secrets from worker/.dev.vars
NZIMAGE_API_SECRET=... npm run check-collections -- --base-url https://nzimages-api.iolab.nz

# Converter and kill switch
(cd converter && pytest)
(cd guard && pytest)
sam build && sam deploy          # converter stack, see build-test-deploy.md

# Reviewer web app (boots the API Worker on :8787 too)
cd collection-reviewer-web && npm run dev
```

Full command reference and deploy detail: [`.claude/rules/build-test-deploy.md`](.claude/rules/build-test-deploy.md).

## Environment variables and secrets

- Worker secrets (`wrangler secret put`): `DIGITALNZ_API_KEY` (sent as the
  `Authentication-Token` header to DigitalNZ), `API_CLIENT_SECRETS` (comma-separated
  `name:secret` pairs), `CONVERTER_SIGNING_KEY` (shared with the converter Lambda).
- Worker var (`worker/wrangler.jsonc`): `JP2_CONVERTER_URL`, the stack's `Jp2ConverterUrl` output.
- Local dev: `worker/.dev.vars` (copy `.dev.vars.example`), repo-root `.env` for the reviewer app.
- SAM parameters: `ConverterSigningKey`, `AlarmEmail`, plus the kill-switch thresholds.

Secrets live in gitignored `.env`, `.dev.vars`, `samconfig.toml`, and `.consumer-secrets/`. Never commit them.

## Code style

- TypeScript (strict) for the Worker and the reviewer app, Python 3.13 for the Lambdas.
- Match existing patterns: the `urlProcessor.ts` strategy registry for new per-collection URL
  logic (see [`.claude/rules/architecture.md`](.claude/rules/architecture.md)), and every
  outbound fetch through `worker/src/http.ts`.

## Gotchas

- **Workers Free plan limits are the API's budget.** 100,000 requests a day shared by every
  Worker on the account (resets 00:00 UTC), 10 ms CPU per request, 50 subrequests per request.
  Over the daily limit every Worker on the account returns error 1027 until the reset. Measured
  CPU is 3-8 ms a request, so avoid DOM libraries or anything that parses whole pages: use the
  regex approach in `worker/src/html.ts`. `worker/src/http.ts` enforces the
  subrequest budget, including redirects.
- `secrets.required` in `worker/wrangler.jsonc` makes `wrangler deploy` fail until all three
  secrets exist on the Worker. `wrangler dev` only warns.
- Routing a new collection through the converter requires adding its host to
  `ALLOWED_HOSTS` in `template.yaml` and redeploying the converter. A pure `urlProcessor.ts`
  strategy change doesn't.
- Replacing the converter function (for example a `PackageType` change) gives it a new Function
  URL. Update `JP2_CONVERTER_URL` in `worker/wrangler.jsonc` from the stack output and redeploy
  the Worker.
- `template.yaml` deliberately sets **no** `ReservedConcurrentExecutions` (the account's Lambda
  concurrency quota is only 10 and must stay fully unreserved). The one exception is
  runtime-only: `ConverterGuardFunction` sets the converter's reservation to **0** to switch it
  off, and deletes it to switch it back on. A converter returning 429 / throttling everything is
  usually the kill switch, not a bug: check the guard's logs and the `nzimageapi-cost-alarms` emails.
- `sam build` needs network access to PyPI for the converter's `pip install`. Run it with the
  sandbox disabled.
- The reviewer web app and `scripts/update-collections.ts` both write the same collections file.
  Never run both writers at once (see `collection-reviewer-web/lib/collectionsFile.ts`).
- The converter is a **.zip**, not a container image, so there is no ECR repo to pay for. Its
  `converter/Makefile` installs Pillow's `manylinux_2_28_aarch64` wheel with `pip --platform`, so
  `sam build` gives the same artefact on macOS and in CI. CI then imports the built package on
  arm64 Python 3.13 to prove JP2 and TIFF decoding are present. Every `sam deploy` uploads zips
  to the SAM artefact bucket declared in [`infra/bootstrap.yaml`](infra/bootstrap.yaml)
  (separate `nzimageapi-bootstrap` stack, 60-day expiry). It is **deliberately not in
  `template.yaml`**: `sam deploy` uploads before CloudFormation runs, so a bucket in the
  consuming stack would not exist yet. `samconfig.toml` points at it with `s3_bucket`, and CI
  reads it from the bootstrap stack's outputs. Full detail:
  [`.claude/rules/build-test-deploy.md`](.claude/rules/build-test-deploy.md#deploy-artefact-retention-cost-control).

## Where to read more

- [`worker/README.md`](worker/README.md) - the API Worker: files, local dev, tests, scripts, deploy, RPC contract.
- [`.claude/rules/architecture.md`](.claude/rules/architecture.md) - request flow, parsing, strategy-registry pattern, HTTP rules.
- [`.claude/rules/build-test-deploy.md`](.claude/rules/build-test-deploy.md) - build/test/deploy reference for every part.
- [`.claude/rules/converter.md`](.claude/rules/converter.md) - the converter Lambda and its kill switch.
- `README.md` - end-user API reference and setup.
- `docs/ACCESS-CONTROL.md`, `docs/adr/0001-free-per-consumer-secrets.md` - auth model and cost-control design.
- `Research/highres/README.md`, `recipes.md`, `progress.json` - per-collection high-res findings.
