# Order 48 — Puke Ariki

- **Group:** B (ADD — was NOT in `collectionWeights`, so never served)
- **Platform (progress.json):** `boutique` → **RECLASSIFIED to `vernonBrowser`** (Vernon Systems
  "Vernon Browser" — the museum's own collection site at `collection.pukeariki.com`,
  S3/CloudFront-backed). **4th confirmed site on this platform** (after Te Ahu 45 / VUW 46 /
  Nelson 47 — see [[project-highres-sweep]]).
- **Host:** `collection.pukeariki.com` (images served from AmazonS3 via CloudFront) · **landing:**
  `collection.pukeariki.com/objects/<objId>`
- **content_partner:** Puke Ariki · **rights:** mixed, mostly "All rights reserved" (a Puketapu/New
  Plymouth District Council museum & library; we serve the same public derivative the museum
  itself publishes — see the Vernon Browser findings from orders 45–47 re: derivative tiers not
  being rights-gated)
- **rawItemCount (progress.json snapshot):** 134,849 · **live (primary_collection, category=Images):**
  **134,911** — by far the largest single-museum site in the sweep so far (bigger than Nelson's
  ~198,770 *raw* records once you account for Nelson's higher null-image fraction — actually
  smaller in raw count than Nelson but the largest **image-bearing** boutique-museum collection to
  date). Dominated by the **Swainson/Woods Collection** (black-and-white photographic negatives,
  studio: Swainson's Studios / Bernard Woods Studio), plus smaller donor collections (Diana Smith
  Collection — toys; Caleb Wyatt — 35mm negatives; Ken Fox Collection; etc.).
- **Status:** committed (pending user approval this session)
- **Strategy:** **REUSE `stringSwap`** (3rd reuse of this helper on this platform, after Te Ahu 45 /
  Nelson 47) — pure path-segment swap `/records/images/large/` → `/records/images/xlarge/`.
  **No request-time fetch, no AWS deploy.**

## Identity / dispatch

"Puke Ariki" is the DigitalNZ `primary_collection` **and** `display_collection` (same value);
`content_partner` also "Puke Ariki". `object_url` null; `landing_url` =
`https://collection.pukeariki.com/objects/<objId>`. The Lambda queries `and[primary_collection][]`
+ `and[category][]=Images` and dispatches on `result.collection` (= `display_collection`), so the
single registry key works.

## Platform detection — 4th confirmed Vernon Systems "Vernon Browser" site

Harvested `large_thumbnail_url` = `https://collection.pukeariki.com/records/images/large/<NN>/<hash40>.jpg`
— **byte-for-byte the same URL scheme** as Te Ahu (45) / VUW (46) / Nelson (47): `<NN>` a numeric
shard directory, `<hash40>` a 40-hex SHA1. Confirmed the platform independently rather than just
assuming it from the URL shape alone:

1. **Landing page bot-wall signature matches exactly.** A plain `curl` (no UA) to
   `collection.pukeariki.com/objects/113040` returns **HTTP 403** with a small CloudFront
   "Request blocked" error page. Retrying with a real browser User-Agent string returns
   **HTTP 202 with a 0-byte body** — the same "202 challenge, no useful HTML" signature
   documented for Te Ahu/VUW's landing pages. This CloudFront-level bot-wall behaviour is specific
   enough (not just a generic WAF 403) that seeing it reproduce exactly is good independent
   evidence of the same underlying deployment.
2. **Image CDN response headers match.** `server: AmazonS3`, served via CloudFront
   (`x-cache: Miss from cloudfront`), `cache-control: public, max-age=31536000` — identical
   infrastructure signature to Te Ahu/VUW/Nelson.
3. **Derivative-name set re-verified directly on this site** (not assumed from Nelson): probed
   `nano/tiny/small/medium/large/xlarge/display/thumbnail` on one record — `nano/tiny/small/medium/
   large/xlarge` all **200**, `display/thumbnail` both **403** — the exact same published subset
   of Vernon's 8 default Image Derivatives as Nelson (47).
