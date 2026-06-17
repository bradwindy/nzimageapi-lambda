# Order 46 — Ngā Puhipuhi o Te Herenga Waka—Victoria University of Wellington Art Collection

- **Group:** B (ADD — was NOT in `collectionWeights`, so never served)
- **Platform (progress.json):** `boutique` → **RECLASSIFIED to `collectiveAccess`** (CollectiveAccess / Pawtucket — **2nd of the sweep**, after Te Ahu 45). Te Pātaka Toi **Adam Art Gallery** (VUW university art collection).
- **Host:** `universityartcollection.adamartgallery.nz` (images served from AmazonS3 behind CloudFront) · **landing:** `…/objects/<objId>`
- **content_partner:** Te Pātaka Toi Adam Art Gallery · **rights:** "All rights reserved" (we serve the same public derivative the gallery publishes)
- **rawItemCount (progress.json snapshot):** 488 · **live (primary_collection, category=Images):** **488**
- **Status:** committed (user-approved 2026-06-18)
- **Strategy:** **NEW reusable `collectiveAccessLargest`** (async, HEAD-probe + fallback) — swap
  `/records/images/large/` → `/records/images/xlarge/`, **HEAD-probe the `xlarge` and fall back to the
  harvested `large` when it is absent**. **No AWS deploy.**

## Identity / dispatch

`display_collection` == `primary_collection` == "Ngā Puhipuhi o Te Herenga Waka—Victoria University of
Wellington Art Collection" (note the macron `ā` and the em-dash `—`; the Swift registry key matches
byte-for-byte). `content_partner` "Te Pataka Toi Adam Art Gallery". `object_url` null; `landing_url` =
`https://universityartcollection.adamartgallery.nz/objects/<objId>`.

## Platform detection — 2nd CollectiveAccess / Pawtucket site (cf. Te Ahu 45)

Harvested `large_thumbnail_url` = `…/records/images/large/<shard>/<hash40>.jpg` (`<shard>` = 1–3 digit
dir; `<hash40>` = 40-hex SHA1); `thumbnail_url` is the `small` version. Identical to Te Ahu's
CollectiveAccess media-version scheme; images served from **AmazonS3** behind CloudFront. The landing
page is **bot-walled** (CloudFront HTTP 202 + JS challenge) but irrelevant — the `/records/images/` CDN
is not walled, and the strategy needs no page fetch.

## Size ladder — `xlarge` (1200 px) is the largest PUBLIC variant (same as Te Ahu)

One record (`…/large/114/ade94a…3692f.jpg`):
- `small` 150×117 · `medium` 400×313 · `large` **800×626** (harvested) · `xlarge` **1200×939**.
- `original`, `fullsize`, `full`, `huge`, `page`, `screen`, `tilepic`, `xxlarge`, `large2x`, `master`,
  `archive`, `print`, `2048`, `1600`, … all → **403** (originals login-gated). **`xlarge` ≈ 1.4 MP is the
  public ceiling.** Both `large` (800 target) and `xlarge` (1200 target) are **master-capped** (no
  upscaling), so `xlarge` ≥ `large` always and never exceeds the master → **no honest-smaller fork**.

## ★ Why a HEAD probe here (not Te Ahu's pure `stringSwap`): ~1.2% missing `xlarge`

Unlike Te Ahu (0/64 xlarge-missing → safe blind swap), a **full HEAD scan of all 486 image-bearing
records found 6 (1.2%) with a `large` (200) but NO generated `xlarge` (403)**. A blind swap would serve
a broken 403 for those. So `collectiveAccessLargest` **HEAD-probes the `xlarge`** and falls back to the
harvested `large` (always 200 for those 6) when it is absent. The HEAD probe is reliable: **HEAD == GET
for every one of the 486 records** (0 mismatches; the 6 missing show `large` HEAD=200/GET=200, `xlarge`
HEAD=403/GET=403). (An early manual check confused me with false 403s — that was a truncated-shard bug
in a debug print, `xl[-46:]` showing only the last digit of a multi-digit shard; the full URLs are
unambiguous and HEAD==GET.)

## Measurements (Discovery Playbook)

- **Null-image census (all 488 records):** **2 null-image (0.4%)** — those hard-fail the pick (HTTP 400
  via `checkHasTitleAndLargeImage`, no retry loop; pre-existing Lambda behaviour, identical for the
  baseline). Negligible vs Waikato 44's 61.5%.
- **Full xlarge scan (486 image-bearing records, HEAD):** xlarge-missing = **6 (1.2%)**; HEAD==GET
  mismatches = **0**.
- **Uniform survey (61 records):** `xlarge` vs `large` = **46 win / 13 equal / 0 smaller / 2
  xlarge-missing**; area ratio **min 1.000 (equal: master ≤ 800 px) / median 2.249 / max 2.253**;
  biggest `xlarge` 1200×1187 ≈ 1.42 MP.

## Decision

**Group B ADD via NEW `collectiveAccessLargest`** (HEAD-probe `xlarge`, fall back to `large`). Strict
1.0–2.25× improvement (median 2.25×), graceful for the ~1.2% missing-xlarge, no honest-smaller fork,
no request-time fetch beyond a cheap HEAD. Weight 0.002 (consistent with Te Ahu 45). Te Ahu's pure
`stringSwap` is left unchanged (0% missing there; this probing variant is for sites where `xlarge` is
not 100% present).

## Implementation

- `URLProcessor.swift` — NEW `collectiveAccessLargest(_:_:) async` (HEAD-probe via
  `NetworkRequestManager().headStatusFollowingRedirects(endpoint:)`, fall back to the harvested URL) +
  registry entry `strategies["Ngā Puhipuhi o Te Herenga Waka—Victoria University of Wellington Art
  Collection"]` → `await collectiveAccessLargest(result, url)`.
- `NZImageApi.swift` — `collectionWeights[…] = 0.002`.
- `progress.json` — platform `boutique` → `collectiveAccess`; status; baseline / chosen / notes / weight.

## Verification

- `swift build` exit 0.
- CollectionTester ×6 → **6/6 HTTP 200**, all served `xlarge` (HEAD-probe path; dispatch confirmed):
  - The Single Cloud 404×800 → 606×1200
  - Continuum VII 800×329 → 1200×493
  - Light Installation 800×553 → 1200×830
  - Untitled 800×519 → 1200×778
  - Untitled (Puvis) 617×800 → 728×944 (master < 1200 px → partial gain ×1.39)
  - Exotic Plant 541×800 → 812×1200
- **Fallback path verified:** record 50811364 — `xlarge` HTTP 403 → strategy returns `large` (HTTP 200,
  800×648). Never a broken 403.
- Regression: additive only (new helper + registry entry + weight); no existing path touched. Te Ahu 45
  (pure `stringSwap`) untouched.

## Example live URLs (for the approval gate)

- **Win (2.25×)** — *Quarry Entrance*: `…/records/images/large/114/ade94a…3692f.jpg` (800×626) →
  `…/records/images/xlarge/114/ade94a…3692f.jpg` (1200×939).
- **Fallback** — record 50811364: `…/xlarge/337/5030a87…ba4e0.jpg` → **403** → served
  `…/large/337/5030a87…ba4e0.jpg` (800×648, 200).

## Commit

- Change commit: "Ngā Puhipuhi … (46): committed Group B ADD …" (new `collectiveAccessLargest` + registry
  + weight + `Research/highres/` bookkeeping). The SHA is recorded by the follow-up "Record SHA … for
  collection 46" commit.
