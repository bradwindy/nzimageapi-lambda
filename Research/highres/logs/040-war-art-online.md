# Order 40 — War Art Online

- **Group:** B (ADD — was NOT in `collectionWeights`, so never served)
- **Platform (progress.json):** `boutique` → **RECLASSIFIED to `ndha`** (NDHA / National Library Rosetta, holding institution **Archives New Zealand**; same delivery platform as National Publicity Studios 03 and TAPUHI 25)
- **rawItemCount (list):** 1,477 · **live (primary_collection / display_collection / collection, category=Images):** 1,477 (all three facets identical)
- **content_partner:** Archives New Zealand Te Rua Mahara o te Kāwanatanga · **rights:** Creative Commons BY 2.0 (open)
- **Status:** committed (user-approved 2026-06-14)
- **Strategy:** Group B ADD reusing the **existing self-hosted Pillow converter** (a generic JP2 **+ TIFF** master→JPEG proxy after TAPUHI 25 / Feilding 35) — **NO converter change, NO AWS redeploy** (the converter already host-allowlists `ndhadeliver.natlib.govt.nz` and already handles TIFF). New Swift `warArtConverter` strategy + `warArtMasterFLPID` METS picker + a `collectionWeights` entry.

## Identity

"War Art Online" is the DigitalNZ `primary_collection` **and** `display_collection` **and**
`collection` — all three return the same 1,477 Images. The Lambda queries
`and[primary_collection][]` + `and[category][]=Images` and dispatches on `result.collection`
(= `display_collection` = "War Art Online"), so the single key works.

The National Collection of War Art (NCWA) — WWI/WWII paintings & drawings held by Archives NZ.
Master TIFF filenames are `NCWA_*.tif`.

## Platform detection

