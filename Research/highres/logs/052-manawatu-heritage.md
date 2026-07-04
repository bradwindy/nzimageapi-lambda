# 052 — Manawatū Heritage

- **Group:** B (add, not currently in the Lambda)
- **Platform:** **Recollect signed-IIIF** (new-generation, `curtis-production2-cache`) — the SAME
  platform as **Feilding Library (35)** and **Kete Horowhenua (51)**; front-end
  `manawatuheritage.pncc.govt.nz` (Palmerston North City Library)
- **DigitalNZ result_count:** 26,021 image-bearing (live, 2026-07-04; `rawItemCount` snapshot
  22,365 in the pre-investigation todo entry, now updated to the live count)
- **Timestamp:** 2026-07-04
- **Outcome:** **committed Group B ADD.** New Swift strategy `manawatuHeritageOriginal` resolves the
  item page's `download?variant=original` link, then probes its `Content-Type` with a ranged GET
  (not HEAD) and branches: a plain JPEG original is returned **directly** (Kete-style); anything
  else (TIFF) is routed through the self-hosted Pillow converter (Feilding-style). Falls back to the
  harvested signed-IIIF JPEG on any failure, including the ~15-20% of records that are multi-page/
  compound "album" parents whose own landing page has no direct file. `swift build` 0;
  `sam build && sam deploy` succeeded (in-place update, 3 `Modify`/0 replace); CollectionTester ×12
  + 6 live deployed-endpoint picks confirmed all three code paths firing correctly. weight 0.002.
  **User-approved 2026-07-04.**

## Raw record sample (key redacted)

| field | value |
|-------|-------|
| large_thumbnail_url | `https://d28dhd8eubcyz4.cloudfront.net/iiif/2/curtis-production2-cache%2F1%2F0%2F7%2F8512e5-c5d1-427e-b1b6-f648ddfc2d09%2Fresize_master_<hash>.jpg/full/!880,1024/0/default.jpg?sig=<sig>` |
| thumbnail_url | same shape at `/full/!440,512/` |
| landing_url | `https://manawatuheritage.pncc.govt.nz/item/<uuid>` |
| dc_identifier | `oai:curtis/<uuid>` — the same `curtis` OAI namespace tell as Feilding/Kete Horowhenua |
| content_partner | `["Palmerston North City Library"]` |
| rights | `By Attribution Alone` / `Some rights reserved` (mixed; some CC variants observed) |

## Current production strategy (baseline)

Not currently served — Manawatū Heritage is not in `NZImageApi.collectionWeights`.

## Live site investigation (Discovery Playbook)

- **Platform match confirmed independently:** identical CloudFront IIIF path shape
  (`iiif/2/curtis-production2-cache%2F<shard>%2F<uuid>%2Fresize_master_<hash>.jpg/full/!<w>,<h>/0/
  default.jpg?sig=<sig>`), identical signed-size tiers (`!440,512` thumb, `!880,1024` large), the
  same `oai:curtis/<uuid>` `dc_identifier` tell, and **`/full/max/` with the harvested signature
  still returns 403** — confirming sizes are individually signed and can't be forged, exactly as
  established at Feilding and Kete Horowhenua.
- **The item page HTML contains the same `/item/<uuid>/files/<fileId>/download?variant=original`
  link pattern.** Following it: 302 → `curtis-production2-store.s3.ap-southeast-2.amazonaws.com/
  <path>/<original-filename>?X-Amz-...` (a presigned GET URL).
- **★ Unlike either sibling, this collection is genuinely MIXED-FORMAT.** A 20-record census
  (uniform sample, `page = 40×n` for n=0..19) resolving each record's download link and reading its
  `Content-Type` via a ranged GET found: **14/20 `image/tiff`** (professional archival scans, up to
  73 MB observed), **3/20 `image/jpeg`** (including a donated smartphone photo — `HTC One X9 dual
  sim` EXIF, 2060×1760 — alongside larger professional JPEG scans), and **3/20 no download link at
  all**. Neither Feilding's "always TIFF" nor Kete Horowhenua's "always JPEG" assumption holds here
  — **the format must be checked per-record at request time**, reinforcing the "same platform ≠
  same converter need" lesson from Kete Horowhenua one step further: even within a single
  collection on this platform, the format is not uniform.
