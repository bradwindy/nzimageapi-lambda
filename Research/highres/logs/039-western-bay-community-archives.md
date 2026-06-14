# Order 39 — Western Bay Community Archives

- **Group:** B (ADD — was NOT in `collectionWeights`, so never served)
- **Platform (progress.json):** `boutique` → **RECLASSIFIED to `recollect`** (Recollect — by Recollect Ltd / NZMS, **not** Axiell; classic `downloadwiz` master on a newer Recollect generation)
- **rawItemCount (list):** 2,420 · **live (primary_collection / display_collection / collection, category=Images):** 2,440 (all three facets identical)
- **content_partner:** Western Bay District Council
- **Status:** committed (user-approved 2026-06-14)
- **Strategy:** Group B ADD via the **EXISTING `recollectOgImageMaster`** (introduced for John Kinder 37, reused by Tasman 38) — two-asset og:image → downloadwiz master, **no new strategy code**

## Identity

"Western Bay Community Archives" is the DigitalNZ `primary_collection` **and** `display_collection`
**and** `collection` — all three return the same 2,440 Images. The Lambda queries
`and[primary_collection][]` + `and[category][]=Images` and dispatches on `result.collection`
(= `display_collection` = "Western Bay Community Archives"), so the single key works.

## Platform detection

Harvested `large_thumbnail_url` = `http://westernbay.recollect.co.nz/assets/display/<aid>-600`,
thumbnail `…/<aid>-280`, landing `http://westernbay.recollect.co.nz/nodes/view/<nid>` — the classic
**Recollect** shape. Footer / download page: **"RECOLLECT © Recollect Limited"** + `recollectcms.com`
(Recollect Ltd / NZMS — NOT Axiell). 7th `boutique`-mislabel of the sweep.

This instance runs a **newer Recollect generation**: the homepage and node pages also expose
`assets/pic/<nodeId>` (node-id-addressed display image; `-600`/`-max` suffixes are ignored on that
route) alongside the legacy `assets/display/<assetId>-…` scheme. The legacy `assets/display/<aid>`
scheme **still resolves for ~97% of records**, so the harvested baseline is mostly live.

## ★ Two-asset (cf. National Army Museum 02 / John Kinder 37 / Tasman 38)

Identical two-asset structure to John Kinder / Tasman:
- `/assets/downloadwiz/<aid>` (the **harvested** asset id) → **404** — the harvested id is a
  master-less display derivative.
- `/assets/display/<aid>-600` == `-max` — both ~1000 px (byte-identical), no improvement from `-max`.
- The **node `og:image`** references a **DIFFERENT primary asset id** (usually `aid+1`, sometimes a
  larger gap, e.g. 5338→5373, 4644→4793, 8088→8573, 4396→4397→…→5160×5299) whose **`downloadwiz`
  master IS present**. The og:image URL itself is `…/assets/display/<ogAid>-max?u=<sig>` (still
  ~1000 px); the win is the `downloadwiz/<ogAid>` master.

**No vanity redirect** (unlike Clutha 36 / Tasman 38): `westernbay.recollect.co.nz` serves the node
pages and the `downloadwiz` master directly (HTTP 200, no cross-host 30x). So
`recollectOgImageMaster` — which builds the master URL from the og:image's own host — targets
`westernbay.recollect.co.nz` and needs **no new strategy code, just a registry entry reusing the
Kinder helper** + a weight. (The shared `fetchHTML` request-header UA fix from Tasman is present but
not strictly required here, since there is no cross-host redirect.)

## ★ Stale harvested ids (site migration renumbered ~3%)

The page-1 / most-recent harvested records (e.g. id 43700029 "Tauranga - Waihi Royal Mail Coach",
asset 2633 / node 607) are **stale**: their `nodes/view/<nid>` 302-redirects to a
`/pages/error404/…` page ("Item does not exist") and `assets/display/<aid>-600` 404s. A past site
migration renumbered nodes/assets, and DigitalNZ's harvest of those records was never re-synced.
The id collisions are coincidental — live `nodes/view/2633` exists but is a **different** item
("At the Katikati A & P Show", og asset 6744), not the harvested record — so there is **no reliable
old→new id mapping**.

