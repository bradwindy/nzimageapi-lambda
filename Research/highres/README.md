# High-Resolution Collection Sweep — Durable Record

This directory is the **single source of truth** for the high-res collection sweep.
A fresh Claude Code session with zero prior context can resume the work using only
these files.

## Current resume state (updated 2026-06-06)

**Wellington removal: done.** Collections **1–17 terminal**; **NEXT → order 18: Mataura Museum
NZMuseums** (eHive / NZMuseums, Group B add). `progress.json` is authoritative; this is a human summary.

| # | collection | platform | outcome |
|---|------------|----------|---------|
| 01 | Tauranga City Libraries Other | recollect | committed — `recollectLargest` (master/-max) |
| 02 | Antarctica NZ DAM | recollect | no-improvement — masters disabled; user emailed to re-enable |
| 03 | National Publicity Studios | ndha (natlib) | no-improvement — 900px access copy is the ceiling |
| 04 | National Army Museum | recollect | no-improvement — existing og:image→downloadwiz already serves master |
| 05 | Presbyterian Research Centre | recollect | **blocked + REMOVED** — migrated to login-walled `pcanzarchives`; user to email for access |
| 06 | Hastings Recollect | recollect | committed ADD — `recollectLargest` (15–59 MP masters) |
| 07 | Lower Hutt MyRecollect | recollect | committed ADD — `recollectLargest` (~5000px masters) |
| 08 | Hocken Digital Collections | recollect | committed ADD — `recollectDisplayMax` (-max ~2000px) |
| 09 | Tāmiro | recollect | no-improvement — existing `downloadwiz` already serves 5 MP master |
| 10 | He Purapura Marara Scattered Seeds | recollect | committed — migrate to `recollectLargest` (fix rare CAT2; ~10% restricted/login-walled) |
| 11 | Ministry for Culture and Heritage Te Ara Flickr | flickr | committed ADD — new `flickrLargest` (swap → `_b`/1024, 2.5× area) |
| 12 | Alexander Turnbull Library Flickr | flickr | committed — no res gain (`object_url` `_o` original already served); migrated to registry + `_b` null fallback |
| 13 | Dunedin City Council Archives Flickr | flickr | committed ADD — general Flickr rule (`object_url` `_o`, up to 27.7 MP) |
| 14 | State Library of NSW Flickr | flickr | committed ADD — new `flickrLandingLargest` (page-scrape `_o`, up to 44.9 MP) |
| 15 | Australian National Maritime Museum Flickr | flickr | committed ADD — `object_url _o ?? flickrLandingLargest` (4–28 MP) |
| 11↻ | Te Ara Flickr (retrofit) | flickr | committed — `_b`→`flickrLandingLargest` (scrape `_h`/`_k`/`_o`; fixes stale-secret 410s) |
| 16 | Kura Heritage Collections Online | iiif (CONTENTdm) | committed — `/full/2048,/`(upscaled)→`/full/max/` honest native (≤2000px); migrated to registry |
| 17 | Howick Historical Village NZMuseums | eHive | no-improvement — `_l` 800px is the ceiling for ALL users (verified login); original sign-in-gated/absent. User emailing museum |

**Next up (order 18) — Mataura Museum NZMuseums** (Group B add; **eHive**; rawItemCount 3,422).
Same platform as Howick (eHive `images.ehive.com`). Per the `ehiveIIIF` recipe: `_l` (800px) is the
anonymous suffix max; the public ceiling is **per-account**, so DON'T assume Howick's 800px cap —
measure `_l`, check the DigitalNZ **rights facet** (Public Domain records on a full-access account
serve the original anonymously), and probe whether any record exceeds 800px before deciding
no-improvement vs add. Then order 19 (NZ Portrait Gallery, also eHive).

