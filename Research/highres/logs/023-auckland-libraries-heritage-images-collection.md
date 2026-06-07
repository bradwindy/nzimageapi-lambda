# 023 — Auckland Libraries Heritage Images Collection

- **Group:** A (re-check, already in Lambda; legacy `switch` → thumbnailer.digitalnz.org proxy)
- **Platform:** was Matapihi / aucklandcity.govt.nz Heritage Images; **migrated to Kura CONTENTdm**
  (`kura.aucklandlibraries.govt.nz`)
- **DigitalNZ result_count:** 17,787 (live, 2026-06-07) — down from the plan's 36,228
- **Timestamp:** 2026-06-07
- **Outcome:** **blocked → REMOVED from the Lambda** (user-approved). The DigitalNZ harvest is fully
  degraded (no image URLs), so the collection hard-fails on every request; its content is already served
  at higher resolution by **Kura Heritage Collections Online (order 16)**.

## Raw record sample (key redacted)

| field | value |
|-------|-------|
| large_thumbnail_url | **null** |
| thumbnail_url | **null** |
| object_url | **null** |
| origin_url / metadata_url | **null** |
| landing_url | `https://kura.aucklandlibraries.govt.nz/digital/collection/photos` (generic — same for ALL records) |
| dc_identifier | `7-A13845` (legacy catalogue id only) |
| rights_url | `http://www.aucklandcity.govt.nz/dbtw-wpd/HeritageImages/termsofuse.htm` (old site) |

## Investigation

- **0 / 700 sampled records have any image URL.** Counted across pages 1, 2, 5, 20, 50, 100, 150
  (per_page=100): every record has `large_thumbnail_url = null` and the identical generic
  `landing_url`. The full harvested source record (`/v3/records/30077521.json`) confirms every image/
  object/origin/metadata URL is null — only legacy descriptive metadata + a `dc_identifier` remain.
- **Hard failure in the Lambda, not just degraded.** `DigitalNZAPIDataSource` picks one random result
  then calls `checkHasTitleAndLargeImage()` (`NZRecordsResult.swift:110`), which **throws** when
  `largeThumbnailUrl == nil`. There is no retry-until-displayable loop, so **every** request that the
  weighted picker routes to this collection throws and returns no image.
- **Weight 0.182 — the single largest entry** in `collectionWeights`. So ≈ 18% of all Lambda traffic was
  hitting this hard failure.
- **Content already served, better, by order 16.** "Kura Heritage Collections Online" (order 16,
  committed `a13ccbb`) is the live Kura CONTENTdm **`photos`** collection — content_partner **Auckland
  Libraries**, 390,626 records, per-record landings (`/digital/collection/photos/id/<id>`), working
  images, served at full IIIF native (`/iiif/2/photos:<id>/full/max/` → verified 2000×1365, HTTP 200).
  The Kura `photos` alias is exactly this collection's generic landing path. So "Auckland Libraries
  Heritage Images Collection" is the **old aucklandcity/Matapihi harvest of the same Auckland Libraries
  photos**, superseded by and migrated into Kura.

## Decision

**Blocked + REMOVED from the Lambda** (user decision, 2026-06-07; same pattern as Presbyterian order 5
and Wellington). Recovery was rejected: the records carry no image URL (so they are filtered/throw before
`URLProcessor` ever runs), recovery would need both an architectural change to the data source and a
fragile per-request CONTENTdm search by `dc_identifier`, and it would only duplicate order 16's content.
Removal eliminates the ≈18% hard-failure rate and loses nothing (the photos are served at higher
resolution by order 16).

## Implementation

- `NZImageApi.swift`: deleted `"Auckland Libraries Heritage Images Collection": 0.182,` from
  `collectionWeights`.
- `URLProcessor.swift`: deleted the legacy `case "Auckland Libraries Heritage Images Collection"`
  (thumbnailer proxy). The `thumbnailerProxy` reusable helper is left in place (seeded platform recipe,
  already unreferenced; may serve a future collection).
- **Weight note:** removing 0.182 leaves `collectionWeights` summing to ≈0.818 until the final
  renormalization pass (one pass at sweep end, per the plan). Not deployed per-collection, so the
  intermediate sum is fine; flagged here so the final pass accounts for it.

## Verification

- `swift build` → exit 0.
- Regression smoke: `CollectionTester "Canterbury Museum"` (legacy switch path, now the first `case`)
  → HTTP 200 valid image — the switch fallback still works after the case removal.

## Commit

`6edb680` — Remove Auckland Libraries Heritage Images Collection (dead harvest, superseded by Kura).
User-approved 2026-06-07.

## Follow-up

If DigitalNZ ever re-harvests this collection with live Kura image URLs (or per-record landings), it
could be re-added — but it would duplicate order 16, so re-adding is unlikely to be worthwhile.
