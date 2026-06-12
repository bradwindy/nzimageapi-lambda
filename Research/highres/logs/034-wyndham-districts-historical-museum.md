# 034 — Wyndham & Districts Historical Museum

- **Order:** 34
- **Group:** B (candidate **new** collection — was NOT in the Lambda)
- **Platform:** **Live eHive** (Vernon Systems / NZMuseums front-end), account **3102**. (progress.json
  `platform` reclassified `boutique` → `ehiveIIIF`.) **4th `boutique`-mislabel-actually-eHive in a row**
  (cf. Te Hikoi 31 / Te Toi Uku 32 / Te Ūaka 33).
- **DigitalNZ result_count (Images):** 3,937 (rawItemCount in progress.json 3,937)
- **Status:** **committed** — ADD (new collection added to the Lambda via `ehiveIIIFLargest`; user-approved 2026-06-12)
- **Date:** 2026-06-12

## Baseline (what shipped before)

**Nothing** — Wyndham was **not in `collectionWeights`**, so the weighted-random picker
(`DigitalNZAPIDataSource.swift:50`) never selected it; the collection was never served in production.
Had it been served via the `switch` `default:` passthrough it would have returned the eHive `_l`
**800 px** derivative.

## Source site

- Images: `https://images.ehive.com/accounts/3102/objects/images/<id>_<size>.jpg` — `_l` (800 px cap) is the
  harvested `large_thumbnail_url`; `_m` is the thumbnail. **All image ids are 32-hex** (no older non-hex
  `cpa*` tokens, unlike Te Ūaka 33 — so no sampling trap here).
- **IIIF master:** `https://iiif.ehive.com/iiif/2/accounts%2f3102%2fobjects%2fimages%2f<id>.tif/...`;
  `/full/full/0/default.jpg` returns the native master as a browser JPEG, no sign-in, `image/jpeg`.
- Landing: `https://ehive.com/collections/3102/objects/<objectId>`. `object_url` null; `dc_identifier` =
  accession (`WY.*`) + `ehiveaccountid:3102`. Rights sampled: **Public Domain**.

## Discovery Playbook (all avenues)

**A. Web research.** `images.ehive.com/accounts/3102/...` ⇒ **eHive**. Same platform/route as the rest of
the eHive cluster (Mataura 18 / Howick 17 / Portrait Gallery 19 / Te Hikoi 31 / Te Toi Uku 32 / Te Ūaka 33).

**B. Page-source / info.json.** `iiif.ehive.com/.../<id>.tif/info.json` gives the master canvas. For a typical
record (`0ccd0e68…`): `width:1000, height:743`, `sizes` pyramid 125→250→500→1000 — i.e. a **1000 px master**.
A small minority carry full-resolution masters (info.json `width` up to 4581 / 4242).

**C. Viewers.** OpenSeadragon on each object page tiles the same `iiif.ehive.com` master.

**D. URL / variant mutation.** Larger `images.ehive.com` suffixes don't exist. **IIIF upscales on demand** —
`full/6000,/` returns a fake 6000 px (interpolated from the native master). The honest ceiling is
**`full/full`** (= `full/max` = the true master), which `ehiveIIIFLargest` uses. Confirmed: for the
4581×2690 master, `full/6000,` → 6000×3523 (interpolated, fake); `full/full` → 4581×2690 (native).

**E. Alternate host/source.** True original (≤ 20 MB, sign-in-only per eHive docs) — the public IIIF master
is the best anonymous route.

**F. Dead/Wayback.** N/A (live route).

**G. Toolbox.** N/A — `full/full` is already a browser-displayable JPEG.

## Measurements

- **Master long-side distribution (120-record sample spread uniformly across the FULL 3,937-record
  collection, measured via info.json — 0 errors):** min **1000**, max **4581**, median **1000**, mean 1058.
  Buckets: **801–1000 → 118 (98%)**, **> 3000 → 2 (~2%)** (4581×2690 and 3199×4351 ≈ 12–14 MP).
- **`_l` baseline vs IIIF `full/full` (15 records spread across pages 1–700, decoded with `sips`):**
  every record **IIIF ≥ `_l`**, http 200, `image/jpeg` — **15 bigger / 0 equal / 0 worse / 0 failures**.
  Typical landscape: `_l` 800×594 → IIIF 1000×743 (×1.56 area). Portrait records upgrade proportionally:
  561×800 → 701×1000, 628×800 → 785×1000, 480×800 → **4242×7065 (~30 MP master!)**.
- **The big masters are real native** (not upscaled): `66ffaff4…` → 4242×7065; `70b7b4cc…` → 4581×2690
  (1.52 MB); `4713e2c0…` → 3199×4351 (1.48 MB). For each, `full/full` == native and `full/6000,` upscales
  past it (fake), so `full/full` is the honest ceiling.
- **No honest-smaller anomaly possible:** the master min is 1000 px and the `_l` suffix is capped at 800 px,
  so IIIF `full/full` is **always ≥ `_l`** (unlike Te Toi Uku 32's single de-faked 793 px record).
- **Dead-at-source:** **60 / 3,937 (1.5%)** records have a **null `large_thumbnail_url`** (no image
  harvested). `DigitalNZAPIDataSource` picks a random record and calls `.checkHasTitleAndLargeImage()`
  (`:112-115`) with **no retry**, so ~1.5% of Wyndham picks hard-fail. **Left as-is** — well below the
  South Canterbury 29 precedent (~9%); a HEAD/retry loop is out of scope (user decision precedent).
- **Live pipeline (`CollectionTester` ×4, HTTP 200 `image/jpeg`):** ids `a7051e94…`, `b15a86b1…`,
  `92e7d059…`, `fe4d34c2…` — all rewritten to `iiif.ehive.com/.../full/full/0/default.jpg`, all 200.

## Implementation

- **`URLProcessor.strategies`:** added `"Wyndham & Districts Historical Museum" → ehiveIIIFLargest`
  (pure URL build; identical transform as the rest of the eHive cluster). No new platform function.
- **`NZImageApi.collectionWeights`:** added `"Wyndham & Districts Historical Museum": 0.002` (provisional
  rawItemCount-share, 3,937 / current corpus ≈ 0.0020; renormalized in the final weights pass).
- `swift build` exit 0; `CollectionTester` ×4 HTTP 200 image/jpeg.

## Conclusion

**ADD — committed (user-approved 2026-06-12).** Wyndham is a **Group B** candidate not previously in the
Lambda. Routed via the existing proven **`ehiveIIIFLargest`** (IIIF `full/full` over the master TIFF). The
account-3102 public master is **almost uniformly 1000 px** (≈98% of records, ×1.56 area over the 800 px
`_l`) with a **~2% tail of large native masters up to ~30 MP** — **every IIIF ≥ `_l`, 0 worse, 0 failures**.
Pure URL construction; weight 0.002 provisional.

## Follow-up

- Provisional weight **0.002** — recompute in the **final weights renormalization pass**.
- ~1.5% of records are null-image at source (hard-fail the pick); left as-is per the South Canterbury 29
  precedent.
- The `ehiveIIIFLargest` transform is shared across the eHive cluster (17/18/19/31/32/33/34) — route any
  future eHive collection through it.