For a stale record, `recollectOgImageMaster` fetches the landing → follows the 302 → the
**`404: Page not found`** page, which has **no `og:image` meta** → the guard fails → it returns the
harvested `url` (which 404s). This is the best achievable (no mapping exists) and is **not a
regression**: the collection is additive (Group B), and the baseline harvested URL is itself 404 for
those records. Uniform survey put staleness at **1/30 ≈ 3%**.

## Measurements (Discovery Playbook)

**Uniform staleness + master-availability survey — 30 records** evenly spaced across all 49 pages
(global index `i·2440/30`):

| metric | value |
|---|---|
| live nodes | **29/30 (97%)** · stale **1/30 (3%)** (page-1 / renumbered) |
| og id present & differs from harvested aid | 29/29 |
| og `downloadwiz` 200 (HEAD) | **29/29 (100%)** of live nodes |
| error404 page carries a misleading default og:image | **no** (none) → clean fallback |

**Pixel sample — 24 uniform records** (baseline `display/<aid>-600` vs master `downloadwiz/<ogId>`):

| metric | value |
|---|---|
| wins (>1.02×) | **24/24 (100%)** |
| ~equal / honest-smaller | 0 / 0 |
| failures | 0 |
| ratio (area) | min **2.74×** · median **11.72×** · max **34.57×** · mean ~13× |
| master dims | up to 5879×4275 (~25 MP) in the sample; CollectionTester served up to **8411×6763 ≈ 57 MP** |

**Master format:** JPEG served as `application/octet-stream` (+ `Content-Disposition: attachment`) —
renders in `<img>` (Tauranga / Hastings / Lower Hutt / Clutha / Tasman behavior). Real JPEG bytes
(decoded by `sips` for dimensions).

## Decision

**Group B ADD via the existing `recollectOgImageMaster`** — master present for 29/29 (100%) of live
nodes (up to ~57 MP live), median 11.7× the ~1000 px display tier, graceful HEAD-probe fallback to
the og asset's `-max` for any pending-master record, and harvested-`url` fallback on the ~3% stale
records (error404 page has no og:image). **No new code beyond the registry entry + weight.**

## Implementation

- `URLProcessor.swift` — registry entry `strategies["Western Bay Community Archives"] = { await
  recollectOgImageMaster(...) }` (reuses the Kinder/Tasman helper).
- `NZImageApi.swift` — `collectionWeights["Western Bay Community Archives"] = 0.002` (provisional).
- `progress.json` — platform `boutique` → `recollect`; status; baseline / chosen / notes.

## Verification

- `swift build` exit 0.
- CollectionTester ×6 → 6/6 HTTP 200 (`display_collection`="Western Bay Community Archives" confirms
  dispatch); served masters: `downloadwiz/4931` (Florence Swindley), `downloadwiz/5357` (8411×6763,
  **57 MP**), `downloadwiz/6233` (6864×4622, 32 MP), `downloadwiz/8992` (3878×2533), `downloadwiz/4021`
  (6903×3041, 21 MP), `downloadwiz/5152` (3511×2660). Every picked URL targets the og asset id
  (≠ harvested thumb id) on westernbay.recollect.co.nz.
- Regression: pure code change, reuses an existing helper; Kinder 37 / Tasman 38 unaffected.

## Example live URLs (for the approval gate)

- big master: `https://westernbay.recollect.co.nz/assets/downloadwiz/5357` (8411×6763, 57 MP) ·
  `…/assets/downloadwiz/3881` (5879×4275, 34.6× over baseline `…/assets/display/3880-600` 1000×727)
- survey plan: `…/assets/downloadwiz/4437` (5282×5306, ~28 MP) vs `…/assets/display/4436-600` (999×1004)
- typical: `…/assets/downloadwiz/5152` (3511×2660, 9.3 MP)

(Master URLs download as an `attachment` JPEG — they render in `<img>`.)

## Commit

- Change commit: "Western Bay Community Archives (39): committed Group B ADD …" (Swift registry entry
  + weight reusing recollectOgImageMaster + `Research/highres/` bookkeeping). The SHA is recorded by
  the follow-up "Record SHA … for collection 39" commit.