- **The "no download link" records are multi-page/compound "album" parent records**, not a fetch
  bug: e.g. `383321a9-913b-4418-b56b-cac46065b227` ("The Grandstand at the Manawatu Racing Club Race
  Course") is a **parent item with child pages** (`?child=<uuid>` links to `Page 1`, `Page 2`, …);
  its own "Download" modal section in the HTML is a genuinely empty `<div>` — the files live on the
  **child** item pages, not the parent DigitalNZ harvested one. Confirmed by inspecting the raw HTML
  (no `download-modal` content, no file/download regex match anywhere on the page). This affected
  3/20 in the census and 3/10 in the pixel survey (~15-20% combined) — an inherent site-structure
  limitation, not something worth chasing (the parent record IS what DigitalNZ harvested and IS what
  gets served; walking to an arbitrary child page would silently substitute a different image).
- **HEAD vs. ranged-GET gotcha (same as Kete Horowhenua/Te Papa):** the S3 presigned URL is signed
  for `GET` only; a `HEAD` returns 403. Content-Type detection therefore uses a **ranged GET**
  (`Range: bytes=0-0`) and reads the `Content-Type` response header — never downloads the body.
  Added a new `NetworkRequestManager.rangeContentType(endpoint:)` helper (returns `(status,
  contentType)`) alongside the existing `rangeStatusFollowingRedirects`.
- **Pixel-dimension survey (10 records across pages 15–735, mixed with the census):** 7/10 resolved
  a download link; **0 honest-smaller**, ratios **4.07×–32.28×** (median ≈**29×**); 3/10 were the
  same multi-page/compound no-link case (consistent with the census rate).

## Decision

**committed Group B ADD.** New strategy `manawatuHeritageOriginal`: resolve the item page's
`download?variant=original` link via one bounded HTML GET, then a ranged-GET Content-Type probe to
decide between direct-serve (JPEG) and converter-routing (anything else, i.e. TIFF). Falls back to
the harvested `!880,1024` signed IIIF JPEG on any failure (no landing URL, non-
`manawatuheritage.pncc.govt.nz` host, fetch failure, no download link found — including the
multi-page/compound case, the ranged-GET probe failing, or `JP2_CONVERTER_URL` unset for the
TIFF branch) — never a broken image, never a raw undisplayable TIFF.

## Implementation

- `Sources/NZImageApiLambda/Helpers/NetworkRequestManager.swift`: new
  `rangeContentType(endpoint:) async -> (status: Int, contentType: String?)` — a 1-byte ranged GET
  that also surfaces `Content-Type` (existing `rangeStatusFollowingRedirects` only returned status).
- `Sources/NZImageApiLambda/Helpers/URLProcessor.swift`: new `"Manawatū Heritage"` registry entry
  (dispatches to `manawatuHeritageOriginal`); new `private static func
  manawatuHeritageOriginal(_:_:)` helper (added after `keteHorowhenuaOriginal`).
- `Sources/NZImageApiLambda/NZImageApi.swift`: `collectionWeights["Manawatū Heritage"] = 0.002`
  (provisional, added after Kete Horowhenua).
- `template.yaml`: added `manawatuheritage.pncc.govt.nz` to the converter's `ALLOWED_HOSTS`
  (comma-separated env var on `Jp2ConverterFunction`) — **this required a redeploy** (unlike Kete
  Horowhenua, since this collection's TIFF majority needs the converter).
- No `Dockerfile` changes (TIFF support already asserted since Feilding).

## Verification

- `swift build`: exit 0.
- **Local:** `sam build` (converter image + Swift Lambda) succeeded; local converter stand-in
  (`converter/local_server.py`, with `manawatuheritage.pncc.govt.nz` added to its own
  `ALLOWED_HOSTS`) + `CollectionTester "Manawatū Heritage"` ×12: TIFF picks routed through the
  converter (all HTTP 200 `image/jpeg`, one verified at 4000×2518, 1.28 MB), one pick correctly fell
  back to the harvested baseline (a multi-page/compound record with no download link). The
  JPEG-direct branch was independently confirmed via the census's Content-Type data (record
  `3f483c4e-52d0-4b0c-80ab-6b94c7355b1c`, `image/jpeg`) — not hit by CollectionTester's random draw
  in the 12 local runs (consistent with its ~15-18% share of the pool), but confirmed live in
  production below.
- **Deployed:** `sam deploy` (in-place update — 3 `Modify` / 0 replace: `Jp2ConverterFunction`,
  `NZImageApiFunction`, `ServerlessHttpApi`; user confirmed the exact changeset before a
  non-interactive `--no-confirm-changeset` apply, since `sam deploy`'s interactive y/N prompt has no
  tty in this environment). Verified the live converter directly: the same TIFF record (28.7 MB
  master) → **2624×3652 JPEG**, HTTP 200. Verified the deployed `ImageApiEndpoint` (with the
  `secret` header, `collection=Manawatū Heritage`) across 6 live picks: **all three code paths
  fired** — (1) fallback to harvested IIIF (compound/no-link record), (2) direct JPEG passthrough
  (`…/download?variant=original` returned as-is — the donated-phone-photo case, verified **2060×1760
  real JPEG**, 527 KB), and (3) converter-routed TIFF (verified **2624×3652 real JPEG**, HTTP 200).
- **User approved both live URLs in a browser, 2026-07-04** (the direct-JPEG pick and the
  converter-routed TIFF pick).

## Example live URLs

- Direct JPEG (no converter):
  `https://manawatuheritage.pncc.govt.nz/item/22f1980d-f439-4007-b524-5c773c43ea9e/files/1d4632b0-ef51-4f90-a249-9bcb9377febe/download?variant=original`
  (2060×1760) — user-approved.
- Converter (TIFF → JPEG):
  `https://rpssr7pwlyvmpoinol3dbrx3ma0pcjaw.lambda-url.ap-southeast-2.on.aws/?url=https%3A%2F%2Fmanawatuheritage%2Epncc%2Egovt%2Enz%2Fitem%2F1c6e4885%2De04d%2D49d2%2Db538%2D24b24fa2d237%2Ffiles%2F0b7352d4%2D95f4%2D44e1%2D95f1%2D003b0d731c00%2Fdownload%3Fvariant%3Doriginal`
  (2624×3652) — user-approved.

## Commit

(recorded after this bookkeeping commit)
