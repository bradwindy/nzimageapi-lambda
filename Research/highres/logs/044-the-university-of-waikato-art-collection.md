# Order 44 — The University of Waikato Art Collection

- **Group:** B (ADD — was NOT in `collectionWeights`, so never served)
- **Platform (progress.json):** `boutique` → **RECLASSIFIED to `ehive`** (live eHive, account **8668**)
- **Host (harvest):** `images.ehive.com` (`_l` = 800px box) · **Host (chosen):** `iiif.ehive.com` (eHive's public IIIF Image API 2.0 over the master TIFF) · **landing:** `ehive.com/collections/8668/objects/<objId>`
- **content_partner:** University of Waikato · **rights:** uniform "All rights reserved", license null (the IIIF `/full/full` is NOT rights-gated — see below)
- **rawItemCount (progress.json snapshot):** 540 · **live (primary_collection, category=Images):** **540** (unchanged)
- **Status:** committed (user-approved 2026-06-17)
- **Strategy:** **REUSE `ehiveIIIFLargest`** (no new strategy code) — registry entry + `collectionWeights` 0.001. Pure URL construction from the `_l` URL; **no request-time fetch, no AWS deploy.**

## Identity / dispatch

"The University of Waikato Art Collection" is the DigitalNZ `primary_collection` **and**
`display_collection` (same value). `object_url` null; `landing_url` =
`https://ehive.com/collections/8668/objects/<objId>`. The Lambda queries
`and[primary_collection][]` + `and[category][]=Images` and dispatches on `result.collection`
(= `display_collection`), so the single registry key works.

## Platform detection — 5th boutique-mislabel-actually-eHive

Harvested `large_thumbnail_url` = `https://images.ehive.com/accounts/8668/objects/images/<id>_l.jpg`
(800px long side); `thumbnail_url` = the `_m` derivative. The landing page
(`ehive.com/collections/8668/objects/<objId>`) wires up **OpenSeadragon** (2 mentions in the
fetched HTML) over the eHive IIIF service. As with Te Hikoi 31 / Te Toi Uku 32 / Te Ūaka 33 /
Wyndham 34, the `boutique` label is wrong — it is **live eHive** (account 8668). Per the sweep
rule, `images.ehive.com` + `iiif.ehive.com` were probed first; both resolve.

## ★ The IIIF `/full/full` is not rights-gated (despite uniform "All rights reserved")

Every sampled record has `rights: "All rights reserved"`, `license: null`. Nevertheless
`iiif.ehive.com/iiif/2/accounts%2f8668%2fobjects%2fimages%2f<id>.tif/full/full/0/default.jpg`
returns **200 image/jpeg for 35/35** image-bearing records in the survey — same as the rest of the
eHive cluster (the rights gate only affects the `_xl`/`_o` derivative suffixes, which 500). We
serve exactly the image the University publishes through its own public OpenSeadragon viewer, at
the largest public size (the native master).

## ★ 61.5% of the collection has NO image at source (pre-existing Lambda hard-fail)

Across all 540 records (6 pages × 100), **332 (61.5%) have a null `large_thumbnail_url`**
(`thumbnail_url`/`object_url` also null) — art-catalogue records with no published image. Per-page
empty rate climbs from 16% (p1) → 86% (p3/p5). These picks hit
`NZRecordsResult.checkHasTitleAndLargeImage()` → throws `nullImageOrTitle` → `NZImageApi.image()`
returns nil → the handler (`NZImageApiLambda.handle`) returns **HTTP 400** (no retry loop). This is
**pre-existing Lambda behaviour, identical for the baseline** (the global DigitalNZ
`category=Images` query is not changed — out of scope for a one-collection additive change). It
just means ~61.5% of picks of *this* collection 400; the low weight (0.001, the floor) reflects it.
cf. South Canterbury 29 / Wyndham 34 null-image hard-fails.

## ★ Honest-native fork (~20%) — same as Howick 17 / Te Ūaka 33

For image-bearing records the IIIF native master is usually ≥ the 800px `_l`, but for ~20% eHive
**fake-upscaled the `_l`** to the 800px box from a smaller real master; there the IIIF `/full/full`
returns the **honest smaller native** (never broken, never upscaled — `sizeAboveFull` is NOT in the
profile `supports`). Consistent with the user's established eHive honest-native-always policy.

## Measurements (Discovery Playbook)

- **Empty-image census (all 540):** 332 null-image (61.5%); 208 image-bearing (38.5%).
- **Uniform survey (78 records sampled across 6 pages; 35 image-bearing, 43 null-image):**
  - IIIF `/full/full` 200-image: **35/35** (not rights-gated).
  - native vs `_l`: **WIN 28 / EQUAL 0 / HONEST-SMALLER 7** (~20%).
  - native/`_l` area ratio: min **0.200** (worst honest-smaller), median **2.25×**, max **95.2×**.
  - biggest native: **7803×5202 = 40.6 MP** (id `ae1afc28…`; `/full/full` = 200 image/jpeg, 7.4 MB; `_l` 800×533).
- **First record spot-check** (Monkey Mind | Max Gimblett, id `4d749a6d…`): `_l` 565×800
  (fake-upscaled) vs IIIF native 388×549 (honest-smaller, identical aspect) — confirms the fork.

## Decision

**Group B ADD via REUSE of `ehiveIIIFLargest`** — account-agnostic, builds
`iiif.ehive.com/iiif/2/accounts%2f8668%2fobjects%2fimages%2f<id>.tif/full/full/0/default.jpg` from
the `_l` URL (drop the last `_<size>` segment, `.jpg`→`.tif`, `/`→`%2f`). Honest native (≤ the
master); strict improvement for the image-bearing records; honest-smaller for the ~20%
fake-upscaled `_l`. No request-time fetch, no deploy. Weight 0.001 (floor; reflects the 61.5%
null-image rate).

## Implementation

- `URLProcessor.swift` — new registry entry `strategies["The University of Waikato Art Collection"]`
  → `ehiveIIIFLargest(result, url)` (with a comment documenting account 8668, the honest-native
  fork, the not-rights-gated finding, and the 61.5% null-image hard-fail). **No function added.**
- `NZImageApi.swift` — `collectionWeights["The University of Waikato Art Collection"] = 0.001`.
- `progress.json` — platform `boutique` → `ehive`; status; baseline / chosen / notes / weight.

## Verification

- `swift build` exit 0.
- CollectionTester: 16 picks → **5 image successes / 11 null-image 400s** (~69%, consistent with
  61.5% ± small-sample noise). The 6 measured image picks (5 from the batch + 1 single run), served
  IIIF vs baseline `_l`:
  - Judy Darragh, *Back to the Future 8* — `_l` 533×800 → IIIF 512×768 (honest-smaller 0.92×)
  - Ray Starr, *Black Puriri* — `_l` 591×800 → IIIF **886×1200** (win 2.25×)
  - Max Gimblett, *8 of Wands* — `_l` 666×800 → IIIF 547×657 (honest-smaller 0.67×)
  - John S. Parker, *Plain Song Elegy* — `_l` 538×800 → IIIF **807×1200** (win 2.25×)
  - Xavier Meade, *Te Whiti – Aotearoa Liberation Poster* — `_l` 565×800 → IIIF **848×1200** (win 2.25×)
  - Mirek Smisek, *Stoneware jar with lid* — `_l` 800×615 → IIIF **1200×922** (win 2.25×)
  All 6 HTTP 200 `image/jpeg`, `display_collection` confirms dispatch, 0 fallbacks.
- Regression: additive only (new registry entry + weight; `ehiveIIIFLargest` unchanged) — the rest
  of the eHive cluster is untouched.

## Example live URLs (for the approval gate)

- **Win (typical 2.25×)** — Ray Starr, *Black Puriri*: `…/8533e07fb02e…_l.jpg` 591×800 →
  `iiif.ehive.com/…/8533e07fb02e….tif/full/full/0/default.jpg` 886×1200.
- **Big win (~95×)** — 40.6 MP master: `…/ae1afc28…_l.jpg` 800×533 →
  `iiif.ehive.com/…/ae1afc28….tif/full/full/0/default.jpg` 7803×5202.
- **Honest-smaller (~20% fork)** — Max Gimblett, *8 of Wands*: `…/6641e9d8…_l.jpg` 666×800
  (fake-upscaled) → `iiif.ehive.com/…/6641e9d8….tif/full/full/0/default.jpg` 547×657 (honest native).

## Commit

- Change commit: "The University of Waikato Art Collection (44): committed Group B ADD …" (registry
  entry → `ehiveIIIFLargest` + weight + `Research/highres/` bookkeeping). The SHA is recorded by the
  follow-up "Record SHA … for collection 44" commit.
