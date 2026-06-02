# 008 — Hocken Digital Collections

- **Group:** B (ADD — not previously in the Lambda)
- **Platform:** recollect (Axiell Recollect) — `hocken.recollect.co.nz`
- **DigitalNZ result_count:** 56,710 (live)
- **Timestamp:** 2026-06-02
- **Outcome:** **ADDED** via new `recollectDisplayMax` strategy (serve `/assets/display/<id>-max`).
  Win: ~2000px (2–6 MP) vs the ~1 MP `-600` baseline; no big master available.

## Raw record sample (key redacted)

| field | value |
|-------|-------|
| large_thumbnail_url | `https://hocken.recollect.co.nz/assets/display/746-600` |
| landing_url | `https://hocken.recollect.co.nz/nodes/view/2994` |
| object_url | `null` |

Host `hocken.recollect.co.nz`, `/assets/display/<assetId>-600`; asset id in large_thumbnail_url.

## Live site investigation (Discovery Playbook)

- **No migration/login;** `display/<id>-600` returns 200 directly.
- **Thumb-id master disabled:** `downloadwiz/<thumbId>` = 404 for **42/42** sampled.
- **NAM-style two-asset structure exists** (og:image id ≠ thumb id; og-id `downloadwiz` = 200 for
  12/12) — BUT it does not help here: the og id resolves to the **same image** as the thumb
  (82078 `-max` == 185309 `-max`, byte-identical), and the og "master" is itself capped (≈2500px,
  often == og `-max`), sometimes **smaller** than the thumb `-max`. No big originals like Hastings
  (Hocken downloadwiz tops ~2500px, not 5000–9000px).
- **`-max` is the practical ceiling (~2000px) and beats `-600`.** Systematic 18-record sample
  (pixel area, MP):
  | thumb | `-600` | `-max` | og-master |
  |-------|--------|--------|-----------|
  | 766 | 1.3 | **5.2** | 4.9 |
  | 769 | 0.8 | 3.0 | **4.2** |
  | 933 | 0.8 | 3.1 | **5.0** |
  | 216720 | 1.5 | **6.1** | 2.4 |
  | 249226 | 0.8 | 2.4 | **4.8** |
  | 254683 | 0.7 | 2.4 | **4.5** |
  `-max` ≥ `-600` for the whole sample (2–4× typical). `-max` vs og-master is mixed (neither
  dominates); og-master needs a per-request landing fetch + is the same image → not worth it.
- **Caveat (rare):** for a small-original subset (older asset-id batch, e.g. 110978) `-600` is
  **upscaled** beyond the true original, so `-max` (the true ~1024px original) has fewer *pixels*
  than the upscaled `-600`. `-max` is the honest resolution; this affects a minority and trades
  fake interpolated pixels for real ones.

## Decision

**ADD via `recollectDisplayMax`** — rip the asset id from `large_thumbnail_url`, serve
`/assets/display/<id>-max` directly (no `downloadwiz` probe, since the thumb master is always 404
here — a probe would waste a round-trip every request). Gives ~2000px (2–6 MP), a clean 2–4× win
over the Group-B baseline raw `-600`. The og:image-master route was evaluated and rejected
(marginal/mixed gain, same image, extra latency).

## Implementation

- `URLProcessor`: new reusable `recollectDisplayMax(_:_:)` (rip id → `/assets/display/<id>-max`).
- `URLProcessor.recollectDomainMap`: added `"Hocken Digital Collections": "hocken.recollect.co.nz"`.
- `URLProcessor.strategies`: added `"Hocken Digital Collections" → recollectDisplayMax`.
- `NZImageApi.collectionWeights`: added `"Hocken Digital Collections": 0.05` (provisional; large
  collection; final renormalization at end).

## Verification

`swift build` exit 0. `CollectionTester "Hocken Digital Collections"` ×3 (fresh server, :7000 freed
between): **3/3 HTTP 200** `-max`. Processed decoded dims vs baseline: 253402 `-max` 1297×1816
(2.4 MP) vs `-600` 1.4 MP; 45951 `-max` 1999×1501 (3.0 MP) vs 0.7 MP; 99153 `-max` 1024×730
(0.7 MP) vs `-600` 0.7 MP (small original, ~equal). All ≥ baseline.

## Commit

`52dc5f4` — Hocken Digital Collections: add via recollectDisplayMax (serve -max derivative).
User-approved 2026-06-02.
