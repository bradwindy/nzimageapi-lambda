# 032 — Te Toi Uku, Crown Lynn and Clayworks Museum

- **Order:** 32
- **Group:** A (re-check an existing Lambda collection)
- **Platform:** **Live eHive** (Vernon Systems / NZMuseums front-end), account **3384**. (progress.json
  `platform` reclassified `boutique` → `ehiveIIIF`.)
- **DigitalNZ result_count (Images):** 8,106 (rawItemCount in progress.json 8,106)
- **Status:** **committed** — IMPROVEMENT (passthrough 800 px → IIIF master up to 1200 px)
- **Date:** 2026-06-12

## Baseline (what shipped before)

Legacy `switch` **passthrough** group in `URLProcessor.swift` (returned `large_thumbnail_url` unchanged).
The harvested `large_thumbnail_url` is the eHive **`_l` (large) derivative**
(`https://images.ehive.com/accounts/3384/objects/images/<hash>_l.jpg`), hard-capped at **800 px** on the
long side. Te Toi Uku was mis-placed in the passthrough group (classified `boutique`) even though it is a
live eHive account and the codebase already has the proven `ehiveIIIFLargest` strategy.

## Source site

- Images: `https://images.ehive.com/accounts/3384/objects/images/<hash>_<size>.jpg` — `_l` (800 px) is the
  max public suffix; `thumbnail_url` is `_m`.
- **IIIF master:** `https://iiif.ehive.com/iiif/2/accounts%2f3384%2fobjects%2fimages%2f<hash>.tif/...`;
  `/full/full/0/default.jpg` returns the native master as a browser JPEG, no sign-in.
- Landing: `https://ehive.com/collections/3384/objects/<objectId>`. `object_url` null; `dc_identifier` =
  accession + `ehiveaccountid:3384`.

## Discovery Playbook (all avenues)

**A. Web research.** `images.ehive.com/accounts/3384/...` ⇒ **eHive**, same platform as Te Hikoi 31 (3278) /
Mataura 18 (4033) / Howick 17 (3000) / Portrait Gallery 19 (3272). Per eHive docs, the public sees either an
800 px cap or higher-res via the IIIF pan-and-zoom service (institution's choice); the true ≤ 20 MB original
is sign-in-only.

**B. Page-source / info.json.** `iiif.ehive.com/.../<hash>.tif/info.json` gives the master canvas. Te Toi
Uku's public masters cluster at **exactly 1200 px** (with a few at 1000 / ≤ 800) — a **server-side public
cap at 1200 px**, higher than Te Hikoi's 1000.

**C. Viewers.** OpenSeadragon on each object page tiles the same `iiif.ehive.com` master.

**D. URL / variant mutation.** Larger `images.ehive.com` suffixes don't exist (eHive returns 500). **IIIF
upscales on demand** — `full/2000,/` → 2000 px, `full/1600,/` → 1600 px, both **interpolated from the
1200 px master** (fake). The honest ceiling is **`full/full`** (= `full/max` = the true 1200 px master),
which `ehiveIIIFLargest` uses — never a fixed larger width.

**E. Alternate host/source.** True original is sign-in-only; 1200 px is the anonymous public ceiling.

**F. Dead/Wayback.** N/A (live route).

**G. Toolbox.** N/A — `full/full` is already a browser-displayable JPEG (`image/jpeg`).

## Measurements

- **Master-size distribution (70-record spread, pages 1…810):** long side **min 793, max 1200, median
  1200, mean 1180**. Buckets: **≤ 800 → 2**, **801–1000 → 2**, **1001–1500 → 66** (all 1200), none above
  1200. So **66/70 records → 1200 px (×1.50 linear, ×2.25 area over `_l` 800)**; 2 at 1000; 2 at ≤ 800.
  **68/70 (97%) IIIF master > 800.**
- **Parity / health (same 70):** `_l` 200 → **70/70**; IIIF `full/full` default.jpg 200 → **70/70**. IIIF
  **bigger: 68, equal: 1, honest-smaller/failed: 1**.
- **The one "honest-smaller" record** (`2bfc22a5…`): IIIF native master = **793×667** (info.json `sizes`
  max = 793), but its `_l` is **800×673** — eHive **upscaled** the 793 px native to a fake 800 px `_l`. So
  IIIF returns the **honest** 793 px native (real detail), not the fake-800. Served under
  **honest-native-always** (the user's order-17/18 choice; same as Kura 16 honest-vs-fake). This is the only
  such anomaly in the sample (~1.4%, vs ~11% for Howick).
- **Cap confirmation:** `full/max` == `full/full` == 1200 px (no upscaling at the honest endpoint).
- **Headers (IIIF):** `content-type: image/jpeg`, **no** `Content-Disposition` (displays inline),
  `access-control-allow-origin: *`, `cache-control: max-age=31536000, public`, CloudFront-backed.
- **Live pipeline (`CollectionTester` ×3, HTTP 200 image/jpeg):** 1000×750 vs `_l` 800×600; **1200×1053 vs
  `_l` 800×702 (×2.25 area)**; 900×1200 vs `_l` 600×800 (×2.25 area). All emitted the IIIF URL.

## Conclusion

**IMPROVEMENT — committed (user-approved 2026-06-12).** Te Toi Uku was mis-placed in the passthrough group.
Moved it into the `strategies` registry pointing at the existing, proven **`ehiveIIIFLargest`** (same as
Te Hikoi 31 / Mataura / Howick / Portrait Gallery): the `_l` 800 px derivative → IIIF `full/full` over the
master TIFF. Result: **~97% of records 800 → up to 1200 px (×2.25 area)**, a couple at 1000, 2 already ≤ 800,
and 1 honest-smaller (de-faked) record. **0/70 failures.** Pure URL construction (no request-time fetch).
`swift build` 0; CollectionTester ×3 HTTP 200 image/jpeg.

Te Toi Uku's 1200 px public cap is higher than Te Hikoi's 1000 px but still far below the big eHive accounts
(Mataura/Howick up to ~12–21 MP) — its public IIIF ceiling is 1200 px, not the true preservation original.

## Follow-up

- Re-check only if Te Toi Uku raises its public IIIF cap above 1200 px (true ≤ 20 MB originals are
  sign-in-only), or if DigitalNZ re-harvests from a higher-res source.
- The `ehiveIIIFLargest` transform is shared across the eHive cluster — route any future eHive collection
  through it rather than passthrough.
