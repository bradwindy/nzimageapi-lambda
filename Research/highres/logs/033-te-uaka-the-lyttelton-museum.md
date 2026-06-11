# 033 — Te Ūaka The Lyttelton Museum

- **Order:** 33
- **Group:** B (candidate **new** collection — was NOT in the Lambda)
- **Platform:** **Live eHive** (Vernon Systems / NZMuseums front-end), account **5362**. (progress.json
  `platform` reclassified `boutique` → `ehiveIIIF`.)
- **DigitalNZ result_count (Images):** 18,588 (rawItemCount in progress.json 18,588)
- **Status:** **committed** — ADD (new collection added to the Lambda via `ehiveIIIFLargest`)
- **Date:** 2026-06-12

## Baseline (what shipped before)

**Nothing** — Te Ūaka was **not in `collectionWeights`**, so the weighted-random picker
(`DigitalNZAPIDataSource.swift:50`, `collectionWeights.weightedRandomPick()`) never selected it; the
collection was never served in production. (Had it been served via the `switch` `default:` passthrough, it
would have returned the eHive `_l` 800 px derivative.) "Te Ūaka" is a recent rebrand of the **Lyttelton
Museum**, added to DigitalNZ after the original 2024 `collectionWeights` snapshot — hence its absence.

## Source site

- Images: `https://images.ehive.com/accounts/5362/objects/images/<id>_<size>.jpg` — `_l` (800 px) is the
  harvested `large_thumbnail_url`; `_m` is the thumbnail. Image ids are a mix of **32-hex** (newer uploads)
  and **older non-hex tokens** (e.g. `ji3o28_cpap`, `13jcqnp_97mc`).
- **IIIF master:** `https://iiif.ehive.com/iiif/2/accounts%2f5362%2fobjects%2fimages%2f<id>.tif/...`;
  `/full/full/0/default.jpg` returns the native master as a browser JPEG, no sign-in.
- Landing: `https://www.teuaka.org.nz/online-collection/<objectId>` (the museum's own site; the eHive
  catalogue is embedded). `object_url` null; `dc_identifier` = accession + `ehiveaccountid:5362`.

## Discovery Playbook (all avenues)

**A. Web research.** `images.ehive.com/accounts/5362/...` ⇒ **eHive** — the **3rd `boutique`-mislabel-
actually-eHive in a row** (cf. Te Hikoi 31 / Te Toi Uku 32). Same platform as Mataura/Howick/Portrait
Gallery. Per eHive docs the public master is either an 800 px cap or higher-res via the IIIF service.

**B. Page-source / info.json.** `iiif.ehive.com/.../<id>.tif/info.json` gives the master canvas. Te Ūaka's
masters are **mixed, not a single cap**: an 800 px batch, a 1000 px batch, and a **full 4000×3000 (12 MP)
batch** (the `cpa*`-token uploads). info.json for a 4000 px record shows a full pyramid
(125→250→500→1000→2000→4000) and 6 scaleFactors (1–32) — a genuine deep-zoom master.

**C. Viewers.** OpenSeadragon on each object page tiles the same `iiif.ehive.com` master.

**D. URL / variant mutation.** Larger `images.ehive.com` suffixes don't exist (500). **IIIF upscales on
demand** — `full/6000,/` → 6000 px (interpolated from the 4000 px master, fake). The honest ceiling is
**`full/full`** (= `full/max` = the true master), which `ehiveIIIFLargest` uses.

**E. Alternate host/source.** True original (≤ 20 MB, sign-in-only) — the public IIIF master is the best
anonymous route. For the `cpa*` batch that master is already a full 12 MP.

**F. Dead/Wayback.** N/A (live route).

**G. Toolbox.** N/A — `full/full` is already a browser-displayable JPEG (`image/jpeg`).

## Measurements

- **Master-size distribution (120-record sample spread across the FULL collection, 20 pages):** long side
  **min 800, max 4000, median 1000, mean 1370**. Buckets: **≤ 800 → 48 (40%)**, **1000 → 54 (45%)**,
  **4000 → 18 (15%)**. So **72/120 (60%) gain**, 48/120 (40%) parity, **0 worse, 0 failures**; mean winner
  gain ×2.19 linear, max ×5.00 linear (×25 area). (NB: an initial hex-only regex **biased** the sample to
  the 1000 px-capped newer uploads — the non-hex `cpa*` ids carry the 4000 px masters; corrected by using
  the actual `ehiveIIIFLargest` transform logic, drop only the last `_<size>`.)
- **The 4000 px masters are real native** (not upscaled): info.json `sizes` max = 4000, `full/full` ==
  `full/max` == 4000×3000 (~1.4 MB), and `full/6000,` upscales to a fake 6000 px — so 4000 is the true
  ceiling for that batch.
- **Parity / health:** `_l` 200 → 120/120; IIIF `full/full` 200 → 120/120; **0 honest-smaller anomalies**.
- **Non-hex ids handled:** `ji3o28_cpap_l.jpg` → IIIF `ji3o28_cpap.tif` = 4000×3000; `13jcqnp_97mc_l.jpg`
  → 800×600. `ehiveIIIFLargest` drops only the last `_<size>` segment, so both id styles map correctly.
- **Headers (IIIF):** `content-type: image/jpeg`, no `Content-Disposition` (inline), CORS `*`, 1-yr cache,
  CloudFront-backed.
- **Live pipeline (`CollectionTester` ×4, HTTP 200 image/jpeg):** 972×1000, **800×600 (non-hex parity
  record)**, 1000×765, 997×1000 — all vs `_l` ~800; plus the verified 4000×3000 `cpa` master.

## Conclusion

**ADD — committed (user-approved 2026-06-12).** Te Ūaka is a **Group B** candidate that was not in the
Lambda. Added it via the existing proven **`ehiveIIIFLargest`** (IIIF `full/full` over the master TIFF) and
added it to **`collectionWeights`** at a **provisional 0.009** (= its rawItemCount share of the current
in-Lambda corpus, 18 588 / 1 998 395; to be renormalized in the final weights pass). The eHive masters are
**mixed**: ~40% 800 px (parity), ~45% 1000 px (×1.56 area), and **~15% full 4000 px / 12 MP (×25 area)** —
the strongest of the three new eHive collections (31–33) because a real high-res batch exists. **60% gain,
0 worse, 0 failures.** Pure URL construction. `swift build` 0; CollectionTester ×4 HTTP 200.

## Follow-up

- Provisional weight **0.009** — recompute in the **final weights renormalization pass**
  (`weight_i = rawItemCount_i / Σ rawItemCount` over kept collections, sum → 1.000).
- Re-check only if Te Ūaka raises caps further (true ≤ 20 MB originals are sign-in-only) or DigitalNZ
  re-harvests from a higher-res source.
- The `ehiveIIIFLargest` transform is shared across the eHive cluster (17/18/19/31/32/33) — route any future
  eHive collection through it.
