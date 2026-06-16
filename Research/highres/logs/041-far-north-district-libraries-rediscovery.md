# Order 41 — Far North District Libraries Rediscovery

- **Group:** B (ADD — was NOT in `collectionWeights`, so never served)
- **Platform (progress.json):** `boutique` → **RECLASSIFIED to `recollect`** (Recollect Ltd / NZMS, the classic `*.recollect.co.nz` `downloadwiz` generation — NOT the Feilding-35 signed-IIIF generation, NOT Axiell)
- **Host:** `fndclibraries.recollect.co.nz` · **content_partner:** Far North District Libraries · **rights:** CC BY-NC 4.0 / CC BY-NC-ND 4.0 (all public, no login-wall)
- **rawItemCount:** 1,435 · **live (primary_collection, category=Images):** 1,435
- **Status:** committed (user-approved 2026-06-16)
- **Strategy:** **REUSED `recollectOgImageMaster`** (no new strategy code) — the 8th `boutique`-mislabel-actually-Recollect, and the 4th TWO-ASSET case (cf. John Kinder 37 / Tasman 38 / Western Bay 39). Registry entry + `collectionWeights` 0.002 only. **Pure code change, no AWS deploy.**

## Identity

"Far North District Libraries Rediscovery" is the DigitalNZ `primary_collection` **and**
`display_collection`; the `collection` field is themed sub-collections ("Kerikeri Early History
Ring Binder", "Rainbow Warrior Clear File", …). The Lambda queries `and[primary_collection][]` +
`and[category][]=Images` and dispatches on `result.collection` (= `display_collection` = "Far North
District Libraries Rediscovery"), so the single key works for the query, the weight, and the
registry. `object_url` is null; `landing_url` = `https://fndclibraries.recollect.co.nz/nodes/view/<n>`.

## Platform detection

Harvested `large_thumbnail_url` = `http://fndclibraries.recollect.co.nz/assets/display/<thumbId>-600`;
`thumbnail_url` = `…/<thumbId>-280`. Landing `…/nodes/view/<n>`. This is the classic Recollect
`downloadwiz` shape (same as Hastings 6 / Lower Hutt 7 / Clutha 36 / Kinder 37 / Tasman 38 / Western
Bay 39).

## ★ UA-gate (the first thing I hit — a red herring that masqueraded as a token gate)

Every `assets/…` URL returns **HTTP 403** (118-byte HTML stub) when requested **without a browser
User-Agent**. The node page's `og:image` is `…/assets/display/<id>-max?u=<32-hex>`, which initially
looked like a per-asset signed token. It is **not**: the `?u=` query is irrelevant (works with or
without), and the real gate is purely the **User-Agent** — with a browser UA, the bare
`display/<id>-600` / `-max` / `-4000` and `downloadwiz/<id>` all return 200. This is the same UA-gating
seen at Tasman 38. The shared `NetworkRequestManager.fetchHTML` and `headStatusFollowingRedirects`
**both already send a browser UA**, so the strategy works unchanged; no cross-host redirect here (the
master is served directly on `fndclibraries.recollect.co.nz`, so the session-level UA suffices).

## ★ TWO-ASSET (the harvested thumb id is mostly master-less)

- `display/<thumbId>-600` == `-max` == `-4000` — all byte-identical, **~1000px display tier** (e.g.
  1000×1351). Size token unlocks nothing on the display derivative.
- **`downloadwiz/<thumbId>` (the harvested id) 200 for only 31/105 (~30%)**, 404 for ~70%.
- **The node `og:image` id == thumb id for only 28/105**, differs for **77/105 (~73%)** — when it
  differs, the `og:image` points to a DIFFERENT *primary* asset whose `downloadwiz` master IS present
  (master_200 ≈ og_same, i.e. the master lives on the og:image's asset, not the harvested thumb).

So `recollectLargest` (which rips the harvested thumb id) would **regress ~70% of records to ~1000px**.
`recollectOgImageMaster` (scrape node `og:image` → master-bearing asset id → `downloadwiz` master,
else `-max`) handles **both** the same-id (~30%) and different-id (~70%) cases uniformly.

## Measurements (Discovery Playbook)

**Survey 1 — harvested-thumb-id path (105 records, uniform across 15 pages):**
- `downloadwiz/<thumbId>` 200: **31/105 (~30%)**; 404: 74/105 (~70%).
- `display/<thumbId>-600` dead: **0/105** (the harvested baseline is always valid).
- `og:image` id == thumb id: 28/105; **differs (two-asset): 77/105 (~73%)**; og missing: 0.

**Survey 2 — `recollectOgImageMaster` path (60 records, uniform across 15 pages):**
- `og:image` present: **60/60 (100%)**.
- **og-`downloadwiz` 200 (master present on the og asset): 59/60 (98.3%)**.
- Pixel: **58 win / 1 equal / 0 honest-smaller / 1 fail**; area ratio **min 1.0, median 23.4×, max 57.6×**.
- Masters up to **7590×5042 ≈ 38 MP** from a ~1000×664 baseline; the `og:image`'s asset id is usually
  thumb-id + a small offset (e.g. 7483→7485, 2532→2602), but is the same id for the single-asset ~30%.

**The 1 fail (id 49622662):** the node's `og:image` is the **site logo**
(`…/theme/fndclibraries/img/logo.mobile.png`, no `display/<id>`), so `recollectOgImageMaster`'s
`content.slice(from: "display/", to: "-")` returns nil → **graceful fallback to the harvested `-600`**
(1000×715, still valid). ~1.7% stale-node fraction (cf. Western Bay 39's ~3%). Additive (Group B),
so not a regression.

## Decision

**Group B ADD via the existing `recollectOgImageMaster`** — the same reusable two-asset strategy as
Kinder 37 / Tasman 38 / Western Bay 39, with no new strategy code, no domain-map entry (the strategy
uses the `og:image`'s own host), and no AWS deploy.

## Implementation

- `URLProcessor.swift` — registry entry `strategies["Far North District Libraries Rediscovery"] =
  { await recollectOgImageMaster(...) }`. No change to `recollectOgImageMaster`,
  `recollectDomainMap`, or any other strategy (zero regression risk).
- `NZImageApi.swift` — `collectionWeights["Far North District Libraries Rediscovery"] = 0.002`
  (provisional rawItemCount-share, renormalized in the final pass).
- `progress.json` — platform `boutique` → `recollect`; status committed; baseline / chosen / notes.

## Verification

- `swift build` exit 0.
- CollectionTester ×6 → **6/6 HTTP 200** `downloadwiz` masters (`display_collection` confirms dispatch):
  ids 7734 / 15569 / 6640 / 7344 / 6654 / 6588 → decoded **18.3 / 0.9 / 29.5 / 21.4 / 25.0 / 28.5 MP**
  (five large masters + one honest small native 793×1098). 0 fallbacks observed.
- Header check: the `downloadwiz` master is `Content-Type: application/octet-stream` +
  `Content-Disposition: attachment` + `X-Content-Type-Options: nosniff` — **byte-identical** to the
  already-approved Clutha 36 / Hastings 6 masters (renders in `<img>`; direct navigation downloads the
  `.jpg`). The `nosniff` is standard Recollect behaviour, not anomalous.
- Regression: additive only (new registry entry + new weight); `recollectOgImageMaster` and every
  other path untouched.

## Example live URLs (for the approval gate)

- *"A scow at the Kerikeri basin"* (node 5): baseline `…/assets/display/42-600` (1000×1351, 1.35 MP)
  → master `…/assets/downloadwiz/42` (**1761×2380, 4.19 MP, 3.1×**).
- *"Waitangi Bowling Club (1)"* (node 2886): baseline `…/assets/display/7798-600` (999×681, 0.68 MP)
  → master `…/assets/downloadwiz/7798` (**7456×5084, 37.9 MP, 55.7×**).

## Commit

- Change commit: "Far North District Libraries Rediscovery (41): committed Group B ADD …" (registry
  entry reusing `recollectOgImageMaster` + weight + `Research/highres/` bookkeeping). The SHA is
  recorded by the follow-up "Record SHA … for collection 41" commit.
