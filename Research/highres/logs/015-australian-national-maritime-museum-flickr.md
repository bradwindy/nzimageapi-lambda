# 015 — Australian National Maritime Museum Flickr

- **Group:** B (ADD — not previously in the Lambda)
- **Platform:** flickr (`live.staticflickr.com`; account `anmm_thecommons`, a high-res Flickr Commons member)
- **DigitalNZ result_count:** 126 (live, 2026-06-06)
- **Timestamp:** 2026-06-06
- **Outcome (approved — user pre-approved "do the same for the other similar flickr page"):** **ADDED**
  via `object_url (_o original) ?? flickrLandingLargest`. `_o` originals 4–28 MP vs the 0.3 MP `_z`.

## Raw record sample (key redacted)

| field | value |
|-------|-------|
| large_thumbnail_url | `https://live.staticflickr.com/8203/8207477350_83f209be95_z.jpg` (640) |
| object_url | `https://live.staticflickr.com/8203/8207477350_c4c9145750_o.jpg` (**Original**) |
| landing_url | `http://www.flickr.com/photos/anmm_thecommons/8207477350` |

## Live site investigation (Discovery Playbook)

- **ANMM is NOT object_url-null** (unlike SLNSW): `object_url` = `_o` original for **35/35**
  uniformly-sampled records (0 null, all `image/jpeg`, HTTP 200). So the original is available via
  `object_url` directly — **no page fetch needed**.
- `_o` originals far exceed the `_z` baseline:
  | record | `_z` baseline | `object_url` `_o` |
  |--------|---------------|-------------------|
  | (sample) | 640×450 (0.3 MP) | 2480×1742 (4.3 MP) |
  | (sample) | 640×434 (0.3 MP) | 3035×2056 (6.2 MP) |
  | (sample) | 465×640 (0.3 MP) | 3400×2672 (9.1 MP) |
- The landing-page scrape (`flickrLandingLargest`) returns the **same** `_o` original — so using
  `object_url` first is the cheaper route to the identical maximum.

## Decision

**ADD via `object_url ?? flickrLandingLargest`.** Serves the `_o` original from `object_url` for
~100% of records (free, no fetch); the page-scrape is the fallback for any null `object_url` (more
appropriate than `_b` for this high-res account). Honors the user's "do the same" intent (get the
original) while avoiding an unnecessary per-request fetch.

## Implementation

- `URLProcessor.strategies`: added `"Australian National Maritime Museum Flickr" → objectUrl ?? flickrLandingLargest`.
- `NZImageApi.collectionWeights`: added `"Australian National Maritime Museum Flickr": 0.001` (provisional; 126 items).

## Verification

`swift build` exit 0. `CollectionTester "Australian National Maritime Museum Flickr"` ×3 (fresh
server, :7000 freed between): **3/3 HTTP 200, `image/jpeg`, JPEG**, all `_o` originals —
8787862071 **3899×3972 (15.5 MP)**, 7898530388 **2814×3749 (10.5 MP)**, 8966369626 **4543×6256
(28.4 MP)** vs `_z` 0.3–0.4 MP.

## Commit

Shared with the Te Ara (order 11) retrofit — see `progress.json` `commit` and log 011.
