# 010 — He Purapura Marara Scattered Seeds

- **Group:** A (re-check, already in Lambda; `collectionWeights` 0.005)
- **Platform:** recollect (Axiell Recollect) — `dunedin.recollect.co.nz` (Dunedin Public Libraries)
- **DigitalNZ result_count:** 10,744 (live, 2026-06-06)
- **Timestamp:** 2026-06-06
- **Outcome (awaiting approval):** **migrate to `recollectLargest`** — a robustness/correctness
  improvement (NOT a resolution gain on the common path).

## Raw record sample (key redacted)

| field | value |
|-------|-------|
| large_thumbnail_url | `http://dunedin.recollect.co.nz/assets/display/203248-600` |
| landing_url | `http://dunedin.recollect.co.nz/nodes/view/200808` |
| object_url | `null` |

Host `dunedin.recollect.co.nz`, `/assets/display/<assetId>-600`; asset id in large_thumbnail_url.

## Current production strategy (baseline)

Legacy `switch` case **shared with Tāmiro**: `recollectDownloadUrlString(from:collection:)` — rip id
between `display/` and `-600`, return `https://dunedin.recollect.co.nz/assets/downloadwiz/<id>`.
**No HEAD probe / no fallback.** (This is the same no-fallback pattern that was found broken and
replaced by `recollectLargest` for Tauranga / Hastings / Lower Hutt.)

## Live site investigation (Discovery Playbook)

Three record categories (downloadwiz = master probe; `-600`/`-max` = display tier):

- **CAT1 — public, master present (~90%).** `downloadwiz/<id>` raw HEAD = **200**
  (`application/octet-stream` JPEG original). The master is **3–23× the display tier**.
  `-600` == `-max` byte-identical (~1000px hard cap).
  | id | downloadwiz master | `-600`/`-max` |
  |----|--------------------|----------------|
  | 201540 | **4850×2920 (14.2 MP)** | 1000×602 (0.6 MP) |
  | 202450 | **4223×2576 (10.9 MP)** | 998×609 (0.6 MP) |
  | 200388 | **2049×1592 (3.3 MP)** | 999×776 (0.8 MP) |

- **Restricted / login-walled (~10%).** `nodes/view/<n>` **302 → `/users/login`** ("Login | Dunedin
  Public Libraries"); `downloadwiz`, `display/<id>-600`, `-max`, `-thumbnail` all **404** anonymously.
  No og:image (login stub). These are community uploads not publicly released — **unfixable
  anonymously** (verified 209319, 209320 → login). Not deleted; just private.

- **CAT2 — public, no master (~0.6%, rare but real).** `downloadwiz` 302→404 while `display/<id>-600`
  and `-max` = **200** (e.g. 435039 = 600×600). The current bare-`downloadwiz` strategy emits the
  **broken 404** for these; `-max` is the true (small) ceiling and works.

**Sampling:** first pass pages 1/3/6/10/15/20/30 (70 ids) hit a restricted-heavy block (39
restricted, 30 CAT1, 1 CAT2). A second **uniform** pass across pages 2/50/120/250/400/550/700/850/
1000/1070 (100 ids) gave **90 CAT1 / 10 restricted / 0 CAT2** → true rates ≈ 90% / 10% / <1%.

**NAM two-asset trick: not applicable.** CAT1 already exposes the master via downloadwiz on the
indexed id (no need to scrape og:image). Restricted records' nodes are login-walled (no og:image).

## Decision

**Migrate to `recollectLargest`** (HEAD-probe `downloadwiz`; if 200 → master, else `-max`). This is a
**strict improvement** with no regression:

| category | baseline (bare downloadwiz) | recollectLargest | delta |
|----------|------------------------------|------------------|-------|
| CAT1 ~90% | master (200) | master (200) | **unchanged** (already the ceiling) |
| CAT2 ~0.6% | **broken 404** | `-max` image (200) | **FIXED** |
| restricted ~10% | 404 | 404 (`-max`) | unchanged (login-walled at source) |

> **Honesty note:** resolution on the dominant CAT1 path is **unchanged** — the baseline already
> served the downloadwiz master. The value of this change is (a) fixing the rare CAT2 records that
> currently serve a broken 404, and (b) consistency with the other healthy Recollect collections
> (one shared, tested strategy + `-max` safety net). Cost: one extra HEAD round-trip per request
> (bounded light HTTP, permitted by the plan). This differs from **Tāmiro** (order 9), which had
> **0** CAT2 records → there the probe would be pure waste, so Tāmiro stayed no-improvement.

## Implementation

- `URLProcessor.strategies`: added `"He Purapura Marara Scattered Seeds" → recollectLargest`.
- `URLProcessor` legacy `switch`: removed `"He Purapura Marara Scattered Seeds"` from the
  Tāmiro-shared case (now `case "Tāmiro":` alone).
- `recollectDomainMap`: already contained `"He Purapura Marara Scattered Seeds": "dunedin.recollect.co.nz"` (no change).
- `NZImageApi.collectionWeights`: already present at 0.005 (Group A re-check; no weight change; final renormalization at end).

## Verification

`swift build` exit 0. `CollectionTester "He Purapura Marara Scattered Seeds"` ×3 (fresh server,
:7000 freed between): **3/3 HTTP 200** downloadwiz masters. Processed decoded dims vs `-600` baseline:
422907 **2645×1763 (4.7 MP)** vs 999×666 (0.7 MP); 451175 **1334×2000 (2.7 MP)** vs 1000×1499
(1.5 MP); 202327 **1926×1301 (2.5 MP)** vs 999×675 (0.7 MP). Masters are octet-stream JPEGs that
decode cleanly (sips) and render in `<img>` (same as the approved Tauranga/Hastings/Lower Hutt masters).

## Commit

(pending user approval)
