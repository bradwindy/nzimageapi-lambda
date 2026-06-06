# 013 — Dunedin City Council Archives Flickr

- **Group:** B (ADD — not previously in the Lambda)
- **Platform:** flickr (`live.staticflickr.com`; account `95014006@N04`)
- **DigitalNZ result_count:** 1,768 (live, 2026-06-06)
- **Timestamp:** 2026-06-06
- **Outcome (awaiting approval):** **ADDED** via the general Flickr rule — serve `object_url` (the
  `_o` original); fall back to `flickrLargest` (`_b`) if absent. `_o` originals up to 27.7 MP vs the
  0.3 MP `_z` baseline.

## Raw record sample (key redacted)

| field | value |
|-------|-------|
| large_thumbnail_url | `https://live.staticflickr.com/3863/14830700335_5d58c923ab_z.jpg` (640) |
| object_url | `https://live.staticflickr.com/3863/14830700335_435fa67a63_o.jpg` (**Original**) |
| landing_url | `http://www.flickr.com/photos/95014006@N04/14830700335` |

## Live site investigation (Discovery Playbook)

- **`object_url` = `_o` original for 45/45** uniformly-sampled records (pages 1–301, per_page 5):
  **0 null, 0 non-jpg, all `_o`.**
- **`_o` browser-displayable** (`Content-Type: image/jpeg`, HTTP 200) and ≥ `_z` everywhere:
  | record | `_z` baseline | `_o` original |
  |--------|---------------|---------------|
  | 14830700335 | 397×640 (0.3 MP) | 858×1383 (1.2 MP) |
  | (sample) | 640×418 (0.3 MP) | 750×490 (0.4 MP — small original, still > `_z`) |
  | (sample) | 468×640 (0.3 MP) | **4497×6153 (27.7 MP)** |
- **`_o` is the ceiling** (Flickr exposes nothing larger than the original; `_b` ≤ `_o`). Identical
  structure to Alexander Turnbull (order 12) — the general Flickr rule applies directly.

## Decision

**ADD via the general Flickr rule:** `object_url ?? flickrLargest`. Serves the `_o` original for
~100% of records (the max), with the `_b` (1024) derivative as a safety net for any null
`object_url`. Big win over the Group-B baseline raw `_z` (640).

## Implementation

- `URLProcessor.strategies`: added `"Dunedin City Council Archives Flickr" → result.objectUrl?.absoluteString ?? flickrLargest(result, url)`.
- `NZImageApi.collectionWeights`: added `"Dunedin City Council Archives Flickr": 0.002` (provisional;
  ~proportional to 1,768 items; final renormalization at end).
- No `recollectDomainMap` change (not Recollect).

## Verification

`swift build` exit 0. `CollectionTester "Dunedin City Council Archives Flickr"` ×3 (fresh server,
:7000 freed between): **3/3 HTTP 200, `Content-Type: image/jpeg`, JPEG**, all `_o` originals —
32439893457 **1650×1162 (1.9 MP)**, 29263354472 **3596×2242 (8.1 MP)**, 25918414421 **1373×949
(1.3 MP)** vs `_z` 0.3 MP.

## Commit

(pending user approval)
