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

## Deploy artefact retention (cost control)

Every `sam deploy` leaves permanent artefacts behind. Left unmanaged these are the account's
only real recurring cost, and they grow with every deploy while the running stack itself
(Lambda, API Gateway, CloudWatch, SNS, SQS) sits at $0.00.

Two things accumulate:

- **The converter's ECR repo.** Each deploy pushes a fresh ~195 MB image under a unique tag
  (`jp2converterfunction-<hash>-latest`), so nothing is ever overwritten. Only the one tag
  referenced by the deployed `Jp2ConverterFunction` is live.
- **The SAM artefact bucket.** Each deploy uploads the Swift Lambda zip (~44 MB) plus
  packaged templates, and versioning is on.

By 2026-08-24 that had reached 29 ECR images (~5.5 GB of manifests) and 75 S3 objects
(1.45 GB) from roughly 20 deploys since June 2026 - about $0.17/month and climbing, all of
it waste.

### `infra/bootstrap.yaml` owns both

Both resources, and both retention policies, are declared in **`infra/bootstrap.yaml`** and
deployed as the separate `nzimageapi-bootstrap` stack:

```bash
aws cloudformation deploy --region ap-southeast-2 --stack-name nzimageapi-bootstrap --template-file infra/bootstrap.yaml
```

**Why a separate stack and not `template.yaml`:** `sam deploy` pushes the container image to
ECR and uploads the packaged template to S3 *before* CloudFormation runs. A repo or bucket
declared in the stack that consumes them would not exist yet at push time. They have to be
created by something that runs first, hence a tiny bootstrap stack deployed on its own.

Retention is tunable via stack parameters rather than by editing policy JSON:

| Parameter | Default | Effect |
| --- | --- | --- |
| `ImageRetentionCount` | `3` | ECR keeps this many images. Newest is live, the rest are rollback targets. |
| `ArtifactRetentionDays` | `60` | S3 artefacts expire after this many days. Non-current versions go at 7 days, stalled multipart uploads at 7. |

The 60-day S3 window is deliberately generous. It does mean a stack update failing more than
60 days after the deploy that produced an artefact cannot roll back to it, which is well
outside any realistic rollback window here.

Both resources carry `DeletionPolicy: Retain` / `UpdateReplacePolicy: Retain`, so deleting or
replacing the bootstrap stack will not take the artefacts (or a bucket full of objects,
which would fail the delete anyway) with it.

### The wiring in `samconfig.toml`

The gitignored `samconfig.toml` points the main stack at the bootstrap stack's outputs:

```toml
s3_bucket = "nzimageapi-sam-artifacts-686865771242-ap-southeast-2"
image_repositories = ["Jp2ConverterFunction=686865771242.dkr.ecr.ap-southeast-2.amazonaws.com/nzimageapi/jp2converter"]
```

`s3_bucket` **replaces** `resolve_s3 = true` - the two are mutually exclusive, and
`resolve_s3` is what made SAM auto-create its own unmanaged bucket. Because `samconfig.toml`
is gitignored, this wiring is the one part that is not in version control; re-read the two
outputs after any bootstrap-stack change:

```bash
aws cloudformation describe-stacks --region ap-southeast-2 --stack-name nzimageapi-bootstrap --query 'Stacks[0].Outputs'
```

### The wiring in CI

`.github/workflows/ci-cd.yml` cannot read the gitignored `samconfig.toml`, so its deploy job
resolves the same two values itself, in a `Resolve bootstrap artefact stores` step that queries
the bootstrap stack's outputs and feeds them to `sam deploy` as `--s3-bucket` and
`--image-repositories`. The step fails the job with a pointer to the bootstrap-deploy command if
the stack is missing or either output is absent, so a misconfigured deploy never reaches the
push.

They are read from the stack rather than from GitHub repo/environment variables on purpose. The
job previously used `--resolve-s3` plus a `CONVERTER_ECR_REPO` environment variable, and that
variable still held the *pre-migration* companion-stack repo, so every CI deploy kept pushing a
~195 MB image into the unmanaged repo and a zip into a SAM-auto-created bucket while local deploys
correctly used the bootstrap stores. Reading the stack removes the copy that can go stale. If you
add another artefact store, add its output to `infra/bootstrap.yaml` and read it in the same step.

`CONVERTER_ECR_REPO` is no longer referenced by anything and can be deleted from the repository's
`production` environment.

### Superseded resources

The pre-migration artefact stores still exist and still hold their history:

- ECR `nzimageapi40221342/jp2converterfunctione92cbfdcrepo`, owned by the SAM-generated
  `nzimageapi-40221342-CompanionStack`.
- S3 `aws-sam-cli-managed-default-samclisourcebucket-tfqwkahyri86`, owned by the
  `aws-sam-cli-managed-default` stack.

Both had the same lifecycle policies applied imperatively on 2026-08-24, so they drain on
their own rather than sitting there forever. Leave them until a deploy against the new
repo and bucket is confirmed working and you are past wanting to roll back to an old image.

Note that CI kept writing to both of them until the deploy job was pointed at the bootstrap stack
(see "The wiring in CI" above), so their newest contents are more recent than the migration date
suggests.

### When adding a new container-image Lambda

A new `PackageType: Image` function does **not** automatically get a managed repo any more,
because `image_repositories` is now explicit. Add an `AWS::ECR::Repository` for it in
`infra/bootstrap.yaml` (copy `ConverterRepository`, including its `LifecyclePolicy`), deploy
the bootstrap stack, then add the new `<FunctionLogicalId>=<repoUri>` entry to
`image_repositories`. Skipping the lifecycle policy is how this problem started.
