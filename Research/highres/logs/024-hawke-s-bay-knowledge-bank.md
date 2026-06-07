# 024 — Hawke's Bay Knowledge Bank

- **Group:** A (re-check, already in Lambda; legacy `switch` → suffix-strip + weserv proxy)
- **Platform:** Knowledge Bank CMS (`www.knowledgebank.org.nz`), images on `cdn.knowledgebank.org.nz`
- **DigitalNZ result_count:** 29,050 (live, 2026-06-07)
- **Timestamp:** 2026-06-07
- **Outcome:** **improvement + bug fix.** The shipped strategy weserv-proxied the image, but **weserv
  404s on this CDN** → broken (404) for every record. New `knowledgeBankMaster` serves the honest native
  `/master/` original (up to ~76 MP) when published, else the honest harvested URL — both **direct**.
  Migrated legacy switch → registry. **User chose "master-first, 800px fallback"** (purest honest-native;
  never the upscaled `/images/<base>.jpg` rendition).

## Raw record sample (key redacted)

| field | value |
|-------|-------|
| large_thumbnail_url | `https://cdn.knowledgebank.org.nz/node/782471/images/mahoraschool1896-2_333-800x525.jpg` (≈800 px) |
| object_url | `null` |
| landing_url | `https://www.knowledgebank.org.nz/still_image/<slug>/` (per-record) |

The harvested URL is `cdn.knowledgebank.org.nz/node/<nodeId>/images/<file>`. The `<file>` is usually
`<base>-WxH.jpg` (≈800 px long side), sometimes `<base>-WxH-<n>.jpg` (dedup) or already the bare
`<base>.jpg`. The `<base>` is either a lowercased original name or the **node id** (`46746-800x538.jpg`).

## Live site investigation (Discovery Playbook)

The CDN serves three tiers (seen in the landing HTML):
1. `…/images/<base>-WxH.jpg` — fixed-size derivatives (harvest = the ~800 px one).
2. `…/images/<base>.jpg` — a **fixed 1400/1800 px rendition** that **UPSCALES small originals**
   (fake interpolated pixels). E.g. node 371784: this is 1800×1689 but the true master is only 648×608.
3. `…/master/<OriginalCaseName>.jpg` — the **true original** (honest native), variable size (648 px –
   10575×7232 = 76.5 MP observed), only published for a subset of records (batch-dependent).

- **weserv 404s on `cdn.knowledgebank.org.nz`** for BOTH the derivative and the original (verified
  multiple encodings) → the shipped `strip+weserv` strategy returned 404 for every record. The CDN has
  **no hotlink protection** (direct GET with no referer → 200), so serve **direct**.
- The master filename keeps the **original upload casing/name**, which the lowercased (or node-id-named)
  `/images/` URL does not carry — so the master URL **cannot** be built by string-munging the harvest; it
  must be read from the landing page. The landing must be fetched on the **`www`** host (the bare host can
  return a page without the CDN links).
- Master selection: collect `/node/<nodeId>/master/…` links; **exactly one → use it** (single-image
  record, handles the node-id-named `/images/` case where stems can't match); **several → stem-match** the
  harvested base (case-insensitive; the `/images/` base may carry a trailing `-<n>` the master lacks).

## Candidate measurements — uniform sample (20 records, pages 1/40/120/200/280)

`curl | sips` decoded px. 800 deriv (harvest) vs the fixed `/images/<base>.jpg` ("imgstrip") vs the
stem/single-matched `/master/`:

- master published for **11/20**; of those **9** are larger than the 800 px harvest (1578–1920 px;
  e.g. 45596xxx 1920×1352–1440, node 46746 1412×949) and **2** are honest-smaller (648×608, 777×619 —
  where the 800 px derivative is itself a fake upscale).
- the fixed `/images/<base>.jpg` rendition is always 1400/1800 px but **upscales** the small-original
  records (fake pixels) — so it is NOT used as a fallback (per the user's choice).
- 9/20 records have **no** published master (e.g. the `spillerp…`/`hillca…` batches) → honest harvested
  fallback.

Tester cross-check (~19 runs): masters served where present — up to **10575×7232 (76.5 MP)** (node 36672,
`HannaVF1149_SmithReunion_Sawmill.jpg`) and 1412×949; honest-small masters served too (800×548 originals);
no-master records served the honest harvested URL. All **HTTP 200 direct**.

## Decision

**`knowledgeBankMaster` (user-approved "master-first, 800px fallback", 2026-06-07):** fetch the landing
(www), serve the honest `/master/` original (direct) when published, else the harvested URL (direct).
Never the upscaled `/images/<base>.jpg` rendition. Strict win on two axes: (1) **fixes** the broken
weserv-404 the Lambda was shipping; (2) lifts ~half the records (those with a published master) to the
honest native original (often multi-MP, up to 76 MP). Honest pixels throughout (consistent with the Kura
16 / eHive 17 honest-native choices).

## Implementation

- `URLProcessor.swift`: new `knowledgeBankMaster(_:_:)` (async, non-throwing). Extract nodeId + base from
  the harvested `/node/<id>/images/<file>`; fetch the www landing via `NetworkRequestManager.fetchHTML`;
  `NSRegularExpression` for `/node/<id>/master/<stem>.(jpg|jpeg|png)`; single-master → use it, multi →
  stem-match (base or `-<n>`-stripped variant); fallback to the harvested URL. Registry entry added;
  legacy `case "Hawke's Bay Knowledge Bank"` (strip + weserv) removed (switch → registry migration).
- Weight unchanged (Group A, 0.029).
- Per-request cost: one bounded landing-HTML GET (same class as the Recollect og:image / TAPUHI scrapes);
  never downloads the image.

## Verification

- `swift build` → exit 0.
- `swift run CollectionTester "Hawke's Bay Knowledge Bank"` (~19 runs across iterations): all HTTP 200.
  Masters served where published (10575×7232 = 76.5 MP; 1412×949; honest-small 800×548); no-master
  records served the honest harvested URL. Direct serving (no weserv); no tester HEAD-timeout issues.

## Commit

(pending)

## Follow-up

Master publication is batch-dependent (~half of the sampled records). If Knowledge Bank later publishes
masters for the `spillerp…`/`hillca…` batches, those records would automatically upgrade (no code change
needed — the strategy already scrapes for a master every request).
