# Converter Lambda

Read this when touching `converter/`, changing which collections route through it, or
debugging a signed-URL failure. For the security rationale behind signing/allowlisting,
see `docs/ACCESS-CONTROL.md` §10 ("Converter security") rather than duplicating it here.

## What it does

`converter/app.py` is a Python + Pillow Lambda behind a public **Function URL** (`AuthType: NONE`,
CORS open) that downloads a master image (JP2 via OpenJPEG, TIFF via libtiff) and returns a
displayable JPEG capped at `MAX_DIM` (default 4000px). It exists because the Swift Lambda is a
pure URL builder and never decodes image bytes itself.

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
