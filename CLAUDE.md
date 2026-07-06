# nzimageapi-lambda

## Overview

A multi-component monorepo, deployed as one AWS SAM stack, that serves random images
from the [DigitalNZ](https://digitalnz.org/) API. The core is a Swift Lambda that acts
as a **pure URL builder** — it never returns image bytes, only JSON metadata pointing at
the highest-resolution image URL it can reach for a given collection. A companion Python
Lambda converts awkward master formats (JP2/TIFF) to JPEG on demand.

## Repository layout

- `Sources/NZImageApiLambda/` — the Swift HTTP API Lambda (the product).
- `Sources/Testing/` — CLI tools: `CollectionTester`, `CollectionReviewer`, `CollectionLister`, `ImageResolutionChecker`, shared `LambdaTesting` lib.
- `converter/` — Python Pillow Lambda (`app.py`) that decodes JP2/TIFF masters to JPEG behind a signed Function URL.
- `collection-reviewer-web/` — Next.js 15 app for triaging DigitalNZ collections; its dev server also boots the Swift Lambda.
- `Research/highres/` — durable record of the (complete, 52-collection) high-resolution sweep; `progress.json` is the authoritative machine record.
- `docs/` — access-control design doc and ADRs.
- `scripts/` — legacy pre-SAM build/deploy scripts (`sam` is now the real deploy path).
- `template.yaml` — the SAM stack definition for both Lambdas.

## Architecture essentials

- Entry point `Sources/NZImageApiLambda/App.swift` uses swift-aws-lambda-runtime **v2**'s
  closure API (`LambdaRuntime { event, context in ... }`) with `APIGatewayV2Request`/`Response`
  — this is an **HTTP API (API Gateway v2)**, not a Function URL. Swift 6, `.macOS(.v15)`.
- Every request must send a `secret` header matching one `name:secret` pair in
  `API_CLIENT_SECRETS`. Checked in constant time across *all* entries (no early exit, no
  timing leak). Missing/empty `API_CLIENT_SECRETS` → 500 (fail closed); bad/missing header → 401.
- Per-collection image-URL upgrading lives in `Sources/NZImageApiLambda/Helpers/URLProcessor.swift`
  (~1500 lines): a `static let strategies: [String: URLStrategy]` registry plus a legacy
  `switch` fallback, covering Recollect, eHive IIIF, Vernon Browser, NDHA/Rosetta, Flickr,
  CONTENTdm/V&A IIIF, and more.
- Collections whose masters need decoding (JP2/TIFF) get routed through the separate,
  HMAC-signed converter Lambda (`URLProcessor.signedConverterURL`) rather than doing that
  work in the API Lambda itself.
- The high-res sweep (collections 34–52) is done; treat `Research/highres/progress.json`
  as ground truth over the prose summaries.
- Random-collection selection weights (`NZImageApi.collectionWeights`, used by
  `weightedRandomPick()`) are a **computed property derived from `NZImageApi.collectionImageCounts`**,
  not hand-set fractions — each collection's odds of being picked are its share of the total
  image count across all listed collections. This is a deliberate fix: the original hardcoded
  weights only summed to 0.837, which silently gave the last dictionary entry an extra ~16%
  pick chance via `weightedRandomPick`'s end-of-loop fallthrough. Keep it this way — never
  replace `collectionImageCounts` with pre-divided fractions, since manually-maintained
  fractions are exactly what caused the bug. To refresh counts as collections grow, rebuild
  `CollectionLister` (`swift build --product CollectionLister`) and run it with
  `DIGITALNZ_API_KEY` set — it fetches every collection's live `category=Images` result count
  in one facet query — then paste the updated numbers into `collectionImageCounts`.

Full request-flow/model details: [`.claude/rules/architecture.md`](.claude/rules/architecture.md).

## Commands

```bash
swift build                                            # build all targets
swift test                                             # run XCTest suite (Tests/NZImageApiLambdaTests)

# Run the Lambda locally (listens on 127.0.0.1:7000)
DIGITALNZ_API_KEY=$DIGITALNZ_API_KEY API_CLIENT_SECRETS=dev:super_secret_secret \
  LOCAL_LAMBDA_SERVER_ENABLED=true ./.build/debug/NZImageApiLambda

# End-to-end test a single collection (builds + boots + validates + shuts down)
./Sources/Testing/CollectionTester/test-collection.sh "<Collection Name>"

# Reviewer web app (also boots the Swift Lambda on :7000)
cd collection-reviewer-web && npm run dev
```

Full command reference (SAM build/deploy, Docker/changeset gotchas, legacy scripts):
[`.claude/rules/build-test-deploy.md`](.claude/rules/build-test-deploy.md).

## Environment variables

- `DIGITALNZ_API_KEY` — sent as the `Authentication-Token` header to DigitalNZ.
- `API_CLIENT_SECRETS` — comma-separated `name:secret` pairs for `/image` auth.
- `CONVERTER_SIGNING_KEY`, `JP2_CONVERTER_URL` — shared HMAC key and converter Function URL (SAM injects the latter automatically).
- `LOCAL_LAMBDA_SERVER_ENABLED`, `LOG_LEVEL` — local dev / logging.

Secrets live in gitignored `.env`, `samconfig.toml`, and `.consumer-secrets/` — never commit them.

## Code style

- Swift 6 throughout; use current Swift 6 best practices.
- Prefer Swift Concurrency (`async`/`await`, actors, `Sendable`) over Dispatch or Combine.
- Match existing patterns: `Sendable` reference types instead of explicit actors, and the
  `URLProcessor` strategy-registry pattern for new per-collection URL logic (see
  [`.claude/rules/architecture.md`](.claude/rules/architecture.md) for how to add one).

## Gotchas

- The local Lambda binds port 7000; a stale process there means you're testing an old
  binary — free the port between runs.
- `sam build`/`docker` need the Docker socket, which isn't sandbox-allowlisted here — run
  with the sandbox disabled.
- `sam deploy`'s changeset y/N prompt has no tty in this environment — review the
  changeset, get explicit confirmation, then re-run with `--no-confirm-changeset`.
- The reviewer web app and the `CollectionReviewer` CLI both write the same collections
  file — never run both writers at once (see `collection-reviewer-web/lib/collectionsFile.ts`).
- `template.yaml` deliberately sets **no** `ReservedConcurrentExecutions` on either
  function (the account's Lambda concurrency quota is already only 10, fully unreserved) —
  don't describe concurrency as reserved/limited per-function.
- Routing a new collection through the converter requires adding its host to
  `ALLOWED_HOSTS` and redeploying the converter; pure `URLProcessor` strategy changes don't.
- Compiled Swift binaries (e.g. running `CollectionLister` or `NZImageApiLambda` after
  `swift build`) fail DNS resolution under the command sandbox even for allowlisted hosts —
  same class of issue as the Docker gotcha above, but it also hits plain network calls made
  by a built binary, not just Docker. Run with the sandbox disabled.

## Where to read more

- [`.claude/rules/architecture.md`](.claude/rules/architecture.md) — Swift Lambda request flow, models, strategy-registry pattern.
- [`.claude/rules/build-test-deploy.md`](.claude/rules/build-test-deploy.md) — full build/test/deploy command reference and gotchas.
- [`.claude/rules/converter.md`](.claude/rules/converter.md) — the Python converter Lambda: contract, allowlist, local dev.
- `README.md` — end-user API reference and setup.
- `docs/ACCESS-CONTROL.md`, `docs/adr/0001-free-per-consumer-secrets.md` — auth model and cost-control design.
- `Research/highres/README.md`, `recipes.md`, `progress.json` — per-collection high-res findings.
- `Sources/Testing/CollectionTester/README-CollectionTester.md` — CollectionTester options.
