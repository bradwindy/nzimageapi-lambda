# 006 — Hastings Recollect

- **Group:** B (ADD — not previously in the Lambda)
- **Platform:** recollect (Axiell Recollect) — `hastings.recollect.co.nz`
- **DigitalNZ result_count:** 3,979 (live)
- **Timestamp:** 2026-06-02
- **Outcome:** **ADDED** via `recollectLargest` (downloadwiz master, `-max` fallback). Big win:
  masters 1.5–59 MP vs the ~1 MP `-600` baseline.

## Raw record sample (key redacted)

| field | value |
|-------|-------|
| large_thumbnail_url | `https://hastings.recollect.co.nz/assets/display/47013-600` |
| landing_url | `http://hastings.recollect.co.nz/nodes/view/7963` |
| object_url | `null` |

All sampled records: host `hastings.recollect.co.nz`, `/assets/display/<assetId>-600`. Asset id is
in the large_thumbnail_url; og:image id == thumb id (no NAM-style second asset).

## Live site investigation (Discovery Playbook)

- **Healthy Recollect (no migration/login):** `display/<id>-600` returns HTTP 200 `image/jpeg`
  directly (contrast Presbyterian, order 5, which had migrated + login-walled).
- **Masters available for ~96%:** `downloadwiz/<id>` (HEAD-follow) = 200 for **24/25** sampled
  records. The lone exception (id 47062) is a fully **dead** record — `downloadwiz`, `-600` AND
  `-max` all 404 (CAT3, deleted at source; ~4%). No clear master-less-but-display-working (CAT2)
  records in-sample, but `recollectLargest` handles that case too (falls to `-max`).
- **Masters are large originals** (`downloadwiz`), far bigger than the ~1000px display tier:
  | id | baseline `-600` | `downloadwiz` master |
  |----|-----------------|----------------------|
  | 47024 | 1000×661 (0.66 MP) | **7101×4696 (33.3 MP)** |
  | 47417 | 1000×1499 | **4748×7120 (33.8 MP)** |
  | 53452 | 999×773 | **4853×3755 (18.2 MP)** |
  | 56780 | 999×1225 | **3594×4405 (15.8 MP)** |
  | 59224 | 1000×666 | **1516×1010 (1.5 MP)** |
  Served `application/octet-stream` (downloadable master, renders in `<img>` — same as Tauranga).
- **`-max` is the display ceiling (~1000px wide)** for master-less records, so `recollectLargest`'s
  fallback yields a working ~1 MP image where a master is absent.

## Decision

**ADD via `recollectLargest`** (the Tauranga strategy): rip the asset id from `large_thumbnail_url`,
HEAD-probe `downloadwiz` following redirects (200 ⟺ master), serve the master else `/assets/display/<id>-max`.
This is a strict win over the Group-B baseline (raw `-600`, ~1 MP): masters are 1.5–59 MP for ~96%
of records; master-less records still get a working `-max`; only the ~4% dead records are
unfixable (broken under any strategy).

## Implementation

- `URLProcessor.recollectDomainMap`: added `"Hastings Recollect": "hastings.recollect.co.nz"`.
- `URLProcessor.strategies`: added `"Hastings Recollect" → recollectLargest`.
- `NZImageApi.collectionWeights`: added `"Hastings Recollect": 0.004` (provisional; final
  renormalization pass at end of sweep).

## Verification

`swift build` exit 0. `CollectionTester "Hastings Recollect"` ×3 (fresh server each, :7000 freed
between): **3/3 HTTP 200**, all `downloadwiz` masters. Processed-URL decoded dims: 73633 1547×981
(1.5 MP), 67013 **9293×6378 (59.3 MP)**, 46668 **6849×4655 (31.9 MP)** — all beat baseline `-600`
(~1 MP).

## Commit

User-approved 2026-06-02. SHA recorded after commit.
