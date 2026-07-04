# Order 45 — Te Ahu Museum

> **★ PLATFORM CORRECTION (added during order 47 investigation, 2026-07-04):** this site was
> misidentified below as "CollectiveAccess / Pawtucket". It is actually **Vernon Systems'
> "Vernon Browser"** (same vendor as eHive) — confirmed via a Wayback Machine snapshot of
> `collection.nelsonmuseum.co.nz` (order 47, same platform) showing `vernon-common.min.js` and a
> "Vernon Browser" modal title in the archived front-end HTML. The URL scheme, size ladder, and
> all measurements/strategy below are unaffected — only the platform label was wrong. `progress.json`
> and `URLProcessor.swift` have been updated to `vernonBrowser`/"Vernon Browser"; this log's body is
> left as originally written except where noted.

- **Group:** B (ADD — was NOT in `collectionWeights`, so never served)
- **Platform (progress.json):** `boutique` → **RECLASSIFIED to `vernonBrowser`** (Vernon Systems "Vernon Browser" — the museum's own collection CMS at `collection.teahumuseum.nz`, S3/CloudFront-backed). **New platform for the sweep.** (Originally logged as "CollectiveAccess / Pawtucket" — see correction note above.)
- **Host:** `collection.teahumuseum.nz` (images served from AmazonS3 via CloudFront) · **landing:** `collection.teahumuseum.nz/objects/<objId>`
- **content_partner:** Te Ahu Museum · **rights:** site copyright notice (personal-use reproduction permitted; we serve the same public derivative the museum publishes)
- **rawItemCount (progress.json snapshot):** 504 · **live (primary_collection, category=Images):** **506**
- **Status:** committed (user-approved 2026-06-17)
- **Strategy:** **REUSE `stringSwap`** (first registry use) — pure path-segment swap
  `/records/images/large/` → `/records/images/xlarge/`. **No request-time fetch, no AWS deploy.**

## Identity / dispatch

"Te Ahu Museum" is the DigitalNZ `primary_collection` **and** `display_collection` (same value);
`content_partner` also "Te Ahu Museum". `object_url` null; `landing_url` =
`https://collection.teahumuseum.nz/objects/<objId>`. The Lambda queries
`and[primary_collection][]` + `and[category][]=Images` and dispatches on `result.collection`
(= `display_collection`), so the single registry key works.

## Platform detection — Vernon Systems "Vernon Browser", not eHive/Recollect

Harvested `large_thumbnail_url` = `https://collection.teahumuseum.nz/records/images/large/<NN>/<hash>.jpg`
(`<NN>` = 1–3 digit shard dir, `<hash>` = 40-hex SHA1); `thumbnail_url` is the `small` version. The
`records/images/<version>/<shard>/<hash>.jpg` layout with named media versions
(`small`/`medium`/`large`/`xlarge`) is the Vernon Systems "Vernon Browser" media-version scheme. Images
are served from **AmazonS3** (`server: AmazonS3` on the image response) behind CloudFront. The
landing page itself is **bot-walled** (CloudFront returns **HTTP 202** with a ~2 KB challenge page,
no useful HTML) — but irrelevant: the `/records/images/` CDN is not walled and the strategy needs no
page fetch.

## ★ Size ladder — `xlarge` (1200 px) is the largest PUBLIC variant

Variant probe on one record (`…/large/51/8ac6…e622.jpg`):
- `small` 123×150 · `medium` 328×400 · `large` **657×800** (harvested baseline) · `xlarge` **985×1200**.
- `original`, `fullsize`, `full`, `huge`, `page`, `screen`, `tilepic`, `xxlarge`, `large2x`,
  `master`, `archive`, `print`, `zoom`, `2048`, `1600`, `4096`, … all → **403** (Vernon Browser
  gates the original behind login; only the four public derivative versions exist). So **xlarge =
  1200 px long side ≈ 1.44 MP is the public ceiling.**

`xlarge` targets 1200 px long side vs `large`'s 800 px; both are capped at the master (Vernon Browser
does not upscale by default), so **`xlarge` ≥ `large` always, and never exceeds the master** → **no
fake-upscale / honest-smaller fork** (unlike eHive's `_l`).

## Measurements (Discovery Playbook)

- **Null-image census (all 506 records, 6 pages):** **0 null-image (0.0%)** — every record carries an
  image (the exact opposite of Waikato 44's 61.5%). So no `checkHasTitleAndLargeImage` hard-fail issue.
- **Uniform survey (64 image-bearing records sampled across the collection):** `xlarge` vs `large` =
  **63 win / 0 equal / 0 smaller / 0 xlarge-missing**; area ratio **min 1.562 / median 2.250 / max
  2.254**; biggest `xlarge` 1200×1199 ≈ 1.44 MP. (The 1.56× tail = records whose master is ~1000 px, so
  `xlarge` caps below 1200 while `large` is the full 800.) **1/64 records had a `large` that itself
  403'd** (~1.6% — a pre-broken baseline at source; `xlarge` would 403 too, so the swap does not make it
  worse; additive Group B ⇒ not a regression.)

## Decision

**Group B ADD via REUSE of `stringSwap(from: "/records/images/large/", to: "/records/images/xlarge/")`** —
pure path-segment swap, no request-time fetch, no deploy. Strict 1.56–2.25× improvement (median 2.25×),
100% available, 0 null-image, no honest-smaller fork. Modest absolute resolution (1.2 MP ceiling, as the
originals are 403-locked), but clean and strictly better than the harvested 800 px `large`.

## Implementation

- `URLProcessor.swift` — new registry entry `strategies["Te Ahu Museum"] = stringSwap(from:
  "/records/images/large/", to: "/records/images/xlarge/")` (first use of the `stringSwap` helper in the
  registry) + a comment documenting the platform, the variant ladder, the 403-locked originals, and the
  100%-available / no-upscale findings. **No new function.**
- `NZImageApi.swift` — `collectionWeights["Te Ahu Museum"] = 0.002`.
- `progress.json` — platform `boutique` → `vernonBrowser`; rawItemCount 504 → 506; status; baseline /
  chosen / notes / weight.

## Verification

- `swift build` exit 0.
- CollectionTester ×6 → **6/6 HTTP 200**, all served `xlarge` URLs (dispatch confirmed; the harvested
  `large` was rewritten to `xlarge`), each exactly 1.5×/side = 2.25× area over `large`:
  - Ahipara 800×604 → 1200×905
  - Greenstone Pendant 800×330 → 1200×494
  - Awanui 800×604 → 1200×906
  - Cigarette Holder 566×800 → 850×1200
  - Far North 800×571 → 1200×856
  - Peria 800×595 → 1200×892
- Regression: additive only (new registry entry + weight; `stringSwap` unchanged) — no existing path
  touched. A URL lacking the `/records/images/large/` substring passes through unchanged.

## Example live URLs (for the approval gate)

- *Ahipara*: `…/records/images/large/739/ae63b58…7f0b.jpg` (800×604) →
  `…/records/images/xlarge/739/ae63b58…7f0b.jpg` (1200×905).
- *Telephone* (first record): `…/records/images/large/51/8ac6fe60…e622.jpg` (657×800) →
  `…/records/images/xlarge/51/8ac6fe60…e622.jpg` (985×1200).

## Commit

- Change commit: "Te Ahu Museum (45): committed Group B ADD …" (registry entry → `stringSwap` + weight +
  `Research/highres/` bookkeeping). The SHA is recorded by the follow-up "Record SHA … for collection 45"
  commit.
