# 007 — Lower Hutt MyRecollect

- **Group:** B (ADD — not previously in the Lambda)
- **Platform:** recollect (Axiell Recollect) — `huttcity.recollect.co.nz`
- **DigitalNZ result_count:** 2,150 (live)
- **Timestamp:** 2026-06-02
- **Outcome:** **ADDED** via `recollectLargest`. Win: masters ~5000px (3.9–28 MP) vs ~1 MP `-600`.

## Raw record sample (key redacted)

| field | value |
|-------|-------|
| large_thumbnail_url | `http://huttcity.recollect.co.nz/assets/display/12819-600` |
| landing_url | `http://huttcity.recollect.co.nz/nodes/view/2905` |
| object_url | `null` |

Host `huttcity.recollect.co.nz`, `/assets/display/<assetId>-600`; asset id in large_thumbnail_url.

## Live site investigation (Discovery Playbook)

- **No migration/login.** (One page-1 id, 12819, 302→"Requested Asset does not exist" 404 — a
  *dead record*, not a host migration; see below.)
- **Masters present for ~all live records:** `downloadwiz/<id>` (HEAD-follow) = 200 for **25/25**
  sampled across pages 2–105. Masters are ~5000px-wide originals (octet-stream), far larger than the
  ~1000px `-600`:
  | id | baseline `-600` | `downloadwiz` master |
  |----|-----------------|----------------------|
  | 252 | 1000×756 | **5000×3780 (18.9 MP)** |
  | 33 | 999×551 | **5000×2757 (13.8 MP)** |
  | 27 | 1000×731 | **5000×3656 (18.3 MP)** |
- **Dead records (CAT3):** ids 12819, 7314 (page 1) → `-600` and `downloadwiz` both 404 ("Requested
  Asset does not exist"). A small minority; broken under any strategy (deleted at source).
- og:image id == thumb id (no NAM-style second asset). No IIIF/zoom.

## Decision

**ADD via `recollectLargest`.** Same proven Recollect strategy: rip the asset id from
`large_thumbnail_url`, HEAD-probe `downloadwiz` (200 ⟺ master) → serve master, else
`/assets/display/<id>-max`. Strict win over the Group-B baseline (raw `-600`, ~1 MP): masters
3.9–28 MP for the live majority; `-max` working fallback for any master-less record; only the
~few-% dead records 404 (unfixable).

## Implementation

- `URLProcessor.recollectDomainMap`: added `"Lower Hutt MyRecollect": "huttcity.recollect.co.nz"`.
- `URLProcessor.strategies`: added `"Lower Hutt MyRecollect" → recollectLargest`.
- `NZImageApi.collectionWeights`: added `"Lower Hutt MyRecollect": 0.002` (provisional).

## Verification

`swift build` exit 0. `CollectionTester "Lower Hutt MyRecollect"` ×3 (fresh server, :7000 freed
between): **3/3 HTTP 200** masters. Processed decoded dims: 6615 **5964×4762 (28.4 MP)**, 7728
**5000×3780 (18.9 MP)**, 24572 **2410×1605 (3.9 MP)** — all beat baseline `-600` (~1 MP).

## Commit

User-approved 2026-06-02. SHA recorded after commit.
