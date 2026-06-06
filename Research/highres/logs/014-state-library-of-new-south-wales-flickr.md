# 014 — State Library of New South Wales Flickr

- **Group:** B (ADD — not previously in the Lambda)
- **Platform:** flickr (`live.staticflickr.com`; account `statelibraryofnsw`, a high-res Flickr Commons member)
- **DigitalNZ result_count:** 174 (live, 2026-06-06)
- **Timestamp:** 2026-06-06
- **Outcome (awaiting approval):** **ADDED** via new `flickrLandingLargest` — scrape the photo page
  for the largest size (up to the `_o` original). `_o` originals up to ~45 MP vs the 0.3 MP `_z`
  baseline. Drove the Flickr re-architecture (see Decision).

## Raw record sample (key redacted)

| field | value |
|-------|-------|
| large_thumbnail_url | `https://live.staticflickr.com/2557/3805829153_a58fc9b1a8_z.jpg` (640) |
| object_url | **null** |
| landing_url | `http://www.flickr.com/photos/statelibraryofnsw/3805829153` |

`object_url` is null (no direct original), so neither `objectUrlDirect` nor a same-secret `_b` swap
reaches the original.

## Live site investigation (Discovery Playbook)

**Critical correction to the Te Ara (order 11) method.** The largest Flickr derivatives
(`_h`/`_k`/`_o`, up to the original) use **per-photo alternate secrets** (confirmed earlier: Flickr's
`_b`/`_c`/`_z` share the base secret; `_h`/`_k` each have their own; `_o` uses `originalsecret`).
Those alternate-secret URLs are **only** in the photo page (or the paid `getSizes` API) — NOT
constructible from the harvested `_z` URL.

- My order-11 "max-size distribution" used a **main-page `displayUrl` JSON scrape that silently
  undercounted** (the big-size URLs are JSON-escaped `\/` and were missed). The reliable signal is
  the page's full embedded size model, recovered by de-escaping `\/` first.
- **SLNSW exposes huge originals.** The page's size model lists widths up to **7792 px**; the `_o`
  URL (e.g. `3805829153_1efc7e47d1_o.jpg`) decodes **7792×5767 (44.9 MP)**. Measured originals
  (strict per-photo-id extraction from the landing page):
  | photo | `_z` baseline | landing-page max |
  |-------|---------------|------------------|
  | 3805829153 | 640×474 (0.3 MP) | `_o` **7792×5767 (44.9 MP)** |
  | 3419414899 | 640×478 (0.3 MP) | `_o` **7518×5954 (44.8 MP)** |
  | 4194047894 | 640×478 (0.3 MP) | `_o` 1400×1045 (1.5 MP) |
  | 14210949316 | (z) | `_o` 736×1200 (0.9 MP) |
  (Mixed: some originals are small scans, but all ≥ the `_z`/`_b` derivative; the big ones are 30–45×.)

**Mechanism decision (user).** First choice was `flickr.photos.getSizes` (clean JSON), but **Flickr
now requires Flickr Pro (paid) to obtain an API key** → not available. Pivoted to a **landing-page
scrape**: fetch the photo page, de-escape `\/`, extract `…/<photoId>_<secret>_<size>.jpg` strictly
for this photo id, return the largest by size rank. Fallback (user-chosen): `flickrLargest` (`_b`)
on no-landing-URL / fetch-failure / no-match.

## Decision

**ADD via `flickrLandingLargest`.** One bounded HTML GET of the photo page per request recovers the
original (or largest available); `_b` (1024) fallback guarantees a valid larger-than-thumbnail image
if Flickr hiccups. Big win for SLNSW (originals up to ~45 MP). Pure `_b` swap was rejected (would
discard ~98% of the resolution on the large originals).

## Implementation

- `URLProcessor`: new `flickrSizeRank` dict + `flickrLandingLargest(_:_:)` (async; fetch landing →
  de-escape `\/` → `NSRegularExpression` for `live.staticflickr.com/<srv>/<photoId>_<secret>_<size>.(jpg|png|gif)`
  → pick max rank → `flickrLargest` fallback).
- `URLProcessor.strategies`: added `"State Library of New South Wales Flickr" → flickrLandingLargest`.
- `NZImageApi.collectionWeights`: added `"State Library of New South Wales Flickr": 0.001` (provisional; 174 items).

## Verification

`swift build` exit 0. `CollectionTester "State Library of New South Wales Flickr"` ×3 (fresh server,
:7000 freed between): **3/3 HTTP 200, `image/jpeg`, JPEG**, all `_o` originals — 36676185834, 23493948378,
37443694695 each **3500×~2590 (9.1 MP)** vs `_z` 0.3 MP (~30× area).

## Commit

(pending user approval)
