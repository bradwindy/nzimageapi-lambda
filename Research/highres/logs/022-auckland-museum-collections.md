# 022 — Auckland Museum Collections

- **Group:** A (re-check, already in Lambda; legacy `switch` → cloudimg `_collectionsecure_` master)
- **Platform:** aklMuseumCloudimg — museum file server behind the cloudimg `_collectionsecure_` storage
  alias (`ajrctguoxo.cloudimg.io`); path from the public API `object_av_link`
- **DigitalNZ result_count:** 267,102 (live, 2026-06-07)
- **Timestamp:** 2026-06-07
- **Outcome:** **improvement — AND a bug fix.** The shipped pipeline was producing a **broken URL (HTTP
  404 for every record)**; the corrected pipeline serves the **honest native master** (0.36–71 MP,
  1.6×–471× the harvested 400 px `medium`). Migrated legacy switch → registry.

## Raw record sample (key redacted)

| field | value |
|-------|-------|
| large_thumbnail_url | `https://collection-api.aucklandmuseum.com/records/images/medium/543593/<hash>.jpg` (**400 px**) |
| thumbnail_url | `https://collection-api.aucklandmuseum.com/records/images/small/543593/<hash>.jpg` (150 px) |
| object_url | `null` |
| landing_url | `https://www.aucklandmuseum.com/discover/collections/record/1072873` |

The harvested `large_thumbnail_url` is the `medium` (400 px) derivative. Size tokens on
`collection-api.aucklandmuseum.com/records/images/<token>/<id>/<hash>.jpg`: `small` 150 px, `medium`
400 px; `large`/`xlarge`/`full`/`original`/`master`/`raw` all **HTTP 403** (signed/private — not a public
route). So the harvested host caps the public image at 400 px.

## Live site investigation (Discovery Playbook)

- **Landing page** (`www.aucklandmuseum.com/discover/collections/record/<landingId>`) embeds the big
  image via cloudimg over a `_collectionsecure_` alias, e.g.
  `https://ajrctguoxo.cloudimg.io/v7/_collectionsecure_%2FDocumentaryHeritage%2FPictorial%2Falbum491%2Ffull%2FAlbum491_p1_1.jpg%3Fc%3D6?ci_url_encoded=1&force_format=webp,jpeg&org_if_sml=0&width=700&height=700&func=fit`
  — the site itself **caps display at 700 px** (`func=fit`, padded) or `height=1000` (`func=bound`).
- The relative master path comes from the public API: `GET
  collection-publicapi.aucklandmuseum.com/api/v3/opacobjects/<landingId>` → field set
  `object_av_link` → first value, e.g. `J:\DocumentaryHeritage\Pictorial\album491\full\Album491_p1_1.jpg|20||Rights...`.
  The `full\` segment is the museum's access master; the cloudimg alias root maps to the `J:` drive.
- **Other routes ruled out:** the `media.aspx?id=...&hash=...` handler on the landing page → **404**;
  `collection-api` `large`/`full`/`original` tokens → **403**. The cloudimg `_collectionsecure_` master
  is the only public full-resolution route, and it is the museum's own master file (so it is the ceiling).

### The bug in the shipped pipeline (why baseline = broken)

The old code built `…/v7/_collectionsecure_/J:/DocumentaryHeritage/…/Album491_p1_1.jpg?c=11?ci_url_encoded=1&force_format=jpeg&height=1000`:
- kept the **`J:` drive prefix** (the alias root already maps to it), and
- left the path **unencoded** (raw `/`) while still passing `ci_url_encoded=1`.

Both forms **404** (verified `prod_height1000`, `noheight`, clean single-`?` variants — all 404). The
site's working URL strips `J:` and percent-encodes the path. ⇒ the Lambda has been emitting a broken
404 cloudimg URL for **every** Auckland Museum record.

## Candidate measurements — uniform sample (18 records, pages 1/200/800/2000/6000/12000)

`curl | sips` decoded px; `medium` (harvested baseline) vs corrected-native cloudimg (`org_if_sml=1`,
no width/height). **18/18 had `object_av_link`; 18/18 native cloudimg → HTTP 200 JPEG.**

| native dims | ratio vs medium | example path |
|-------------|:---------------:|--------------|
| 512×337 | 1.6× | `…/album491/full/Album491_p1_1.jpg` (small postcard) |
| 721×800, 800×572 | 4.0× | `…/Pictorial/pf/f/*.jpg` |
| 1275 px long side | 10.2× | `…/Photographs/2013/PH-2013-*` |
| 1561×2500 … 1698×2500 | 39× | `…/Photographs/Albums/PH-ALB-91*` |
| 3344×3417 | 73× | `…/Photographs/Albums/PH-ALB-10*` |
| **8688×5792 (50 MP)** | **471×** | `…/Natural History/Marine/BongE/*.jpg` |

Tester cross-check (4 random records, GET-verified): 800×464; **7105×10015 (71 MP)**; 512×704;
5792×8688 (50 MP). 22/22 total records → valid native JPEG. `org_if_sml=1` never upscales (the 512 px
masters stay 512 px — honest native, consistent with the Kura 16 / eHive 17 honest-native choice).

## Decision

**Serve the honest native master via the corrected cloudimg `_collectionsecure_` URL.** Strict
improvement on two axes: (1) **fixes** the broken 404 the Lambda was shipping; (2) lifts resolution from
the 400 px `medium` to the native master (1.6×–471× observed). Honest pixels (no upscale), per the user's
standing preference.

## Implementation

- `URLProcessor.swift`: new `aklMuseumCloudimg(_:_:)` (async, non-throwing → always falls back to the
  harvested 400 px `medium` on nil landing id / API error / missing `object_av_link`, so output is always
  a valid 200 image). Transform: `object_av_link` first value → `\`→`/` → strip leading `X:` drive prefix
  + leading `/` → percent-encode (RFC 3986 unreserved only, so `/`→`%2F`, space→`%20`) → build
  `https://ajrctguoxo.cloudimg.io/v7/_collectionsecure_%2F<encoded>?ci_url_encoded=1&force_format=jpeg&org_if_sml=1`.
- Registry entry added; legacy `case "Auckland Museum Collections"` removed (switch → registry migration).
  Reuses the existing `AKLMuseumResponse`/`OpacObjectFieldSet`/`OpacObjectField` models and
  `NetworkRequestManager.makeRequest`.
- Weight unchanged (Group A).
- Per-request cost: one bounded JSON GET to the public API (same as before) — never downloads the image.

## Verification

- `swift build` → exit 0.
- `swift run CollectionTester "Auckland Museum Collections"` ×4: all produced the corrected cloudimg URL.
  The tester validates with a **10 s HEAD** which **times out on cloudimg's cold processing of large
  masters** → reports "HTTP 0" (a tester artifact for slow/large strategies, as the plan notes; a warm
  HEAD returns 200 in ~2.5 s). GET-verified each (what a browser does): all **HTTP 200 image/jpeg JPEG**
  (800×464; 7105×10015 = 71 MP; 512×704; 5792×8688 = 50 MP).

## Commit

(pending user approval)