Harvested `large_thumbnail_url` = `thumbnail_url` =
`https://ndhadeliver.natlib.govt.nz/NLNZStreamGate/get?dps_pid=IE<n>` — the **NDHA / Rosetta**
delivery shape (same host as National Publicity Studios 03 and TAPUHI 25). `object_url` null.
The served JPEG/TIFF carry the comment **"Produced by New Zealand Micrographic Services Ltd."**
(NZMS — the Recollect Ltd parent; here as Archives NZ's digitisation vendor).

**Landing page** `https://archives.govt.nz/images/<slug>` is **Incapsula/Imperva WAF-walled**
(returns a 212-byte JS-challenge stub; uncrawlable, like the Auckland Art Gallery 27 / Canterbury 26
WAF pages) — **no alternate hi-res route** there. The NDHA Rosetta METS is the authoritative source.

## ★ TIFF preservation master via the Rosetta METS (cf. TAPUHI 25, but TIFF not JP2)

Identical resolve to TAPUHI: `…/DeliveryManagerServlet?dps_pid=IE<n>&dps_func=mets` is a stateless
GET that enumerates every file (`<mets:amdSec ID="FL<n>-amd">` blocks with
`<key id="fileMIMEType">` + `<key id="fileSizeBytes">`). Each record carries a **DERIVATIVE_COPY**
representation (the access JPEG `NLNZStreamGate` serves) **and** a **PRESERVATION_MASTER**
representation = an `image/tiff` master (`NCWA_*.tif`, 8-bit RGB, uncompressed, **~5000 px, 40–65 MB**).

The master FL stream `…/DeliveryManagerServlet?dps_pid=FL<n>&dps_func=stream` returns the TIFF
**anonymously** (HTTP 200 `image/tiff`, a direct 200 — no S3 redirect, unlike Feilding 35). TIFF is not
browser-displayable, so it is routed through the **same converter** (TIFF→JPEG, downscaled ≤ 4000 px)
that TAPUHI (JP2) and Feilding (TIFF) use. `ndhadeliver.natlib.govt.nz` is **already in the deployed
converter's `ALLOWED_HOSTS`** (added for TAPUHI), so this is a **pure Swift change, no redeploy**.

## ★ Bimodal baseline — the one wrinkle (drove the user-chosen heuristic-passthrough)

The harvested access derivative (what `NLNZStreamGate/get?dps_pid=IE` serves) is **bimodal**, and the
Swift Lambda **cannot decode images** (the converter's whole reason to exist) so it cannot pixel-measure
the baseline at request time. The METS `techMD` carries `tiff:ImageWidth` only for the **master** (and
even that is unreliable — says 5287/4346 where the TIFF decodes to 5000), and the access JPEG's
`preservationType` is `DERIVATIVE_COPY` in **both** tiers → **no robust structural signal**. The only
no-decode signal is the access JPEG's `fileSizeBytes` (which exactly equals the served byte length).

| case | share | baseline (NLNZStreamGate) | master | decision |
|---|---|---|---|---|
| **1** (older IE1204… batch) | **~80 %** | **900 px** access JPEG (127–655 KB) | ~5000 px TIFF | **convert** → ~4000 px (**~20× area**) |
| **2** (newer IE257…/IE807… batch) | **~20 %** | **already ~5000 px** access JPEG (4347–5440 px, 586 KB–2.3 MB) | ~5000 px TIFF | **passthrough** native (converter's 4000 px would shrink it) |
| **3** (multi-page compilations) | **~1–2 %** | a **PDF** (`combinedPDF.pdf`) → not `<img>`-displayable | 19× ~5000 px TIFFs | **convert** the largest TIFF page (one displayable image) |
| outlier | 1/30 sampled | already ~6039 px access JPEG | **908 MB** TIFF | TIFF > 110 MB converter cap → **passthrough** the 6039 px baseline |

**Decision rule (`warArtMasterFLPID`, from the METS only — no extra fetch):**
1. No `image/tiff` ≤ `maxBytes` (110 MB, = converter download cap) → `nil` (passthrough; the 908 MB
   outlier lands here and serves its already-full-res baseline).
2. An `application/pdf` is present (Case 3) → convert the largest TIFF page.
3. Largest `image/jpeg` access ≥ `accessPassthroughThreshold` (**700 KB**) → `nil` (passthrough Case 2).
4. Else (Case 1) → convert the master TIFF.

The 700 KB threshold sits at the top of the thumbnail-tier byte cluster (Case 1 ≤ 655 KB in a 100-rec
sample) and below most full-tier (Case 2 ≥ 586 KB, median 1272 KB). The byte distributions overlap
slightly (the pixel gap 1452↔4347 px is clean, but bytes are not), so a **few-percent of boundary
records may render at 4000 px instead of native ~5000 px (or vice-versa)** — always **graceful, never
a broken image**. (User chose this "heuristic passthrough, pure Swift" over always-convert and over a
converter-decides redeploy.)

## Measurements (Discovery Playbook)

**Uniform 30-record survey** (master presence + size + MIME, via METS):
- master present: **30/30 (100 %)** · MIME (all FL): `image/tiff` 50, `image/jpeg` 48, `application/pdf` 1.
- master size: min **40.3 MB**, median **53.5 MB**, max **908.5 MB** (1 outlier > 110 MB); **0** JP2.

**Uniform 100-record baseline survey** (`NLNZStreamGate/get`, decoded longest side + content-length):
- Case 1 small (< 4000 px): **80 %** — width 900–1452 px (median 900), 127–655 KB.
- Case 2 big (≥ 4000 px): **20 %** — width 4347–5440 px (median 5000), 586–2256 KB.
- Case 3 PDF: 0 in this sample (~1–2 % overall). **Threshold gap:** Case 1 max 655 KB vs Case 2 min
  586 KB → small overlap (graceful, as above).

**Pixel sub-sample (real converter decode of the master):**
- Case 1: baseline 900×576 / 900×635 / 900×483 → converter **4000×2558 / 4000×2822 / 4000×2146**
  → area ratio **19.7×–19.8×**.
- Case 2 (IE25707818): baseline **5000×3531**, converter 4000×2825 = **0.6×** → confirms passthrough is right.

## Decision

**Group B ADD via the existing converter** — convert the ~5000 px TIFF master to ≤ 4000 px JPEG for the
~80 % small-baseline records (~20× win), passthrough the native ~5000 px JPEG for the ~20 % already-full-res
records, convert one TIFF page for the ~1–2 % PDF compilations, and gracefully fall back to the harvested
baseline on any failure. **No converter code change, no AWS redeploy.**

## Implementation

- `URLProcessor.swift` — registry entry `strategies["War Art Online"] = { await warArtConverter(...) }`;
  new `warArtConverter` (mirrors `tapuhiConverter`), `resolveWarArtFLStreamURL` (IE → METS → decide),
  and `warArtMasterFLPID` (the bimodal-aware METS picker). TAPUHI's `largestTapuhiJP2PID` left untouched
  (zero regression risk; the new picker is a parallel function).
- `NZImageApi.swift` — `collectionWeights["War Art Online"] = 0.002` (provisional rawItemCount-share).
- `progress.json` — platform `boutique` → `ndha`; status; baseline / chosen / notes.

## Verification

- `swift build` exit 0.
- CollectionTester ×8 → **7 converter + 1 passthrough, all HTTP 200** (`display_collection`="War Art
  Online" confirms dispatch). Converter picks FL12041803/FL12040183/FL12041022/FL12044011/FL12042235/
  FL25612335/FL12039635; passthrough pick IE25707508.
- Local converter `curl | sips`: FL12041803 → **4000×3173** (12.7 MP, 1.6 MB), FL12044011 → 3068×4000
  (2.7 MB), FL25612335 → 2580×4000 (1.5 MB). Passthrough IE25707508 → **5000×4745** (23.7 MP, native).
- **LIVE deployed converter** (`rpssr7pwlyvmpoinol3dbrx3ma0pcjaw.lambda-url.ap-southeast-2.on.aws`):
  FL12045354 → 200 `image/jpeg` **4000×2558** (5.7 s), FL12041803 → 4000×3173 (7.3 s),
  FL12044775 → 4000×2822 (6.3 s) — all well under the 60 s Lambda timeout.
- Regression: pure code change reusing the deployed converter; TAPUHI 25 / Feilding 35 paths untouched.

## Example live URLs (for the approval gate)

- canonical *"The battle of Polygon Wood"* (IE12045352): baseline `…/NLNZStreamGate/get?dps_pid=IE12045352`
  (900×576) → converter `…lambda-url…/?url=<FL12045354 stream>` (**4000×2558, ~19.7×**).
- Case-2 passthrough (IE25707508): `…/NLNZStreamGate/get?dps_pid=IE25707508` served native (**5000×4745**).

(Converter output is a normal JPEG that renders in `<img>`; the raw FL stream is a TIFF and is NOT
served to the browser — only the converter URL is.)

## Commit

- Change commit: "War Art Online (40): committed Group B ADD …" (Swift `warArtConverter`/
  `resolveWarArtFLStreamURL`/`warArtMasterFLPID` + weight reusing the deployed converter +
  `Research/highres/` bookkeeping). The SHA is recorded by the follow-up "Record SHA … for collection 40"
  commit.
