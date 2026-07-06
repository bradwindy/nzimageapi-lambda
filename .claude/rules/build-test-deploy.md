# Build, test, and deploy reference

Read this when building, testing, or deploying — either component. For end-user API docs
and setup walkthroughs, see the root `README.md` instead of duplicating them here.

## Swift Lambda

```bash
swift build                    # build all targets (main Lambda + CLI tools)
swift test                     # XCTest suite: Tests/NZImageApiLambdaTests
```

Run locally (listens on `127.0.0.1:7000`; `LOCAL_LAMBDA_SERVER_ENABLED=true` is what
switches the runtime into local HTTP-server mode instead of polling the Lambda Runtime API):

```bash
DIGITALNZ_API_KEY=$DIGITALNZ_API_KEY API_CLIENT_SECRETS=dev:super_secret_secret \
  LOCAL_LAMBDA_SERVER_ENABLED=true ./.build/debug/NZImageApiLambda
```

Invoke it directly once running:

```bash
curl -X POST http://127.0.0.1:7000/invoke -d '{...APIGatewayV2 event JSON...}'
```

## CollectionTester (recommended way to validate a collection end-to-end)

```bash
./Sources/Testing/CollectionTester/test-collection.sh                       # random collection
./Sources/Testing/CollectionTester/test-collection.sh "Wellington City Recollect"
./Sources/Testing/CollectionTester/test-collection.sh --port 8000 "Canterbury Museum"
```

Builds the Lambda, boots it, makes a request, validates the JSON, checks the image URL is
actually fetchable, then shuts the server down. Full option list:
`Sources/Testing/CollectionTester/README-CollectionTester.md`.

## Reviewer web app

```bash
cd collection-reviewer-web && npm run dev          # incremental Swift build, boots Lambda on :7000 too
npm run dev:clean                                   # clean Swift build first
npm run dev:reuse                                   # skip Swift build, reuse an already-healthy Lambda
```

Reads `DIGITALNZ_API_KEY` from the repo-root `.env` (`collection-reviewer-web/scripts/dev.mjs`).
**Do not run this at the same time as the `CollectionReviewer` Swift CLI** — both mutate the
same collections file and only one writer can hold the mutex
(`collection-reviewer-web/lib/collectionsFile.ts`).

## SAM deploy (the real deploy path)

Stack name `nzimageapi`, region `ap-southeast-2`. Needs Docker (the Swift Lambda's Makefile
target and the converter's container image both build via Docker) — Docker commands need
the sandbox disabled here, since the Docker socket isn't sandbox-allowlisted.

```bash
sam build
sam deploy                     # will prompt a changeset y/N — see below
```

This environment has no tty for interactive prompts: show the user the changeset, get
explicit confirmation, then re-run with `sam deploy --no-confirm-changeset`.

Parameters (`DigitalNzApiKey`, `ApiClientSecrets`, `AlarmEmail`, `ConverterSigningKey`) come
from `--parameter-overrides` or the gitignored `samconfig.toml` — never hardcode or commit them.

## Legacy scripts (pre-SAM, not the current deploy path)

`scripts/deploy.sh`, `scripts/build.sh`, `scripts/package.sh` predate the SAM stack and drive
a manual `aws lambda update-function-code` flow. They still work for the Swift Lambda alone
but don't know about the converter Lambda or the SAM-managed resources (alarms, budget,
Function URL wiring) — prefer `sam build && sam deploy` for anything touching the full stack.
