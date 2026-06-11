# 031 — Te Hikoi Museum

- **Order:** 31
- **Group:** A (re-check an existing Lambda collection)
- **Platform:** **Live eHive** (Vernon Systems / NZMuseums front-end), account **3278**. (progress.json
  `platform` reclassified `boutique` → `ehiveIIIF`.)
- **DigitalNZ result_count (Images):** ~8,690 (rawItemCount in progress.json 8,589)
- **Status:** **committed** — IMPROVEMENT (passthrough 800 px → IIIF master up to 1000 px)
- **Date:** 2026-06-12

## Baseline (what shipped before)

Legacy `switch` **passthrough** group in `URLProcessor.swift` (returned `large_thumbnail_url` unchanged).
The harvested `large_thumbnail_url` is the eHive **`_l` (large) derivative**
(`https://images.ehive.com/accounts/3278/objects/images/<hash>_l.jpg`), hard-capped at **800 px** on the
long side (~0.4–0.5 MP). Te Hikoi was mis-placed in the passthrough group even though the codebase already
has a proven `ehiveIIIFLargest` strategy (used by Mataura 18 / Howick 17 / NZ Portrait Gallery 19).

## Source site

- Images: `https://images.ehive.com/accounts/3278/objects/images/<hash>_<size>.jpg` — public size suffixes
  `_t`/`_s`/`_m`/`_l`; **`_l` (800 px) is the max** public suffix. `thumbnail_url` is `_m`.
- **IIIF master:** `https://iiif.ehive.com/iiif/2/accounts%2f3278%2fobjects%2fimages%2f<hash>.tif/...`
  (the OpenSeadragon viewer's own `info.json` source). `/full/full/0/default.jpg` returns the native master
  as a browser JPEG, no sign-in.
- Landing: `https://ehive.com/collections/3278/objects/<objectId>`. `object_url` null; `dc_identifier` =
  accession + `ehiveaccountid:3278`.

## Discovery Playbook (all avenues)

**A. Web research.** `images.ehive.com/accounts/3278/...` ⇒ **eHive**, same platform as Mataura (4033) /
Howick (3000) / Portrait Gallery (3272). eHive's own help docs confirm the model: public viewers get
**either** a legacy **800 × 800** cap **or** higher-resolution / full-size originals via the **IIIF
pan-and-zoom** service — the institution chooses per copyright licence; the true ≤ 20 MB original is
**sign-in-only**. (https://info.ehive.com/help/images/image-access/, .../pan-and-zoom-ehive/.)

**B. Page-source / info.json.** `iiif.ehive.com/.../<hash>.tif/info.json` returns the master canvas
dimensions. For Te Hikoi these are **bimodal and exact**: every improvable record is **exactly 1000 px**
long side, the rest **exactly 800 px** — never an intermediate value. That exact-1000/exact-800 split means
1000 px is a **server-side public cap** Te Hikoi has set (not natural original sizes, which would spread).

**C. Viewers.** OpenSeadragon on each object page tiles the same `iiif.ehive.com` master (512² tiles,
scaleFactors 1/2/4/8; scaleFactor-1 canvas = 1000 px). No route beyond the 1000 px canvas.

**D. URL / variant mutation.** Larger `images.ehive.com` suffixes `_xl`/`_xxl`/`_o`/`_original`/`_master`/
`_full`/`_z`/`_zoom` all **HTTP 500** (don't exist). **IIIF upscales on demand** — `full/1600,/` returns
1600 px and `full/2000,/` returns 2000 px, but these are **interpolated from the 1000 px master**
(fake/blurry). The **honest** ceiling is **`full/full`** (= `full/max` = the true master, 1000 px), which
the shared `ehiveIIIFLargest` already uses — it never requests a fixed larger width.

**E. Alternate host/source.** The true full original is sign-in-only (eHive account login). No anonymous
route above the 1000 px public IIIF master.

**F. Dead/Wayback.** N/A (live route).

**G. Toolbox.** N/A — `full/full` is already a browser-displayable JPEG (`image/jpeg`).

## Measurements

- **Master-size distribution (70-record spread, pages 1…810):** long side **min 800, max 1000, median
  1000, mean 960**. Buckets: **≤ 800 → 14 (20%)**, **801–1000 → 56 (80%)**, none above 1000. So **~80% of
  records gain 800 → 1000 px (×1.25 linear, ×1.56 area)**; the other ~20% are already ≤ 800 and the IIIF
  master returns that native size.
- **Parity / health (same 70):** `_l` 200 → **70/70**; IIIF `full/full` default.jpg 200 → **70/70**. IIIF
  **bigger than `_l`: 56, equal: 14, worse-or-failed: 0** — a strict-safe improvement (never a regression,
  never a new failure where `_l` worked).
- **Cap confirmation:** `full/max` == `full/full` == 1000 px (no upscaling at the honest endpoint);
  fixed-width requests above the master upscale (so they are deliberately not used).
- **Headers (IIIF):** `content-type: image/jpeg`, **no** `Content-Disposition` (displays inline),
  `access-control-allow-origin: *`, `cache-control: max-age=31536000, public`, CloudFront-backed.
- **Live pipeline (`CollectionTester "Te Hikoi Museum"` ×3, HTTP 200 image/jpeg):** run 2 served
  **1000×667** vs baseline **800×534** (×1.56 area); run 3 served **800×533** vs baseline **800×533**
  (already-≤800 record, no regression). All emitted the IIIF URL.

## Conclusion

**IMPROVEMENT — committed (user-approved 2026-06-12).** Te Hikoi was mis-placed in the passthrough group.
Moved it into the `strategies` registry pointing at the existing, proven **`ehiveIIIFLargest`** (same as
Mataura/Howick/Portrait Gallery): the `_l` 800 px derivative → IIIF `full/full` over the master TIFF.
Result: **~80% of records 800 → 1000 px (×1.56 area)**, ~20% unchanged at ≤ 800, **0/70 worse or failed**.
Pure URL construction (no request-time fetch). `swift build` 0; CollectionTester ×3 HTTP 200 image/jpeg.

Te Hikoi's masters are **smaller than the other eHive accounts** (1000 px cap here, vs up to ~12–17 MP for
Mataura/Howick) — its public IIIF ceiling is 1000 px, not the true preservation original.

## Follow-up

- Re-check only if Te Hikoi raises its public IIIF cap above 1000 px (true ≤ 20 MB originals are
  sign-in-only), or if DigitalNZ re-harvests from a higher-res source.
- The `ehiveIIIFLargest` transform is shared with Mataura/Howick/Portrait Gallery — any future eHive
  collection in the sweep should be routed through it rather than passthrough.
