# Converter Lambda

Read this when touching `converter/`, changing which collections route through it, or
debugging a signed-URL failure. For the security rationale behind signing/allowlisting,
see `docs/ACCESS-CONTROL.md` §10 ("Converter security") rather than duplicating it here.

## What it does

`converter/app.py` is a Python + Pillow Lambda behind a public **Function URL** (`AuthType: NONE`,
CORS open) that downloads a master image (JP2 via OpenJPEG, TIFF via libtiff) and returns a
displayable JPEG capped at `MAX_DIM` (default 4000px). It exists because the Swift Lambda is a
pure URL builder and never decodes image bytes itself.

It is a python3.13 arm64 **.zip** built by `converter/Makefile`, which installs Pillow's
`manylinux_2_28_aarch64` wheel (it bundles OpenJPEG and libtiff) on any build host. CI's deploy job
imports the built package on arm64 Python 3.13 and fails if either codec is missing.

## Timeouts

NDHA streams some masters to the Lambda at under 1 MB/s. The function timeout is 120 s and
`download_image` gives up after `DOWNLOAD_DEADLINE` (90 s) for the whole download, on top of the
per-socket `DOWNLOAD_TIMEOUT`, so a slow source ends as a logged `502 download failed` instead of
a silent function timeout. FL73848659 (45.8 MB, 7356×5010) is the known slow master.

## Kill switch (`guard/`)

The Function URL is public, so `ConverterGuardFunction` (`guard/app.py`) keeps the converter
inside Lambda's always-free allowance. It switches the converter off by setting its reserved
concurrency to 0 (every call is throttled, nothing is billed), and back on by deleting the
reservation:

- **Spike:** `nzimageapi-converter-invocations-high` (over `ConverterSpikeThreshold`, default 100,
  invocations in 5 minutes) emails `nzimageapi-cost-alarms` and, through the same topic, switches
  the converter off.
- **Hourly:** month-to-date usage from CloudWatch is checked against `GuardMaxGbSeconds` (320,000
  of the 400,000 free), `GuardMaxRequests` (800,000 of 1,000,000) and
  `GuardMaxConverterInvocations` (20,000, which keeps data transfer out under the free 100 GB at
  up to ~4 MB a response). Over any limit, it switches off. Under all of them with the spike alarm
  OK, it switches back on, which is how it recovers after a spike or at the start of a month.

Every switch is emailed to the cost-alarm topic. While the converter is off, converter URLs fail
and the slideshow skips those images. To switch it back on by hand:
`aws lambda delete-function-concurrency --region ap-southeast-2 --function-name <converter>`
(the next hourly run turns it off again if a limit is still reached).

## HMAC signer/verifier contract

- Swift side: `URLProcessor.signedConverterURL(for:)` (`Sources/NZImageApiLambda/Helpers/URLProcessor.swift`)
  builds `<JP2_CONVERTER_URL>/?url=<pct-encoded source URL>&sig=<hex HMAC-SHA256(CONVERTER_SIGNING_KEY, source URL)>`.
  Returns `nil` (graceful fallback to the unconverted URL) if either `JP2_CONVERTER_URL` or
  `CONVERTER_SIGNING_KEY` is unset — this is what makes local dev work without a converter deployed.
- Python side: `converter/app.py` recomputes the HMAC over the decoded `url` param with its own
  `CONVERTER_SIGNING_KEY` and rejects on mismatch, so the public Function URL only serves
  requests the Swift Lambda actually minted.
- Both sides read the **same** `CONVERTER_SIGNING_KEY` — it's a single shared secret, not a
  keypair. Rotating it requires redeploying both functions with the new value.

## Host allowlist

`ALLOWED_HOSTS` (comma-separated, set in `template.yaml`) gates which source hosts the
converter will fetch from, independent of the HMAC check. Currently: `ndhadeliver.natlib.govt.nz`
(NDHA/TAPUHI, War Art Online), `www.feildingheritage.nz`/`feildingheritage.nz` (Feilding Library
TIFF originals), `manawatuheritage.pncc.govt.nz` (Manawatū Heritage TIFF originals, which
302-redirect to a presigned S3 URL that's followed transparently).

**Adding a new converter-routed collection whose host isn't already listed requires adding it
to `ALLOWED_HOSTS` in `template.yaml` and redeploying the converter function** — a
`URLProcessor` strategy change alone won't work if the host is unlisted.

## Which collections route through it vs. direct-serve

- Through the converter (JP2/TIFF masters): TAPUHI (NDHA), War Art Online, Feilding Library, Manawatū Heritage.
- Direct-serve, no converter (JPEG-native or already-displayable): e.g. Kete-based collections.
Check `Research/highres/recipes.md` for the full per-collection breakdown.

## Local dev

`converter/local_server.py` runs the converter as a plain local HTTP server for testing
without a Lambda deploy. `converter/test_local.py` exercises it directly.
