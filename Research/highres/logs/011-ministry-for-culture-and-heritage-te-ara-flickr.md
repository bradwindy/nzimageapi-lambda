# 011 — Ministry for Culture and Heritage Te Ara Flickr

- **Group:** B (ADD — not previously in the Lambda)
- **Platform:** flickr (`live.staticflickr.com`; Flickr "Te Ara" pool, contributed by several users)
- **DigitalNZ result_count:** 15,714 (live, 2026-06-06)
- **Timestamp:** 2026-06-06
- **Outcome (awaiting approval):** **ADDED** via new reusable `flickrLargest` — swap the size suffix
  to `_b` (Large 1024). ~2.5× the `_z` (640) baseline area; FIRST non-Recollect collection of the sweep.

## Raw record sample (key redacted)

| field | value |
|-------|-------|
| large_thumbnail_url | `https://live.staticflickr.com/8219/8267849140_e386a9d083_z.jpg` (= Medium 640) |
| object_url | `null` |
| landing_url | `https://www.flickr.com/photos/<userId>/<photoId>/in/pool-teara/` |

URL shape: `https://live.staticflickr.com/<server>/<photoId>_<secret>[_<size>].jpg`. DigitalNZ harvests
the **`_z` (640px)** derivative. `object_url` is null (no direct original), so the legacy
`objectUrlDirect` Flickr approach does not apply here.

## Live site investigation (Discovery Playbook)

**Flickr size-suffix / secret rules** (confirmed: Flickr official "Photo Image URLs"
<https://www.flickr.com/services/api/misc.urls.html> + The Mighty Cribb + nitinhayaran gist):
- Sizes: `_z`=640, `_c`=800, `_b`=1024, `_h`=1600, `_k`=2048, `_o`=original.
- **Secret sharing:** `_b`, `_c`, `_z` and every size **below** `_h` share the photo's **base
  secret**. `_h` and `_k` each use their **own unique secret**. `_o` uses `originalsecret`.
  ⇒ `_b` (1024) is the largest size reachable by a **pure string swap** on the harvested URL;
  anything larger needs an alternate per-photo secret, only obtainable from the photo page model
  JSON or the `flickr.photos.getSizes` API (needs an API key).
- **Flickr never upscales:** requesting a size larger than the original returns the original at that
  size's URL (verified: a 600px-original photo returns 600×400 at its `_b` URL — HTTP 200, not 404).
  So `_z`→`_b` is safe for **every** record and never 404s.

**Empirical same-secret swap (photo 8267849140):** `_z`→`_c`(800)→`_b`(1024) all HTTP 200 on the
shared secret `e386a9d083`; `_h`/`_k`/`_o` all **HTTP 410** on that secret. The photo page exposes a
larger `_h` (1600) but only under a **different** secret (`69ec4dd031`) — confirming the rule.

**Max-size distribution (page-scrape, two uniform samples, n=63 total across pages 50–1180):**
| max size available | count |
|--------------------|-------|
| `_b` (1024) | 56 |
| `_c` (800)  | 4 |
| `_z` (640)  | 3 |
| `_h`/`_k`/`_o` (>1024) | **0** |

⇒ **0/63 photos exceed 1024px.** The Te Ara pool is overwhelmingly web-resolution uploads capped at
1024 (the lone 1600px `_h` photo was a non-uniform front-of-list hand-pick). Chasing >1024 via
per-request page-scraping would add an HTML fetch + parse on 100% of requests (plus fragility to
Flickr page-structure changes) for ≈0% resolution benefit → rejected.

## Decision

**ADD via `flickrLargest` = swap the size token to `_b`.** Captures the true max for ~98%+ of photos
(min(1024, original)), zero extra requests, universally safe (no 404, no upscaling), no API key, no
scraping. Baseline `_z` 640 → `_b` 1024 = **2.56× area**. Page-scrape-for-true-max was evaluated and
rejected (0/63 benefit). `object_url` route N/A (null).

## Implementation

- `URLProcessor`: new reusable `flickrLargest(_:_:)` — guards `staticflickr.com`; splits the filename
  on `_` (id/secret never contain `_`); 3+ parts ⇒ replace the trailing size token with `b`, 2 parts
  (no size token, the `_500` default) ⇒ append `_b`; rebuild as `..._b.jpg`. Returns the URL
  unchanged if not a staticflickr `.jpg`.
- `URLProcessor.strategies`: added `"Ministry for Culture and Heritage Te Ara Flickr" → flickrLargest`.
- `NZImageApi.collectionWeights`: added `"Ministry for Culture and Heritage Te Ara Flickr": 0.015`
  (provisional; ~proportional to 15,714 items; final renormalization at end).
- No `recollectDomainMap` change (not Recollect).

## Verification

`swift build` exit 0. `CollectionTester "Ministry for Culture and Heritage Te Ara Flickr"` ×3 (fresh
server, :7000 freed between): **3/3 HTTP 200, `Content-Type: image/jpeg`, File Type JPEG**, all `_b`.
Processed `_b` vs `_z` baseline: 11250520265 **1024×768 (0.79 MP)** vs 640×480 (0.31); 18607409488
**1024×683 (0.70 MP)** vs 640×427 (0.27); 15638754722 **685×1023 (0.70 MP)** vs 428×639 (0.27).
All ≥ 2.5× baseline area.

## Commit

`c47ae4e` — Add Ministry for Culture and Heritage Te Ara Flickr via flickrLargest (_b/1024).
User-approved 2026-06-06.
