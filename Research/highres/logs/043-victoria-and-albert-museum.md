# Order 43 — Victoria and Albert Museum

- **Group:** B (ADD — was NOT in `collectionWeights`, so never served)
- **Platform (progress.json):** `boutique` → **RECLASSIFIED to `iiif`** (the V&A's own IIIF Image API at `framemark.vam.ac.uk`)
- **Host (harvest):** `media.vam.ac.uk` (legacy image host, being retired) · **Host (chosen):** `framemark.vam.ac.uk` (IIIF) · **landing:** `collections.vam.ac.uk/item/O<systemNumber>`
- **content_partner:** Victoria and Albert Museum · **rights:** "© Victoria and Albert Museum, London" (we serve the same image the V&A publishes via IIIF, at the largest public size — its 2500 px cap)
- **rawItemCount (progress.json snapshot):** 549 · **live (primary_collection, category=Images):** **564** (updated)
- **Status:** committed (user-approved 2026-06-16)
- **Strategy:** **NEW `vamIIIFLargest`** (pure URL construction, like Kura 16) — derive the IIIF id from the harvested filename stem, emit `https://framemark.vam.ac.uk/collections/<id>/full/max/0/default.jpg`. Registry entry + `collectionWeights` 0.001. **No request-time fetch, no AWS deploy.**

## Identity

"Victoria and Albert Museum" is the DigitalNZ `primary_collection` **and** `display_collection`
(`collection` field == same). The Lambda queries `and[primary_collection][]` + `and[category][]=Images`
and dispatches on `result.collection` (= `display_collection`), so the single key works. `object_url`
null; `landing_url` = `https://collections.vam.ac.uk/item/O<systemNumber>`.

## Platform detection

Harvested `large_thumbnail_url` = `https://media.vam.ac.uk/media/thira/collection_images/<batch>/<id>.jpg`
(e.g. `2025PE4780.jpg`); `thumbnail_url` adds a `_jpg_w` suffix. `media.vam.ac.uk` is the **legacy image
host** — it serves only ~640–768 px where present and **404s for ~⅓ of records** (host being retired).
The V&A runs a public **IIIF Image API** at `framemark.vam.ac.uk/collections/<id>/`, keyed by the SAME
`<id>` (the V&A object API confirms: `meta.images._iiif_image` = `framemark.vam.ac.uk/collections/<id>/`,
and `<id>` == the harvested filename stem). So the IIIF URL is derivable **purely from the harvested
filename** — no API call needed.

## ★ The harvested baseline is partly broken; IIIF is a strict Pareto improvement

- `media.vam.ac.uk` `<id>.jpg`: **200 for 24/36 (67%), 404 for 12/36 (33%)** — a third of the harvested
  baseline is dead.
- `framemark` `info.json`: **36/36 (100%) resolve.** Native is **bimodal**: ~44% report **2500 px** (the
  service cap, `maxWidth`/`maxHeight` = 2500), ~47% report **768 px**, ~8% **640 px** (genuinely low-res
  digitisations).
- **Head-to-head (30 records), IIIF `/full/max/` vs the harvested media image:** where both exist (20):
  **IIIF win 12 / equal 8 / lose 0** (area ratio min 1.0, median **10.6×**, max 17.2×). For the 10 dead-media
  records IIIF resolves (200), so the IIIF route **fixes the broken harvest** as well as enlarging.
- So `/full/max/` is **≥ the media image for every record**, 2500 px for the ~half with a high-res master,
  and the honest native (≤ 2500, **never upscaled**) for the low-res half.

## ★ 2500 px is the hard public ceiling; honest `/full/max/`

- `info.json` `profile` is IIIF 2 level1 with `maxWidth`/`maxHeight` = **2500** and `supports` includes
  `sizeAboveFull` — so a fixed-width request **could** fake-upscale a small-native record. `/full/max/`
  avoids that (returns native ≤ 2500). Verified: a 768-native record → `/full/max/` = 768 (not upscaled),
  and a `/full/4000,` request on a high-res id **clamps to 2500** (byte-identical to `/full/max/`, not
  upscaled past the master). So 2500 px is the real ceiling.
- The IIIF **presentation manifest** (`iiif.vam.ac.uk/collections/O<n>/manifest.json`) references only the
  same `framemark` image — **no larger download/original/TIFF** is exposed. (Rights are "© V&A", and the
  V&A deliberately caps public delivery at 2500 px.)
- `framemark` needs **no browser UA** (no-UA `/full/max/` → 200), so the served URL renders anywhere.

## Measurements (Discovery Playbook)

- **Survey 1 (36 records uniform):** harvested media 200 24 / 404 12; IIIF info.json 36/36 ok; IIIF
  longest-side native distribution {640: 3, 768: 17, 2500: 16}.
- **Survey 2 — media-vs-IIIF head-to-head (30 records):** harvested media dead 10; both present 20 → IIIF
  win 12 / equal 8 / lose 0; IIIF/media area ratio min 1.0 / median 10.6 / max 17.21.
- **V&A object API** (`api.vam.ac.uk/v2/object/O<n>`): `meta.images._iiif_image` =
  `framemark.vam.ac.uk/collections/<id>/`, `imageResolution` per-record tier ("high" for 2500-px records),
  `_images_meta[].assetRef` == `<id>`. Confirms the id mapping (no API call needed at request time).

## Decision

**Group B ADD via a new `vamIIIFLargest`** — `framemark.vam.ac.uk/collections/<id>/full/max/0/default.jpg`,
id parsed from the harvested filename stem (defensively strips a `_jpg_w` suffix). Honest native ≤ 2500 px;
strict improvement (≥ the media image always, fixes the ~⅓ dead-media records). No request-time fetch.

## Implementation

- `URLProcessor.swift` — new `vamIIIFLargest(_:_:)` (pure URL construction; guards on host containing
  `vam.ac.uk` + a `.jpg` path, falls back to the harvested URL otherwise) + registry entry
  `strategies["Victoria and Albert Museum"]`.
- `NZImageApi.swift` — `collectionWeights["Victoria and Albert Museum"] = 0.001` (provisional; 564 records).
- `progress.json` — platform `boutique` → `iiif`; rawItemCount 549 → 564; status; baseline / chosen / notes.

## Verification

- `swift build` exit 0.
- CollectionTester ×6 → **6/6 HTTP 200 `image/jpeg`** framemark IIIF URLs (`display_collection` confirms
  dispatch): 2014HD1569 / 2019MJ6730 / 2019MJ6716 → 768×576 (low-res masters); 2022NE3449 1797×2500,
  2014HD1533 2500×1875, 2022NE3444 1676×2500 (high-res masters). 0 fallbacks.
- Regression: additive only (new function + registry entry + weight); no existing path touched.

## Example live URLs (for the approval gate)

- *"Postcard – South"* (O1276652): baseline `media.vam.ac.uk/.../2014HD1531.jpg` (768×576) → IIIF
  `framemark.vam.ac.uk/collections/2014HD1531/full/max/0/default.jpg` (**2500×1875, 10.6×**).
- *"Teddy bear – Teddy 2002"* (O85053): baseline `media.vam.ac.uk/.../2025PE4780.jpg` (**HTTP 404, broken**)
  → IIIF `framemark.vam.ac.uk/collections/2025PE4780/full/max/0/default.jpg` (**1939×2500, fixes the broken harvest**).

## Commit

- Change commit: "Victoria and Albert Museum (43): committed Group B ADD …" (new `vamIIIFLargest` +
  registry + weight + `Research/highres/` bookkeeping). The SHA is recorded by the follow-up
  "Record SHA … for collection 43" commit.
