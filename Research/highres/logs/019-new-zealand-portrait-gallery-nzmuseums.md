# 019 — New Zealand Portrait Gallery NZMuseums

- **Group:** B (add; not yet in the Lambda)
- **Platform:** eHive (Vernon Systems) — `images.ehive.com` (account **3272**); NZMuseums front-end
- **DigitalNZ result_count:** 136 (live, 2026-06-07)
- **Timestamp:** 2026-06-07
- **Outcome:** **ADD via `ehiveIIIFLargest`** (same strategy as Mataura 18 / Howick 17) — eHive's public
  IIIF master TIFF serves the full native (up to ~21 MP) for **every** record. **24/24 uniform win, 0
  honest-smaller, 0 failures** — the cleanest eHive result so far (a portrait gallery uploads big masters).

## Raw record sample (key redacted)

| field | value |
|-------|-------|
| large_thumbnail_url | `https://images.ehive.com/accounts/3272/objects/images/03f856d0a28542c092607e757db59a16_l.jpg` |
| object_url | `null` (all 136) |
| landing_url | `https://ehive.com/collections/3272/objects/555027` |

Mix of UUID-style ids (`03f856d0…_l.jpg`) and `<id>_<token>_l.jpg`. Rights facet: **136 / 136 "All
rights reserved"** — irrelevant, the IIIF master endpoint is not rights-gated.

## Live site investigation

- Same eHive shape as Mataura/Howick. The IIIF service is live for account 3272: `info.json` at
  `https://iiif.ehive.com/iiif/2/accounts%2f3272%2fobjects%2fimages%2f<id>.tif/info.json` → 200, IIIF
  2.0 level2, native dims declared. (The landing-page `iiif` ref is JS-loaded so a raw-HTML grep misses
  it, but the endpoint itself is confirmed live and `/full/full/` returns the native master.)
- `ehiveIIIFLargest` applies unchanged.

## Candidate measurements — uniform sample (24 of 136, pages 1–2)

`curl | sips` decoded px; `_l` baseline vs IIIF `/full/full/`:

| outcome | count | range | examples |
|---------|------:|-------|----------|
| win | **24** | 1.27×–49.3× | `1e4r1dr_9jeq` `_l` 800×533 → **5616×3744** (49.3×); `03f856d0…` 607×800 → 3953×5211 (42.4×); `c07c71e2…` → 5140×3427 (41.3×) |
| equal | 0 | — | — |
| honest-smaller | 0 | — | (none — unlike Howick) |
| IIIF non-200 | 0 | — | — |

Most records are multi-MP masters (5–21 MP); the smallest win was 1.27× (`4e236f_dulp` 800×528 →
900×594). No upscaled-`_l` anomalies in this collection.

## Decision

**ADD** via `ehiveIIIFLargest` (the shared eHive IIIF strategy). Strict win on every sampled record,
browser-displayable `image/jpeg`, no rights gate, no request-time fetch.

## Implementation

- `URLProcessor.swift`: registry entry `"New Zealand Portrait Gallery NZMuseums" → ehiveIIIFLargest`
  (no new code — reuses the function added for Mataura 18).
- `NZImageApi.collectionWeights`: add `"New Zealand Portrait Gallery NZMuseums": 0.001` (provisional).

## Verification

- `swift build` → exit 0.
- `swift run CollectionTester "New Zealand Portrait Gallery NZMuseums"` ×3 → all HTTP 200, `image/jpeg`,
  JPEG (e.g. `190uju_9jfj`, `1ga2e86_ckfp`, `4e236f_dulp` → IIIF `/full/full/` URLs).

## Commit

`5b060bd` — Add New Zealand Portrait Gallery (eHive) via IIIF master TIFF (1.27x-49.3x over _l).
User-approved 2026-06-07.
