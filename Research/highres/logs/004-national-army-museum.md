# 004 — National Army Museum

- **Group:** A (re-check, already in Lambda)
- **Platform:** recollect (Recollect — Recollect Ltd / NZMS, NOT Axiell) — `nam.recollect.co.nz`
- **DigitalNZ result_count:** 14,035 (live)
- **Timestamp:** 2026-06-02
- **Outcome:** **no-improvement** — the existing og:image→downloadwiz strategy already serves the
  master (the maximum available); no code change.

## Raw record sample (key redacted)

| field | value |
|-------|-------|
| large_thumbnail_url | `https://nam.recollect.co.nz/assets/display/13722-600` |
| landing_url | `https://nam.recollect.co.nz/nodes/view/8855` |
| object_url | `null` |

All 20 sampled records: host `nam.recollect.co.nz`, `large_thumbnail_url` =
`/assets/display/<assetId>-600`, landing `/nodes/view/<node>`.

## Current production strategy (baseline)

`case "National Army Museum"` in `URLProcessor`: fetch the landing page HTML, read `og:image`
(`/assets/display/<ogId>-max`), rip `<ogId>`, return `https://nam.recollect.co.nz/assets/downloadwiz/<ogId>`.
No fallback. (Reads `result.landingUrl`; per-request landing fetch.)

## Live site investigation (Discovery Playbook)

- **Two distinct asset ids per record.** The DigitalNZ `large_thumbnail_url` id (e.g. 13722, range
  ~13.7k–14.1k) is an **older/thumbnail asset with NO master**: `downloadwiz/<thumbId>` 404s
  ("goDownload failed") for **50/50** sampled, and `-600`==`-max` capped at width ~1000
  (13722 1000×816, 13715 1000×1038, 13651 999×527, …). The landing page's `og:image` points to a
  **different, newer primary asset** (e.g. 31444, range ~31.4k–31.6k) which **does** have a master.
- **og-id masters present for ~100% of records:** `downloadwiz/<ogId>` = HTTP 200 for **41/41**
  sampled nodes. So the current og:image→downloadwiz strategy resolves to a working master for
  effectively all records (and when no og:image exists, the code falls back to the `-600`
  large_thumbnail, which is a valid ~1000px image).
- **Master is the largest source.** downloadwiz masters (og id) decode to 1220×996, 1734×1800,
  2325×1226, 1192×1012, 1874×1218, 2680×1957 (1.2–5.2 MP) — i.e. **1.2×–5× the `-max` pixels**.
  Served `application/octet-stream` + `Content-Disposition: attachment`, JPEG (Exif), original
  filenames (e.g. `1997.55_A01_026_10964-996.jpg.jpg`) ⇒ these are NAM's uploaded originals.
  `-max` of the og id is still capped at ~1000px (1000×816, 999×527, …), so the master is the
  ceiling. No IIIF/zoom/tile source. Recollect exposes nothing larger than downloadwiz.
- **The landing fetch is unavoidable:** the master only exists under the og-id, which is NOT
  derivable from the large_thumbnail id (different asset upload) — so `recollectLargest` (which rips
  the large_thumbnail id) would *regress* NAM to the ~1000px `-max`. The current strategy is correct
  to scrape og:image.

## Candidate measurements (decoded pixels)

| candidate | example dims | notes |
|-----------|--------------|-------|
| **baseline** og:image→downloadwiz (og id master) | 1220×996 … 2680×1957 | current production = master = ceiling |
| `-max` / `-600` (og id) | ~1000px wide | capped display derivative |
| `downloadwiz` on large_thumbnail id | — | 404 (50/50; that asset has no master) |
| `-max` / `-600` on large_thumbnail id | ~1000px wide | capped |

## Decision

**no-improvement.** The current og:image→downloadwiz strategy already delivers the master (the
original upload), which is 1.2×–5× larger than any display derivative and is the largest source
Recollect exposes. No alternative (large_thumbnail-id master, `-max`, IIIF) beats it. → No Swift
change.

> Note (not acted on): the current strategy has no explicit fallback if an og-id master 404s, but
> 41/41 sampled records had a master, and the no-og:image branch already falls back to a valid
> ~1000px image — so no broken-record fix was warranted. If a future re-check finds og-id masters
> missing for some records, add a `-max` fallback (HEAD-probe downloadwiz on the og id).

## Implementation

None (no code change). Strategy retained as-is in the legacy `switch`.

## Verification

No code change. Baseline behaviour confirmed live: og:image→downloadwiz resolves to a 200
`application/octet-stream` JPEG master (1.2–5.2 MP) for all sampled records; production output
unchanged.

## Commit

`98a7ea0` — Investigate National Army Museum: current og:image->downloadwiz already optimal (no
code change). User-approved no-improvement 2026-06-02 (Research/highres bookkeeping only).

> Follow-up requested by user after this approval: re-check Antarctica (order 2) for the same
> two-asset / og:image-master pattern. See logs/002 addendum.
