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

Stack name `nzimageapi`, region `ap-southeast-2`. Needs Docker for the Swift Lambda's Makefile
target — Docker commands need the sandbox disabled here, since the Docker socket isn't
sandbox-allowlisted. The converter and guard are .zips built by their own Makefiles
(`converter/Makefile`, `guard/Makefile`) with no Docker; the converter's `pip install` needs
network access to PyPI.

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

## Deploy artefact retention (cost control)

Every `sam deploy` uploads the packaged code (the Swift Lambda zip ~44 MB, the converter zip
~22 MB, the guard) and templates to S3, and versioning is on. Left unmanaged, deploy artefacts
were the account's only real recurring cost while the running stack sat at $0.00: by 2026-08-24
there were 29 converter images in ECR (~5.5 GB) and 1.45 GB in S3.

The converter was a container image until October 2026. ECR's free storage is a 12-month
offer this account no longer has, so even three retained images cost about $0.06 a month. It is
now a .zip, whose code storage Lambda includes for free, and the ECR repository is gone.

### `infra/bootstrap.yaml` owns the artefact bucket

The bucket and its retention policy are declared in **`infra/bootstrap.yaml`** and deployed as
the separate `nzimageapi-bootstrap` stack:

```bash
aws cloudformation deploy --region ap-southeast-2 --stack-name nzimageapi-bootstrap --template-file infra/bootstrap.yaml
```

**Why a separate stack and not `template.yaml`:** `sam deploy` uploads the packaged code and
template to S3 *before* CloudFormation runs, so a bucket declared in the stack that consumes it
would not exist yet at upload time.

`ArtifactRetentionDays` (default `60`) sets when artefacts expire; non-current versions go at 7
days, stalled multipart uploads at 7. A stack update failing more than 60 days after the deploy
that produced an artefact cannot roll back to it, which is well outside any realistic rollback
window here. The bucket carries `DeletionPolicy: Retain` / `UpdateReplacePolicy: Retain`.

### The wiring

The gitignored `samconfig.toml` points the main stack at the bucket with
`s3_bucket = "nzimageapi-sam-artifacts-686865771242-ap-southeast-2"` (which **replaces**
`resolve_s3 = true`; the two are mutually exclusive, and `resolve_s3` is what made SAM
auto-create its own unmanaged bucket). It no longer needs an `image_repositories` entry.

`.github/workflows/ci-cd.yml` cannot read `samconfig.toml`, so its deploy job reads the bucket
from the bootstrap stack's `ArtifactBucketName` output and passes it as `--s3-bucket`, failing
with a pointer to the bootstrap-deploy command if the stack or output is missing. It reads the
stack rather than a GitHub variable on purpose: a stale `CONVERTER_ECR_REPO` variable once kept CI
deploying into superseded, unmanaged stores. Never reintroduce `--resolve-s3` there.

### Prefer .zip over container images

Keep Lambdas as .zips (250 MB unzipped limit) so there is nothing in ECR to pay for. If a function
ever has to be a container image, it needs an `AWS::ECR::Repository` with a lifecycle policy in
`infra/bootstrap.yaml` (see git history before October 2026 for the old `ConverterRepository`),
plus an explicit `image_repositories` entry in `samconfig.toml` and `--image-repositories` in CI.