4. **No Wayback Machine snapshot exists** for `collection.pukeariki.com` at all (checked via the
   CDX API — zero captures for the subdomain, likely `robots.txt`-disallowed or simply never
   crawled), so the JS-source `vernon-*.min.js` confirmation method used at Nelson wasn't
   available here. Not needed: the CloudFront bot-wall signature + identical URL scheme + identical
   derivative-availability fingerprint (points 1–3) are independently strong confirmation. The
   underlying "xlarge is Vernon Browser's public ceiling" finding is a **platform-level** fact
   established at Nelson (47) via 7 lines of evidence there (vendor API, EXIF, Wayback JS
   inspection, exhaustive derivative-name guessing, etc.) — it does not need to be independently
   re-proven per-site once the platform match is confirmed.

## Measurements (Discovery Playbook)

### Full-range census (150 samples spanning the ENTIRE ~134,911-record range)

**API gotcha discovered this session:** DigitalNZ's `records.json` endpoint hard-caps the `page`
parameter at **50,000** regardless of `per_page` (confirmed empirically: `page=50000` succeeds,
`page=69000` returns `{"errors":["The page parameter can not exceed 50000"]}`). With the naive
`per_page=1` approach, this means only the **front ~37%** of a 134,911-record collection is
reachable by page number — a census built that way (as first attempted) silently truncates to the
front of the collection and is NOT a valid uniform sample. **Worked around** by using
`per_page=50` and reading only the first record of each page: with `per_page=50`, `page` only
needs to reach `⌈134911/50⌉ = 2698` to cover the whole range, well under the 50,000 cap — verified
this reaches records near the very end of the collection (tested `page=2698` → returns id
`51810178`, the true tail of the result set).

Sampling one record per page, spread uniformly across pages `1..2698` (150 samples, step ≈18):

