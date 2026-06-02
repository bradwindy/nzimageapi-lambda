# 009 — Tāmiro

- **Group:** A (re-check, already in Lambda)
- **Platform:** recollect (Axiell Recollect) — `massey.recollect.co.nz`
- **DigitalNZ result_count:** 5,628 (live)
- **Timestamp:** 2026-06-02
- **Outcome:** **no-improvement** — the current `downloadwiz` strategy already serves the master
  (~2700px, 5 MP) for ~all records; the master is the maximum. No code change.

## Raw record sample (key redacted)

| field | value |
|-------|-------|
| large_thumbnail_url | `http://massey.recollect.co.nz/assets/display/268849-600` |
| landing_url | `http://massey.recollect.co.nz/nodes/view/22008` |
| object_url | `null` |

Host `massey.recollect.co.nz`, `/assets/display/<assetId>-600`; asset id in large_thumbnail_url.

## Current production strategy (baseline)

Legacy `switch` case (shared with He Purapura): `recollectDownloadUrlString(from:collection:)` —
rip id between `display/` and `-600`, return `https://massey.recollect.co.nz/assets/downloadwiz/<id>`.
No HEAD probe / no fallback.

## Live site investigation (Discovery Playbook)

- **No migration/login.** `display/<id>-600` serves directly.
- **Masters present for ~100%:** `downloadwiz/<id>` = 200 for **75/75** sampled across ~12 pages.
  No master-less (CAT2) or dead (CAT3) records found in-sample.
- **Masters are ~2700px originals (≈5 MP)**, far larger than the capped display tier:
  | id | `-600` (= `-max`) | `downloadwiz` master |
  |----|-------------------|----------------------|
  | 155518 | 999×691 (0.7 MP) | **2696×1864 (5.0 MP)** |
  | 155524 | 1000×678 (0.7 MP) | **2684×1820 (4.9 MP)** |
  | 155526 | 999×689 (0.7 MP) | **2692×1856 (5.0 MP)** |
  | 155552 | 1000×687 (0.7 MP) | **2684×1844 (4.9 MP)** |
  `-600` and `-max` are byte-identical (~1000px ceiling); `downloadwiz` is the largest source.

## Decision

**no-improvement.** The existing strategy already returns the `downloadwiz` master — the largest
available (~5 MP, 7× the display derivative). No alternative beats it. The strategy has no `-max`
fallback, but 75/75 sampled records have masters, so no broken records were observed; adding
`recollectLargest`'s HEAD probe would only add a wasted round-trip on every request (downloadwiz is
uniformly 200). → No Swift change.

> Note (not acted on): if a future re-check finds master-less Tāmiro records (downloadwiz 404),
> migrate this case to `recollectLargest` for the `-max` fallback. Not warranted now.

## Implementation

None (no code change). Strategy retained as-is in the legacy `switch` (shared with He Purapura,
order 10).

## Verification

No code change. `CollectionTester "Tāmiro"` ×2 confirmed the current pipeline serves `downloadwiz`
masters (158480, 111239) at **HTTP 200**. Production output unchanged.

## Commit

`062719b` — Investigate Tāmiro: existing downloadwiz already serves the master (no code change).
User-approved no-improvement 2026-06-02.
