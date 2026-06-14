# 035 — Feilding Library

- **Order:** 35
- **Group:** B (candidate **new** collection — was NOT in the Lambda)
- **Platform:** **Recollect Ltd new-generation signed-IIIF** (vendor **Recollect Ltd**, `recollectcms.com`;
  cache identifier `curtis-production2-cache`; CloudFront IIIF + presigned-S3 originals). This is the **newer
  product generation of the same vendor** as the older **`*.recollect.co.nz` `downloadwiz`** pipeline
  (orders 1/6/7/8/10/…) — **one vendor (Recollect Ltd / NZMS), two generations**, NOT two vendors and **NOT
  Axiell** (vendor corrected 2026-06-14). (progress.json `platform` reclassified `boutique` → `recollectIIIF`.)
- **DigitalNZ result_count (Images):** 3,585 (rawItemCount in progress.json).
- **Status:** **committed** — Group B ADD; **deployed + verified live on AWS**; user-approved 2026-06-12.
- **Date:** 2026-06-12

## Baseline (what shipped before)

**Nothing** — Feilding was **not in `collectionWeights`**, so the weighted-random picker never selected it;
the collection was never served in production. Had it been served via the `switch` `default:` passthrough it
would have returned the harvested `large_thumbnail_url`: a **CloudFront-signed IIIF derivative confined to the
site's `!880,1024` box (≈880×886, ~0.78 MP)**:

```
https://<dist>.cloudfront.net/iiif/2/curtis-production2-cache%2F6536%2F…%2Fresize_master_<hash>.jpg/full/!880,1024/0/default.jpg?sig=…&ver=…
```

## Source site

- **Landing:** `https://www.feildingheritage.nz/item/<uuid>` (Recollect Ltd `recollectcms.com` front-end).
- **Harvested image:** the CloudFront-signed `/iiif/2/…/full/!880,1024/0/default.jpg?sig=…` derivative.
- **True original:** the item page exposes `…/item/<uuid>/files/<fileId>/download?variant=original`, which
  **302-redirects to a short-lived (~1 h) presigned S3 URL** serving the **original TIFF** (e.g.
  **4969×5000, ~25 MP, ~75 MB**, RGB, uncompressed). The OpenSeadragon `data-dzi` descriptor confirms the
  native size. `object_url` null; rights sampled **public** (anonymous original-download works).

## Discovery Playbook (all avenues)

**A. Web research.** `recollectcms.com` / `curtis-production2-cache` / signed CloudFront IIIF ⇒ **Recollect
Ltd** (the NEW-generation product), the same vendor's newer generation vs the older **`*.recollect.co.nz`
`downloadwiz`** sites. (Vendor = **Recollect Ltd / NZMS**, NOT Axiell — corrected 2026-06-14.)
The `recollectLargest` family does **not** apply (no `/assets/downloadwiz/`, no `/assets/display/`).

**B. Page-source / DZI / info.json.** The item page's OpenSeadragon `data-dzi` descriptor gives the native
master dimensions (e.g. 4969×5000). The `/item/<uuid>/files/<fileId>/download?variant=original` link is in
the page HTML — **the `<fileId>` exists ONLY in the page**, not derivable from the harvested URL.

**C. Viewers.** OpenSeadragon tiles the signed IIIF derivative; the viewer's "download original" is the
`download?variant=original` route.

**D. URL / variant mutation — DEAD END (the key finding).** **The CloudFront signature is bound to the exact
derivative path.** Mutating `/full/!880,1024/` → `/full/max/` returns **HTTP 403 `SignatureDoesNotMatch`**.
The site only ever pre-signs **`{!440,512, !880,1024, !1170,1170}`**; `!1170,1170` (≈1163×1170, **1.36 MP**)
is the largest displayable JPEG it exposes publicly. **Larger IIIF sizes cannot be forged.**

**E. Alternate host/source — the win.** The `download?variant=original` → presigned-S3 **TIFF original**
(~25 MP) is the true ceiling, ~32× the harvested `!880,1024` (0.78 MP).

**F. Dead/Wayback.** N/A (live route).

**G. Proxy / format toolbox — both fail.** **TIFF is not browser-displayable**, and the **~75 MB file is too
large for weserv (it 504s)**. So neither a raw URL nor weserv works → must self-convert.

## Decision — route through the existing self-hosted Pillow converter (JP2 + now TIFF)

**User decision (2026-06-12):** serve the **~25 MP TIFF original, downscaled to a displayable ≤4000 px JPEG,
via the existing self-hosted Pillow converter Lambda** (the one TAPUHI order 25 uses for JP2) — extended to
also decode **TIFF** and to accept a **multi-host allowlist**. Strategy kept **Feilding-specific** but
structured to extend (Manawatū Heritage 52 likely reuses it; see Follow-up).

