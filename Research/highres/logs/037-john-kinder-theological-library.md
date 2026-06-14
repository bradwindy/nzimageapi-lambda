# Order 37 — John Kinder Theological Library

- **Group:** B (ADD — was NOT in `collectionWeights`, so never served)
- **Platform (progress.json):** `boutique` → **RECLASSIFIED to `recollect`** (Recollect — by Recollect Ltd / NZMS, **not** Axiell; classic `downloadwiz` generation)
- **rawItemCount (list):** 2,714 · **live (all three facets, category=Images):** 2,714
- **content_partner:** John Kinder Theological Library
- **Status:** committed (user-approved 2026-06-14)
- **Strategy:** Group B ADD via a **NEW reusable `recollectOgImageMaster`** (registry) — two-asset
  og:image → downloadwiz master, cf. National Army Museum

## Identity

Unlike Clutha (36), "John Kinder Theological Library" is a value in **all three** DigitalNZ facets —
`and[primary_collection][]`, `and[collection][]`, and `and[display_collection][]` each return **2,714**
Images. The Lambda queries `and[primary_collection][]` + `and[category][]=Images` and dispatches on
`result.collection` (= `display_collection` = "John Kinder Theological Library"), so the single key
works for the query, the `collectionWeights` pick, and the `strategies` registry.

## Platform detection

Harvested `large_thumbnail_url` = `http://kinderlibrary.recollect.co.nz/assets/display/<id>-600`,
thumbnail `…/<id>-280`, landing `http://kinderlibrary.recollect.co.nz/nodes/view/<node>` — the classic
**Recollect** `downloadwiz` shape (NOT the `recollectcms.com` signed-IIIF generation of Feilding 35).
Footer: **"Recollect Limited"** (Recollect Ltd / NZMS — NOT Axiell). The site auto-upgrades
`http`→`https` (and `:443`); no domain migration, no vanity-redirect. The `boutique` label was wrong
(5th platform-mislabel of the sweep).

## ★ The catch — TWO-ASSET records (cf. National Army Museum, order 02)

The harvested `large_thumbnail_url` id is a **master-less display derivative**:
- `/assets/downloadwiz/<thumbId>` → **404** ("goDownload failed") — no master on the harvested id.
- `/assets/display/<thumbId>-600` == `-max` == `-1000` == `-2000` == `-4000` are **all byte-identical**
  (≈1000 px long side) — the display pyramid is hard-capped, the size token unlocks nothing.

The **node page's `og:image`** references a **DIFFERENT, primary asset id** (e.g. thumb `374245` →
og `374380`; thumb `378354` → og `398934`) whose **`downloadwiz` master IS present**. `og:image:width`
on the page reports the true original width (matches the decoded master). So `recollectLargest` — which
rips the harvested thumb id and probes `downloadwiz/<thumbId>` — would **404 → fall back to
`display/<thumbId>-max` ≈ 1000 px for EVERY record**, missing the master entirely. We must scrape the
node `og:image` to recover the primary asset id, then take its `downloadwiz` master.

## Measurements (Discovery Playbook)

**Uniform survey — 80 records** across pages 1/4/7/10/13/16/19/22/25/27 (asset ids 191k–458k):

| metric | value |
|---|---|
| thumb `downloadwiz` 200 | **0/80** (master never on the harvested id) |
| og id present | 80/80 |
| og id **differs** from thumb id | **80/80 (100%)** |
| og `downloadwiz` 200 | **80/80 (100%)** |
| node not-200 / login-wall / missing og | **0 / 0 / 0** |
| og:image width | min 318 · median **1927** · max **6587** (>1000 px: 56/80 = 70%) |

**Pixel sample — 32 uniform records** (baseline `display/<thumbId>-600` vs master `downloadwiz/<ogId>`):

| metric | value |
|---|---|
| wins (master bigger, >1.02×) | **22/32 (69%)** |
| ~equal (0.98–1.02×) | 8/32 (small ≤1000 px native — master == display, no fakery) |
| honest-smaller (<0.98×) | 2/32 |
| failures | 0 |
| ratio (area) | min 0.64× · **median 3.81×** · max **43.49×** · mean 7.87× |
| master MP | min 0.43 · median 3.33 · **max 31.54** |

