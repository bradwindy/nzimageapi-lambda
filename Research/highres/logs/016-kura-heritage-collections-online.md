# 016 — Kura Heritage Collections Online

- **Group:** A (re-check, already in Lambda; `collectionWeights` 0.116)
- **Platform:** iiif — **CONTENTdm** (OCLC) at `kura.aucklandlibraries.govt.nz` (Auckland Libraries)
- **DigitalNZ result_count:** 390,626 (live, 2026-06-06; the largest collection)
- **Timestamp:** 2026-06-06
- **Outcome:** **Switched to honest native `/full/max/`** (user-chosen). The previous hardcoded
  `/full/2048,/` upscaled every image; there is no master larger than the 2000px native.

## Raw record sample (key redacted)

| field | value |
|-------|-------|
| large_thumbnail_url | `https://kura.aucklandlibraries.govt.nz/digital/api/singleitem/image/photos/235744/default.jpg` |
| object_url | `null` |
| landing_url | `https://kura.aucklandlibraries.govt.nz/digital/collection/photos/id/235744` |

Asset id is between `/image/photos/` and `/default.jpg`. The current strategy rebuilds it as a
CONTENTdm IIIF 2.0 URL.

## Current production strategy (baseline)

Legacy `switch`: `ripId` → `https://kura.aucklandlibraries.govt.nz/iiif/2/photos:<id>/full/2048,/0/default.jpg`
(hardcoded **2048 width**).

## Live site investigation (Discovery Playbook)

- **IIIF 2.0 level2** (`info.json`), profile supports `sizeAboveFull`, `maxArea` ≈ 2× the image area.
- **Native is capped at 2000 px on the long side, universally.** `info.json` `width`/`height` and the
  `sizes[]` array top out at the native dimensions; **0/30** uniformly-sampled images exceed 2048
  (many are exactly 2000 on the long side; some smaller). Sources:
  CONTENTdm IIIF docs (<https://help.oclc.org/Metadata_Services/CONTENTdm/Advanced_website_customization/API_Reference/IIIF_API_reference>),
  IIIF Image API 2.1 (<https://iiif.io/api/image/2.1/>).
- **No larger preservation master exists.** The CONTENTdm download endpoints
  `utils/getfile/collection/photos/id/<id>/...` and `digital/api/collection/photos/id/<id>/download`
  both return the **same native** (1378×2000 for id 235744, `application/octet-stream`/`image/jpeg`).
  `/full/2828,/` and `/full/4000,/` → **HTTP 403** (server refuses larger upscales).
- **The current `/full/2048,/` UPSCALES.** Because `sizeAboveFull` is supported, requesting width 2048
  on a sub-2048 native interpolates fake pixels. Measured (id 235744, native 1378×2000): `/full/2048,/`
  = 2048×2972 (6.1 MP, **interpolated**) vs `/full/max/` = `/full/full/` = 1378×2000 (2.8 MP, **native**).
  Every image is upscaled to 2048-wide (portraits worst, ~1.5× fake).

## Decision

**Switch to `/full/max/` (honest native).** A quality-vs-pixel-count fork (like Hocken order 8): the
current `/full/2048,/` yields more pixels but they're interpolated/soft. The true ceiling is the 2000px
native (confirmed via the download endpoints). **User chose** the honest native over keeping the
upscale. `/full/max/` still beats the raw `singleitem` baseline (0.4–0.5 MP) by 4–7×.

## Implementation

- `URLProcessor.strategies`: added `"Kura Heritage Collections Online"` → `ripId(... /iiif/2/photos:<id>/full/max/0/default.jpg)`
  (reuses `ripId`; id between `/image/photos/` and `/default.jpg`).
- `URLProcessor` legacy `switch`: removed the `case "Kura Heritage Collections Online":` block
  (migrated switch → registry).
- No `collectionWeights` change (Group A; stays 0.116).

## Verification

`swift build` exit 0. `CollectionTester "Kura Heritage Collections Online"` ×3 (fresh server, :7000
freed between): **3/3 HTTP 200, `image/jpeg`, JPEG**, all `/full/max/`. Native vs old upscale vs raw
baseline: 299089 **1751×1752 (3.1 MP)** [old 2048² 4.2 MP fake; raw 0.4 MP]; 124544 **2000×1341
(2.7 MP)** [old 2.8; raw 0.4]; 176105 **2000×1618 (3.2 MP)** [old 3.4; raw 0.5]. `/full/max/` is the
honest native and 4–7× the raw baseline.

## Commit

`a13ccbb` — Kura Heritage Collections Online: serve honest IIIF native /full/max/ (was upscaled
/full/2048,/). User-approved 2026-06-06.
