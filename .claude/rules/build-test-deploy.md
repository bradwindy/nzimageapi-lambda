# Build, test, and deploy reference

Read this when building, testing, or deploying any part. For end-user API docs
and setup walkthroughs, see the root `README.md` instead of duplicating them here.

## API Worker (`worker/`)

```bash
cd worker
npm ci
npm test                 # Vitest inside workerd (@cloudflare/vitest-plugin), outbound fetches mocked with MSW
npm run typecheck        # src, test and scripts
npm run dev              # wrangler dev on http://127.0.0.1:8787, secrets from worker/.dev.vars
npm run cf-typegen       # regenerate worker-configuration.d.ts after editing wrangler.jsonc
```

### Validating collections end-to-end

`check-collections` replaces the old CollectionTester. It requests `/image` for every collection
(or each `--collection`), checks the JSON and that the image URL loads, and exits 1 on any failure:

```bash
NZIMAGE_API_SECRET=... npm run check-collections -- --base-url https://nzimages-api.iolab.nz
NZIMAGE_API_SECRET=... npm run check-collections -- --collection "Feilding Library"   # against wrangler dev
```

`--compare-url <base>` also queries a second deployment and reports whether both return the same
URL shape (records are random, so a master-vs-fallback difference can be legitimate).

### Deploying the Worker

Workers Builds deploys `worker/` (its root directory) on every push to `main`, running the
tests first. By hand:

```bash
npx wrangler deploy
npx wrangler secret put API_CLIENT_SECRETS      # or DIGITALNZ_API_KEY, CONVERTER_SIGNING_KEY
```

`secrets.required` in `wrangler.jsonc` makes a deploy fail until all three secrets exist. A new
Worker's first deploy therefore uploads them with `--secrets-file <file outside the repo>`.
Secret changes take effect immediately, with no redeploy. `JP2_CONVERTER_URL` is a plain var in
`wrangler.jsonc`, set to the stack's `Jp2ConverterUrl` output.

Free plan limits that shape the code: 100,000 requests a day for the whole account, 10 ms CPU
and 50 subrequests per request. See CLAUDE.md's gotchas.

## Reviewer web app

```bash
cd worker && npm ci                                # once
cd ../collection-reviewer-web && npm run dev       # boots the API Worker on :8787, then Next.js
```

`scripts/dev.mjs` reads `DIGITALNZ_API_KEY` from the repo-root `.env`, starts `wrangler dev` with a
dev-only consumer secret (`dev:super_secret_secret`, which `lib/imageApi.ts` sends), and reuses an
API that is already healthy on the port. `CONVERTER_SIGNING_KEY` is not set there, so
converter-routed collections show their harvested URL. **Do not run `npm run update-collections`
while the app is running**: both write the same collections file and only one writer can hold
the mutex (`collection-reviewer-web/lib/collectionsFile.ts`).

## Converter and kill switch (SAM)

```bash
(cd converter && pip install -r requirements-dev.txt && pytest)
(cd guard && pip install -r requirements-dev.txt && pytest)
```

Stack name `nzimageapi`, region `ap-southeast-2`. GitHub Actions deploys it on every push to
`main` (`.github/workflows/ci-cd.yml`: tests, `sam build`, a codec check on the built converter,
`sam deploy`). By hand:

```bash
sam build                      # needs network access to PyPI (run unsandboxed here)
sam deploy                     # will prompt a changeset y/N, see below
```

This environment has no tty for interactive prompts: show the user the changeset, get explicit
confirmation, then re-run with `sam deploy --no-confirm-changeset`.

Parameters (`ConverterSigningKey`, `AlarmEmail`, and the `Converter*`/`Guard*` thresholds) come
from `--parameter-overrides` or the gitignored `samconfig.toml`. Never hardcode or commit them.
`ConverterSigningKey` must match the Worker's `CONVERTER_SIGNING_KEY` secret.

## Deploy artefact retention (cost control)

Every `sam deploy` uploads the packaged code (the converter zip
~22 MB, the guard) and templates to S3, and versioning is on. Left unmanaged, deploy artefacts
were the account's only real recurring cost while the running stack sat at $0.00: by 2026-08-24
there were 29 converter images in ECR (~5.5 GB) and 1.45 GB in S3.

The converter was a container image until October 2026. ECR's free storage is a 12-month
offer this account no longer has, so even three retained images cost about $0.06 a month. It is
now a .zip, whose code storage Lambda includes for free. Removing `ConverterRepository` from
`infra/bootstrap.yaml` does not delete the repository (it was `DeletionPolicy: Retain`), so after
the first .zip deploy replaced the image function, the bootstrap stack was redeployed and
`nzimageapi/jp2converter` was deleted by hand with
`aws ecr delete-repository --region ap-southeast-2 --repository-name nzimageapi/jp2converter --force`.

### `infra/bootstrap.yaml` owns the artefact bucket

The bucket and its retention policy are declared in **`infra/bootstrap.yaml`** and deployed as
the separate `nzimageapi-bootstrap` stack:

```bash
aws cloudformation deploy --region ap-southeast-2 --stack-name nzimageapi-bootstrap --template-file infra/bootstrap.yaml
```

**Why a separate stack and not `template.yaml`:** `sam deploy` uploads the packaged code and
template to S3 *before* CloudFormation runs, so a bucket declared in the stack that consumes it
would not exist yet at upload time.

`ArtifactRetentionDays` (default `60`) sets when artefacts expire. Non-current versions go at 7
days, stalled multipart uploads at 7. A stack update failing more than 60 days after the deploy
that produced an artefact cannot roll back to it, which is well outside any realistic rollback
window here. The bucket carries `DeletionPolicy: Retain` / `UpdateReplacePolicy: Retain`.

### The wiring

The gitignored `samconfig.toml` points the main stack at the bucket with
`s3_bucket = "nzimageapi-sam-artifacts-686865771242-ap-southeast-2"` (which **replaces**
`resolve_s3 = true`. The two are mutually exclusive, and `resolve_s3` is what made SAM
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