**Master format:** JPEG (`application/octet-stream` + `Content-Disposition: attachment` with real
filenames, e.g. `KIN-322-1-2.jpg`) — downloads as attachment but renders in `<img>` (established
Tauranga/Hastings/Lower Hutt/Clutha behavior).

**Honest-smaller (2/32):** thumb 280370 (`-600` upscaled-fake 999×667) → master 280504 (honest
**800×534**); thumb 280395 (`-600` 1000×666) → master 280527 (honest 800×533). The `-600` display
upscales small originals to a fake ~1000 px; `downloadwiz` returns the honest native (fewer pixels,
real detail). Consistent with the honest-native-always precedent (Clutha 36, Hocken 8, Kura 16, eHive).

## Decision

**Group B ADD via the NEW reusable `recollectOgImageMaster`** — the two-asset master strategy. Master
present for 80/80 (100%, up to 42.7 MP), median 3.81× the ~1000 px display tier, graceful fallback to
the og asset's `-max` for any pending-master record (HEAD-probed) and to the harvested `url` on any
parse/fetch failure. **NOT `recollectLargest`** (rips the master-less thumb id → would regress to
~1000 px for every record). **NOT `recollectDisplayMax`** (the harvested thumb `-max` is also capped
~1000 px). This is the National Army Museum pattern, generalised into a reusable registry strategy.

## Implementation

- `URLProcessor.swift` — NEW `recollectOgImageMaster(_:_:)` static helper (async): one bounded
  `fetchHTML` of `result.landingUrl`; SwiftSoup parse `meta[property=og:image]`; `slice` the og id
  between `display/` and `-`; HEAD-probe `downloadwiz/<ogId>` following redirects, serve it on 200 else
  `display/<ogId>-max`, using the og:image's own host; fall back to the harvested `url` on any failure.
  Registry entry `strategies["John Kinder Theological Library"]`. (Mirrors the legacy NAM switch case's
  SwiftSoup parse, adds `recollectLargest`'s master-probe-else-`-max` robustness; NAM left in the
  legacy switch, untouched.)
- `NZImageApi.swift` — `collectionWeights["John Kinder Theological Library"] = 0.002` (provisional
  rawItemCount share; renormalised in the final pass).
- `progress.json` — platform `boutique` → `recollect`; status; baseline/chosen/notes.

## Verification

- `swift build` exit 0.
- CollectionTester ×5 → 5/5 HTTP 200 `downloadwiz` master (`display_collection`="John Kinder
  Theological Library" confirms dispatch): records 53287963→og 398968 (**7383×5779 = 42.7 MP**),
  42683991→226896 (800×1263, small native), 53288008→398983 (6001×4077 = 24.5 MP), 51713719→360628
  (4710×5964 = 28.1 MP), 45963741→281354 (3912×3101 = 12.1 MP). The two-asset og:image→downloadwiz
  resolves end-to-end; the picked URL is always `downloadwiz/<ogId>` (ogId ≠ harvested thumb id).

## Example live URLs (for the approval gate)

- big master: `https://kinderlibrary.recollect.co.nz/assets/downloadwiz/398968` (7383×5779, 42.7 MP) vs
  baseline `…/assets/display/398593-600` (~1000 px); item page `…/nodes/view/15549`
- typical: `https://kinderlibrary.recollect.co.nz/assets/downloadwiz/398964` (4123×5097, 21 MP) vs
  `…/assets/display/398589-600`
- honest-smaller: `https://kinderlibrary.recollect.co.nz/assets/downloadwiz/280504` (honest 800×534) vs
  the upscaled-fake `…/assets/display/280370-600` (999×667)

(Master URLs download as an `attachment` JPEG — they render in `<img>`; the same behavior already
shipped and accepted for Tauranga/Hastings/Lower Hutt/Clutha.)

## Commit

- Change commit: "John Kinder Theological Library (37): committed Group B ADD …" (Swift code +
  `Research/highres/` bookkeeping). The SHA is recorded into `progress.json` by the follow-up
  "Record SHA … for collection 37" commit (established pattern).