**Why the converter (not weserv/direct):** weserv 504s on the 75 MB TIFF; browsers can't render TIFF; the
signed IIIF `!1170` ceiling (1.36 MP) wastes the 25 MP master the site actually holds.

## Implementation

- **`converter/app.py`** — `ALLOWED_HOST` → multi-host **`ALLOWED_HOSTS`** (comma-separated `frozenset`;
  singular still honoured for back-compat). Only the **entry** host is allowlisted; the converter then
  follows the 302 to the (trusted-origin-chosen) presigned S3 store itself (so the served URL stays short and
  the presigned URL never expires in transit). `DOWNLOAD_TIMEOUT` made env-configurable (default 20→**35**).
  **TIFF needs NO new decode logic** — the generic `convert_to_jpeg` already covers it: the `JPEG2000`
  `image.reduce` branch is skipped for TIFF; `image.load()`; RGB passes through, exotic modes (CMYK/16-bit)
  hit `convert("RGB")`; the LANCZOS thumbnail to ≤4000 px + the under-6-MB budget loop are shared.
- **`converter/Dockerfile`** — added a hard build-time assert `features.check('libtiff')` alongside the
  existing `jpg_2000` assert (a wheel without TIFF now fails the build deterministically). **Verified passing
  in the real `sam build` image build** (Pillow 11.3.0, cp313 aarch64).
- **`template.yaml`** — converter env `ALLOWED_HOST` → `ALLOWED_HOSTS:
  "ndhadeliver.natlib.govt.nz,www.feildingheritage.nz,feildingheritage.nz"`. `MAX_DIM` stays 4000. No rename
  of `Jp2ConverterFunction` / `JP2_CONVERTER_URL` (avoids breaking existing wiring).
- **`URLProcessor.swift`** — new non-throwing **`feildingConverter`** strategy + registry entry
  `"Feilding Library"`. Mirrors `tapuhiConverter`: one bounded HTML GET of `result.landingUrl` via
  `NetworkRequestManager().fetchHTML`, regex
  `/item/[0-9a-f-]+/files/[0-9a-f-]+/download\?variant=original`, rebuild the absolute download endpoint from
  the landing scheme+host, return `<JP2_CONVERTER_URL>/?url=<download endpoint percent-encoded with
  .alphanumerics>`. **Graceful fallback to the harvested signed `!880,1024` JPEG** on ANY failure (no landing
  URL, host not `feildingheritage.nz`, `JP2_CONVERTER_URL` unset, `fetchHTML` throws, or **no
  `download?variant=original` link** = login-walled/restricted record). Never weserv, never a raw TIFF.
- **`NZImageApi.swift`** — added `collectionWeights["Feilding Library"] = 0.002` (provisional rawItemCount
  share; renormalized in the final weights pass).

## Measurements

- **Local converter unit path:** fetched the **74.5 MB** TIFF (following the 302 to S3) in ~6.8 s →
  `convert_to_jpeg` → **JPEG 3975×4000 (15.9 MP), 3.50 MB** (base64 ≈4.67 MB < 6 MB cap), convert ~0.25 s.
- **Local `CollectionTester "Feilding Library"` ×6** (incl. the first run) — **6/6 routed through the converter,
  all HTTP 200 `image/jpeg`** (none fell back): measured outputs **1800×1200 (2.16 MP, honest small native),
  2443×4000 (9.8 MP), 4000×3174 (12.7 MP), 4000×3358 (13.4 MP)** — all ≥ the 0.78 MP harvested baseline, big
  masters downscaled to ≤4000 px long side, **never upscaled**.
- **Live deployed `/image?collection=Feilding%20Library` ×3** + 1 direct converter test — **4/4 HTTP 200
  `image/jpeg`, multi-MP:** Stanway School 1898 **4000×3358 (13.4 MP)** in 5.45 s cold (byte-identical to the
  local result), Macarthur Street **4000×3000 (12 MP)**, "Feilding" panorama **4000×1682 (6.7 MP)**,
  Manawatū-Oroua Electric Power Board **3397×1845 (6.3 MP, honest native < 4000)**. Warm picks of small/medium
  masters were sub-1.5 s.
- **TAPUHI regression:** `converter/test_local.py` PASS — canonical FL73782300 → **3737×2148 (8.0 MP)**,
  byte-identical to before (back-compat confirmed).

## Routes table

