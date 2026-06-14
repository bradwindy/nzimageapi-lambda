# Order 36 — Clutha Heritage

- **Group:** B (ADD — was NOT in `collectionWeights`, so never served)
- **Platform (progress.json):** `boutique` → **RECLASSIFIED to `recollect`** (Recollect — by Recollect Ltd / NZMS, **not** Axiell)
- **rawItemCount (list):** 2,754 · **live (primary_collection, category=Images):** 2,888
- **content_partner:** Clutha District Libraries
- **Status:** committed (user-approved 2026-06-14)
- **Strategy:** Group B ADD via the existing **`recollectLargest`** (registry + `recollectDomainMap`)

## Identity / harvest quirk (important)

"Clutha Heritage" is **not** a DigitalNZ `collection` value — it is the **`primary_collection`**
(scalar `display_collection` = "Clutha Heritage" on every record; the `collection` array is `[]`
or a themed sub-collection like "World Wars"). `and[collection][]=Clutha Heritage` returns **0**;
`and[primary_collection][]=Clutha Heritage` returns 3,040 (2,888 in category Images). The Lambda
already queries `and[primary_collection][]` + `and[category][]=Images`
(`DigitalNZAPIDataSource.swift:61,93`) and dispatches the URL strategy on `result.collection`
(= `display_collection` = "Clutha Heritage", `NZRecordsResult.swift:61`) — so the single key
**"Clutha Heritage"** works for the query, the `collectionWeights` pick, the `strategies` registry,
and `recollectDomainMap` alike. (The earlier `display_collection` facet showed 0 values — the field
is populated on records but not faceted; verified by reading records directly.)

## Platform detection

Harvested `large_thumbnail_url` = `https://clutha.recollect.co.nz/assets/display/<id>-600`,
landing `https://clutha.recollect.co.nz/nodes/view/<node>`, thumbnail `…/<id>-280` — the classic
**Recollect** shape (the `*.recollect.co.nz` `downloadwiz` family, NOT the new-gen signed-IIIF
`recollectcms.com` of Feilding 35). **Recollect is made by Recollect Ltd (spun out of NZMS — New
Zealand Micrographic Services — in 2019); it is NOT an Axiell product.** The `*.recollect.co.nz`
`downloadwiz` generation and the `recollectcms.com` signed-IIIF generation are **two product
generations of the same vendor**, not two vendors. Same family as Tauranga (1), Hastings (6), Lower
Hutt (7), Hocken (8), He Purapura (10). The `boutique` label in the worklist was wrong.

**Vanity-domain redirect:** `clutha.recollect.co.nz` 301/302-redirects to the council vanity domain
**`heritage.cluthadc.govt.nz`** (the site's canonical host; `og:image` points there as
`…/assets/display/<id+1>-max?u=<sig>`). Both hosts serve the identical master. Unlike the
Presbyterian (5) migration, the harvested `*.recollect.co.nz` host is **fully live** (the redirect
is followed transparently by `headStatusFollowingRedirects` and by browsers) — no breakage. We keep
`clutha.recollect.co.nz` in the domain map (consistent with the harvest + every other entry).

## Measurements (Discovery Playbook)

**Uniform sample:** 788 records across pages 1/5/9/13/17/21/25/29; asset ids 11–16544 (median 8015).