- **0/150 (0.0%) null-image** — no records lacking `large_thumbnail_url`.
- **0/150 non-standard URL shape** — all matched `/records/images/large/`.
- **0/150 stale/broken `large`** — every harvested `large` URL returned HTTP 200 (unlike Nelson's
  4.7% pre-existing dead rate — Puke Ariki's asset set is in noticeably better health).
- **0/150 "large 200 but xlarge missing"** — i.e., **0% cases where the swap would introduce a
  broken image.** Cleaner than any other Vernon Browser site checked so far (Nelson had the same
  0% missing-xlarge rate but 4.7% pre-existing dead assets; Puke Ariki has neither issue).

This justifies the plain unconditional `stringSwap` (no HEAD-probe/fallback needed, unlike VUW's
`vernonBrowserLargest` which exists specifically because VUW had a nonzero missing-xlarge rate).

### Pixel-dimension survey (40-record uniform subsample of the census set)

- **0/40 (0%) smaller** — `xlarge` is never smaller than `large` (never a regression).
- **35/40 (87.5%) byte-identical** (`ratio = 1.000`, confirmed by dimension AND file match) — the
  master is already ≤800 px long side, so `large` already captures it in full and `xlarge`
  (master-capped, no upscaling) returns the identical file. This is a materially higher
  equal-rate than Te Ahu/VUW/Nelson (which had 0–~50% equal), reflecting that Puke Ariki's
  dominant Swainson/Woods photographic-negative scans were mostly digitised at modest resolution.
- **5/40 (12.5%) real wins**, ratio range **2.248×–14.073×**:
  - id 31885833: `large` 307×800 (0.25 MP) → `xlarge` 460×1200 (0.55 MP), ratio 2.248×
  - id 31873742: `large` 800×589 (0.47 MP) → `xlarge` 1200×884 (1.06 MP), ratio 2.251×
  - id 49174386: `large` 800×563 (0.45 MP) → `xlarge` 1200×845 (1.01 MP), ratio 2.251×
  - id 33691074: `large` 791×800 (0.63 MP) → `xlarge` 1187×1200 (1.42 MP), ratio 2.251×
  - id 31876970: `large` 800×514 (0.41 MP) → `xlarge` **3000×1929 (5.79 MP)**, ratio **14.073×**
    (the standout — a master well above the 1200 px `xlarge` cap for other records, meaning this
    particular record's true master is much bigger than the platform's usual ~1000–1200 px
    ceiling, and `xlarge` still exposes all of it).
- **Sample diversity check:** spot-checked `collection_title` across 10 ids spread through the
  census (via the `records/<id>.json` endpoint, since DigitalNZ's records search does not support
  filtering by internal `id`) — confirmed the sample spans multiple sub-collections (Diana Smith
  Collection, Swainson/Woods Collection, Caleb Wyatt, Ken Fox Collection), not just one dominant
  donor collection, so the census/survey results are representative of the whole site rather than
  an artifact of one sub-collection's scanning practice.

## Decision

**Group B ADD via REUSE of `stringSwap(from: "/records/images/large/", to: "/records/images/xlarge/")`**
— identical strategy to Te Ahu (45) and Nelson (47). Strictly safe (0/150 missing-xlarge, 0/40
smaller) and a genuine improvement for the ~12.5% of records with masters above the harvested
800 px `large` tier (up to 14×), with the rest served byte-identically (no harm, no benefit). No
new code, no request-time fetch, no deploy.

## Implementation

- `URLProcessor.swift` — new registry entry `strategies["Puke Ariki"] = stringSwap(from:
  "/records/images/large/", to: "/records/images/xlarge/")` (3rd reuse of the helper) + a comment
  documenting the platform-match evidence, the page-cap census workaround, and the measured
  win/equal/smaller breakdown. **No new function.**
- `NZImageApi.swift` — `collectionWeights["Puke Ariki"] = 0.002` (consistent with the other
  Group-B Vernon Browser adds).
- `progress.json` — platform `boutique` → `vernonBrowser`; rawItemCount 134,849 → 134,911; status;
  baseline / chosen / notes / weight.

## Verification

- `swift build` exit 0.
- CollectionTester ×6 → **6/6 HTTP 200**, all served `xlarge` URLs (dispatch confirmed):
  - Woodleigh School, Children — `xlarge` 200 image/jpeg
  - Peeler, Apple — `xlarge` 200 image/jpeg
  - Bray, Baby — `xlarge` 200 image/jpeg
  - Ernest Corbett — `xlarge` 200 image/jpeg
  - Crow, Women — `xlarge` 200 image/jpeg
  - Wolfsbauer, Children — `xlarge` 200 image/jpeg
  - (3 of the 6 spot-checked at pixel level happened to land on `large`==`xlarge` records — expected
    given the 87.5% equal rate measured in the survey; still HTTP 200, still correct dispatch, no
    regression.)
- **Debugging note (this session):** the first two CollectionTester runs failed with HTTP 400
  ("Failed to get image for collection: Puke Ariki"). Server-side log
  (`/tmp/lambda-server.log`) showed `NetworkRequestManagerError error 1` (`nonJsonResponse`) on the
  second (100-record) DigitalNZ request. Root cause: `DIGITALNZ_API_KEY` had not been re-exported
  in the same shell invocation as the `swift run CollectionTester` call (per-Bash-call shell state
  does not persist between tool calls in this environment) — so the Lambda made an **unauthenticated**
  request to `api.digitalnz.org`, which DigitalNZ apparently serves inconsistently (non-JSON
  response) for larger `per_page` values without a valid `Authentication-Token`. Re-exporting the
  key in the same command as the `swift run` call fixed it immediately and consistently (6/6
  clean runs afterward). Not a platform or code bug — a session/environment mistake.
- Regression: additive only (new registry entry + weight; `stringSwap` unchanged) — no existing
  path touched. A URL lacking the `/records/images/large/` substring passes through unchanged.

## Example live URLs (for the approval gate)

- *Kaupokonui beach site, pendant pieces, Kaupokonui* (landing:
  `https://collection.pukeariki.com/objects/134753`):
  `…/records/images/large/88214/214b02e0…eaea6.jpg` (800×514, 0.41 MP) →
  `…/records/images/xlarge/88214/214b02e0…eaea6.jpg` (**3000×1929, 5.79 MP** — the 14× standout).
- *Ockhuysen, Boy* (landing: `https://collection.pukeariki.com/objects/163642`):
  `…/records/images/large/63413/267e50ea…9c.jpg` (791×800, 0.63 MP) →
  `…/records/images/xlarge/63413/267e50ea…9c.jpg` (1187×1200, 1.42 MP, 2.25×).
- *Woodleigh School, Children* (a live CollectionTester pick):
  `…/records/images/xlarge/70693/f20a984a…8a.jpg` (served directly by the deployed strategy).

## Commit

- Change commit: "Puke Ariki (48): committed Group B ADD …" (registry entry → `stringSwap` (reuse)
  + weight + `Research/highres/` bookkeeping). The SHA is recorded by the follow-up "Record SHA …
  for collection 48" commit.