| route | result |
|-------|--------|
| harvested `…/full/!880,1024/…?sig=` (baseline) | ≈880×886 (0.78 MP) signed JPEG — long-lived sig, always 200 (the fallback) |
| `…/full/max/…?sig=` (forge larger IIIF) | **403 `SignatureDoesNotMatch`** (path-bound signature) |
| `…/full/!1170,1170/…?sig=` (largest pre-signed) | ≈1163×1170 (1.36 MP) — public JPEG ceiling, still tiny vs the master |
| `…/files/<fileId>/download?variant=original` | **302 → presigned S3 → original TIFF (~25 MP, ~75 MB)** — not browser-displayable, weserv 504s |
| `<converter>/?url=<download endpoint>` (CHOSEN) | **TIFF → JPEG ≤4000 px, HTTP 200 `image/jpeg`** (up to ~16 MP), Feilding-specific `feildingConverter` |

## Deploy (this session)

- **`sam build`** — converter image built (the `libtiff` assert **passed**); Swift arm64 cross-compile
  succeeded (`provided.al2`).
- **Changeset reviewed then executed** (the blind `--no-confirm-changeset` apply was correctly blocked; a
  reviewable `--no-execute-changeset` changeset was generated, shown, user-approved, then
  `execute-change-set`). **3 in-place `Modify` ops, `Replacement: False` for all** (`Jp2ConverterFunction`,
  `NZImageApiFunction`, `ServerlessHttpApi`) — no replacements/deletions. Stack `nzimageapi`, ap-southeast-2,
  account 686865771242 → **UPDATE_COMPLETE**.
- Stack outputs **unchanged** from the TAPUHI deploy (in-place update):
  - `Jp2ConverterUrl` = `https://rpssr7pwlyvmpoinol3dbrx3ma0pcjaw.lambda-url.ap-southeast-2.on.aws/`
  - `ImageApiEndpoint` = `https://zk9rlj3um2.execute-api.ap-southeast-2.amazonaws.com/image`
- **NoEcho secrets** (`DigitalNzApiKey`, `ApiSecret`) sourced from gitignored `.env`; SAM masked them as
  `*****` (never logged/committed).

## Risks / edge cases

- **Login-walled records** (restricted rights): no public `download?variant=original` → graceful fallback to
  the `!880,1024` harvested JPEG. **Not observed in the sample** (all sampled public-rights items resolved
  anonymously); the fallback path is intact for the rare restricted record.
- **Per-request latency:** a cold converter pick = landing GET (~0.5–1 s) + TIFF download + decode
  (~7–9 s for the big ~75 MB masters; smaller masters seconds). Mitigated by `Cache-Control: immutable`
  (browser/CDN cache on repeat). Acceptable for a random-image API.
- **6 MB Function URL cap:** respected — 4000 px JPEG ≈3.5 MB raw / ≈4.7 MB base64; the budget loop
  (q85→q75→≤3000 px) drops quality/size if a record ever exceeds it.
- **Atypical TIFFs** (16-bit, CMYK, multi-page): `convert("RGB")` + first-frame default cover the common
  cases; rare exotic TIFFs that fail decode → converter 502 (no fallback at that point, the URL is already
  handed to the browser). Low risk for these RGB archival scans.
- **`DOWNLOAD_TIMEOUT`** default 35 s (env-overridable to 45) so the 75 MB fetch fits under the 60 s Lambda
  timeout; TAPUHI JP2 (~60 MB) unaffected.

## Conclusion

**ADD — committed (user-approved 2026-06-12).** Feilding is a **Group B** candidate not previously in the
Lambda, on **Recollect Ltd's new-generation signed-IIIF** platform. The harvested signed IIIF derivative is
hard-capped at ≈880×886 (0.78 MP) and **larger IIIF sizes cannot be forged** (path-bound CloudFront
signature; public ceiling `!1170,1170` = 1.36 MP). The 25 MP TIFF original (via
`download?variant=original` → presigned S3) is **not browser-displayable and too large for weserv**, so it is
routed through the **existing self-hosted Pillow converter Lambda — now a generic master→JPEG proxy (JP2 +
TIFF)** — which downscales it to a ≤4000 px JPEG (up to ~16 MP, ~20× the baseline). Graceful fallback to the
signed `!880,1024` JPEG on any failure. Weight 0.002 provisional.

## Follow-up

- Provisional weight **0.002** — recompute in the **final weights renormalization pass**.
- **Manawatū Heritage (order 52)** is run by the *same* Manawatu District Libraries and is **very likely the
  identical Recollect Ltd signed-IIIF pipeline**; **Kete Horowhenua (51)** and other "Heritage" todo sites may
  be too. Reuse = add the site's landing domain to the converter `ALLOWED_HOSTS` + one registry entry pointing
  at a shared helper (generalize `feildingConverter`). **Confirm per-collection; do not assume.**
- The converter is now a generic master→JPEG proxy (JP2 + TIFF). Streaming the full ~5000 px (200 MB Function
  URL limit) would need the Lambda Web Adapter — out of scope; noted as a future option only.