**`downloadwiz` master availability (HEAD following redirects, all 788):** **784 = 200 (99.5%)**,
**4 = 404** (aids 16437/16439/16441/16443 — consecutive newest uploads; their `-600` AND `-max`
both 200 JPEG, so `recollectLargest` serves `-max` → no breakage). No login-wall (8/8 nodes 200,
`login=False`); all rights public/open (CC BY 3.0 NZ, out-of-copyright, orphan works) — **no
restricted/All-Rights-Reserved tail** (cf. He Purapura's ~10%).

**Master format:** JPEG (magic `\xFF\xD8\xFF`) served `application/octet-stream` +
`Content-Disposition: attachment` with real filenames — downloads as attachment but renders in
`<img>` (the established, user-accepted Tauranga/Hastings behavior). A `Range` header → 404
(hotlink protection; can't Range-probe, must full-GET).

**Pixel sample (36 uniform records — `downloadwiz` master vs `-600`):**

| metric | value |
|---|---|
| wins (master bigger) | **34/36 (94%)** |
| honest-smaller | 2/36 (6%) |
| equal / worse-than-honest / failures | 0 / 0 / 0 |
| ratio (area) | min 0.40× · **median 4.27×** · max **36.08×** · mean 8.44× |
| largest masters | 6000×4379 (26.3 MP), 5287×3596 (19 MP), 4094×3497 (14.3 MP), 4320×3240 (14 MP) |
| smallest masters | 1151×1145 (1.3 MP), 634×1071 (0.68 MP), 792×485 (0.38 MP) |

`-600` == `-max` byte-identical (~1000 px display cap) for almost every record.

**Honest-smaller (2/36):** aids 11575 (master 634×1071 vs `-600` upscaled-fake 1000×1689) and 11686
(master 792×485 vs `-600` 999×612). The `-600` display tier **upscales** small originals to a fake
~1000 px; `downloadwiz`/`-max` return the **honest native** (fewer pixels, real detail). Consistent
with the project's honest-native-always precedent (Kura 16, Hocken 8 caveat, eHive 17/32).

## Decision

**Group B ADD via `recollectLargest`** — healthy Recollect, masters present for ~99.5% (up to
26 MP, median 4.27× the display area), graceful `-max` fallback for the ~0.5% pending-master
records, no login-wall / no migration rot. Identical to Hastings (6) / Lower Hutt (7). **Not**
`recollectDisplayMax` (Hocken's case — there `downloadwiz` was uniformly 404; here it's uniformly
200). **Not** NAM-style two-asset (the thumbnail id's own `downloadwiz` already serves the master;
no `og:image` scrape needed).

## Implementation

- `URLProcessor.swift` — `strategies["Clutha Heritage"] = { await recollectLargest(...) }`;
  `recollectDomainMap["Clutha Heritage"] = "clutha.recollect.co.nz"`.
- `NZImageApi.swift` — `collectionWeights["Clutha Heritage"] = 0.002` (provisional rawItemCount
  share; renormalized in the final pass).
- `progress.json` — platform `boutique` → `recollect`; status; baseline/chosen.

## Verification

- `swift build` exit 0.
- CollectionTester ×4 → 4/4 HTTP 200 `downloadwiz` master (`display_collection`="Clutha Heritage"
  confirms dispatch): aid 14889 1920×1280 (3.7×), 15131 1920×1280 (3.7×), 8770 2547×1771 (6.5×),
  3378 1428×974 (2.0×) — all beat their `-600` baseline.

## Example live URLs (for the approval gate)

- big master: `https://clutha.recollect.co.nz/assets/downloadwiz/5062` (6000×4379, 26 MP) vs
  baseline `…/assets/display/5062-600` (999×729)
- typical: `https://clutha.recollect.co.nz/assets/downloadwiz/8770` (2547×1771) vs `…/8770-600`
- honest-smaller: `https://clutha.recollect.co.nz/assets/downloadwiz/11575` (634×1071, honest
  native) vs the upscaled-fake `…/11575-600` (1000×1689)

(Master URLs download as an `attachment` JPEG — they render in `<img>`; the same behavior already
shipped and accepted for Tauranga/Hastings/Lower Hutt.)

## Commit

- Change commit: "Clutha Heritage (36): committed Group B ADD …" (Swift code + `Research/highres/`
  bookkeeping, bundled with the Recollect vendor-attribution correction). The SHA is recorded into
  `progress.json` by the follow-up "Record SHA … for collection 36" commit (established pattern).