**eHive lesson (Howick):** `_l` (800px) is the anonymous suffix max; `_xl`/`_o`/etc → HTTP 500; no
public IIIF; REST API OAuth-gated; the original is sign-in-gated AND the per-account cap can apply to
signed-in users too (Howick caps everyone at 800px). The "Public Domain → original" exception is an
account setting, not guaranteed (Howick's 1 PD record is also capped).

**IIIF note (Kura):** for any IIIF service NEVER hardcode a width — `sizeAboveFull` makes a fixed
width > native UPSCALE (fake pixels). Read `info.json`; request `/full/max/`. (Kura's native is capped
at 2000px; no larger master via download endpoints.)

**Flickr cluster (orders 11–15) COMPLETE.** Final Flickr decision tree (in `recipes.md`): `object_url`
present → serve the `_o` original (free, no fetch — Turnbull 12, Dunedin 13, ANMM 15); `object_url`
null → `flickrLandingLargest` (scrape the photo page for `_h`/`_k`/`_o`, `_b` fallback — SLNSW 14, Te
Ara 11). Reusable registry helpers: `flickrLargest` (`_b` swap), `flickrLandingLargest` (page-scrape).
`getSizes` API is unavailable (Flickr Pro now required for a key). Legacy `switch` still holds: Tāmiro
(sole recollect occupant) + non-recollect cases (Auckland Libraries, Auckland Museum, Kura,
Canterbury/Culture Waitaki, Te Papa, passthrough group, TAPUHI, Hawke's Bay, Auckland Art Gallery,
National Army Museum).

**Reusable strategies in `URLProcessor` (registry):** `recollectLargest` (HEAD-probe `downloadwiz`
→ master, else `-max`; for instances WITH masters), `recollectDisplayMax` (rip id → `-max`, no
probe; for instances where the thumb `downloadwiz` is uniformly 404 but `-max` > `-600`, e.g.
Hocken). Recollect domains live in `recollectDomainMap`.

**Provisional weights pending final renormalization:** Hastings 0.004, Lower Hutt 0.002, Hocken
0.05 (added); Presbyterian 0.014 (removed). Weights currently sum < 1.0 — expected; the final pass
recomputes all from `rawItemCount`.

**Env gotchas:** `swift build`/`run` + DigitalNZ/asset hosts need the command sandbox OFF;
`lsof -ti :7000 | xargs -r kill -9` between `CollectionTester` runs (stale-binary trap); git
commits are 1Password-SSH-signed and intermittently fail with "failed to fill whole buffer" — just
re-run.

## Goal

For the NZ Image API Lambda (wraps DigitalNZ), make each served collection return
the **highest-resolution** browser-displayable image we can extract. Two jobs, one
collection at a time, fully resumable from disk:

1. **Re-check** every collection already in the Lambda (`collectionWeights`) for a
   higher-res extraction than what ships today.
2. **Add** every approved/unsure collection not yet in the Lambda, reverse-
   engineering its source site for the largest image.

## Files

- `progress.json` — **MACHINE-READABLE source of truth.** Determines the next
  collection. One entry per collection (52), in processing order, plus the Wellington
  removal. Schema fields: `order, name, slug, group (A=recheck/B=add), platform,
  rawItemCount, weight, status, baseline, chosen, commit, log, notes`.
- `worklist.md` — human-readable mirror of `progress.json`, grouped by platform
  cluster. Regenerate with `python3 Research/highres/gen_worklist.py` whenever
  `progress.json` changes.
- `gen_worklist.py` — the regenerator for `worklist.md`.
- `recipes.md` — per-platform detection + extraction recipes (a floor, not a
  ceiling) and the **Discovery Playbook**. Grows a "Verified findings" section per
  platform as facts are measured.
- `logs/<NNN>-<slug>.md` — one investigation log per collection (NNN = `order`).

## The secret (NEVER commit it)

The DigitalNZ API key lives only in the gitignored repo-root `.env` as
`DIGITALNZ_API_KEY=…`. Export it before any tooling:
`export DIGITALNZ_API_KEY=$(grep '^DIGITALNZ_API_KEY=' .env | cut -d= -f2)`.
**Never** write the key into any file under `Research/highres/`; redact to
`$DIGITALNZ_API_KEY` in any logged URL.

## How to resume (next-collection algorithm)

1. `export DIGITALNZ_API_KEY=…` (from `.env`).
2. Read `progress.json`.
3. If `removal.status == "pending"` → do the Wellington City Recollect removal first.
4. Else the next collection is the first entry (sorted by `order`) whose `status` ∉
   `{committed, no-improvement, blocked}`.
   - An entry at `awaiting-approval` resumes by **re-surfacing its final URL to the
     user** for testing (loop Step 7) — NOT by re-investigating.
5. When every entry is terminal → run the final weights renormalization + cleanup
   commit (see the plan).

A session updates exactly **one** collection per loop iteration and rewrites
`progress.json` + `worklist.md` **before** moving on, so a crash never loses more
than the in-flight collection.

## The per-collection loop (brief)

0. Select next `C`; `status="investigating"`; persist; open `logs/<NNN>-<slug>.md`.
1. Pull raw records from DigitalNZ (ignore the stale notes in
   `Research/details-of-collections.txt`).
2. Investigate the live site from scratch; detect platform by signal; run the
   **Discovery Playbook** (recipes.md) — mandatory for every collection.
3. Enumerate & measure candidates by **decoded pixel area** (`curl | sips`; proxy
   JP2/TIFF via cloudimg). Always measure the baseline too.
4. Pick the winner (larger area AND browser-displayable AND HTTP 200). Else
   `no-improvement` (Group A) or `blocked`.
5. Implement in Swift (platform function + registry entry; delete legacy `case` in
   the same commit). Group B: add to `collectionWeights` (provisional weight) and to
   `recollectDomainMap` if Recollect.
6. Verify: `swift build` (exit 0) → `swift run CollectionTester "<name>"` (HTTP 200 +
   image type) → `curl|sips` the **processed** URL beats baseline → run tester 2–3×.
7. **USER TEST & APPROVAL GATE (mandatory, every collection).** Surface the final URL
   + measured dims + baseline comparison; set `status="awaiting-approval"`; persist;
   pause. The user opens and tests the URL and must explicitly approve before any
   commit or starting the next collection.
8. After approval: update the log, `progress.json` (`status`→`committed`+SHA),
   `recipes.md` Verified findings; regenerate `worklist.md`; one commit per
   collection (trailer below). For `no-improvement`/`blocked`, still commit the
   `Research/highres/` update.
9. Loop.

## Build / test / measure commands

```
swift build                                  # exit 0
swift run CollectionTester "<EXACT name>"    # full pipeline; HTTP 200 + image type
swift run ImageResolutionChecker "<name>"    # reference cross-check (raw record only)
# decoded-pixel measurement of any candidate:
curl -sL --max-time 120 -A 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36' \
  "<candidate>" -o "$TMPDIR/cand" && sips -g pixelWidth -g pixelHeight "$TMPDIR/cand" && file "$TMPDIR/cand"
```
Network + `swift build`/`swift run` need the command sandbox disabled in this
environment (swift spawns its own sandbox; DigitalNZ/asset hosts aren't allowlisted).

## Commit trailer (every commit)

```
Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
```

## Final passes (after all 52 are terminal)

- **Weights:** `weight_i = rawItemCount_i / Σ rawItemCount` over collections that
  ended up IN the Lambda (committed/kept; exclude blocked/not-added and Wellington);
  round to 3 dp; add the rounding residual to the largest-weight entry so the dict
  sums to exactly 1.000 (the cumulative-sum picker needs ~1.0). Rewrite the
  `collectionWeights` literal in descending-weight order. Commit.
- **Cleanup:** delete the now-empty legacy `switch` (`default: passthrough`); re-verify
  any migrated collections. Commit.
