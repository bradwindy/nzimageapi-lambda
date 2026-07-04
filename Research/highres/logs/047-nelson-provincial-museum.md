# Order 47 — Nelson Provincial Museum

- **Group:** B (ADD — was NOT in `collectionWeights`, so never served)
- **Platform (progress.json):** `boutique` → **RECLASSIFIED to `vernonBrowser`** (Vernon Systems
  "Vernon Browser" — **3rd of the sweep**, after Te Ahu 45 / VUW 46). By far the largest of the three
  (~198,770 image-bearing records vs the ~500-record boutique sites).
- **Host:** `collection.nelsonmuseum.co.nz` (images served from AmazonS3 behind CloudFront) ·
  **landing:** `collection.nelsonmuseum.co.nz/objects/<objId>`
- **content_partner:** Nelson Provincial Museum · **rights:** "All rights reserved" (we serve the same
  public derivative the museum publishes)
- **rawItemCount (progress.json snapshot):** 198196 · **live (primary_collection, category=Images):**
  **198770**
- **Status:** committed (user-approved 2026-07-04)
- **Strategy:** **REUSE `stringSwap`** (same as Te Ahu 45) — pure path-segment swap
  `/records/images/large/` → `/records/images/xlarge/`. **No request-time fetch, no AWS deploy.**

## ★ Platform correction discovered this session: Vernon Browser, not CollectiveAccess

Te Ahu (45) and VUW (46) were both logged as "CollectiveAccess / Pawtucket" earlier in the sweep. That
label is **wrong**. While investigating Nelson, a Wayback Machine snapshot of
`collection.nelsonmuseum.co.nz` (2023-01-28, `http://web.archive.org/web/20230128224911/https://
collection.nelsonmuseum.co.nz/`) showed the front-end loading `vernon-common.min.js` /
`vernon-shortlist.min.js`, and a modal with the title **"Vernon Browser"** — this is **Vernon Systems'**
"Vernon Browser" product (the same NZ company, Vernon Systems Ltd, that makes **eHive**; `dc_identifier`
on Nelson records even carries a leftover `ehiveaccountid:3348` tag, consistent with the same vendor
family). All three sites (Te Ahu, VUW, Nelson) share the identical `/records/images/<version>/<shard>/
<hash40>.jpg` URL scheme and the identical 403-locked-original behaviour — this is Vernon Browser's
media-derivative convention, not CollectiveAccess's. The mislabelling has been corrected retroactively
in `URLProcessor.swift` (comments + the `collectiveAccessLargest` helper renamed to
`vernonBrowserLargest`), `progress.json` (`platform` field for orders 45/46/47), `recipes.md`,
`README.md`, and the sweep memory. None of the actual strategies/behaviour for 45/46 change — only the
label was wrong.

## Identity / dispatch

`display_collection` == `primary_collection` == "Nelson Provincial Museum". `object_url` null;
`landing_url` = `https://collection.nelsonmuseum.co.nz/objects/<objId>`.

## Platform detection

Harvested `large_thumbnail_url` = `…/records/images/large/<shard>/<hash40>.jpg` (`<shard>` = up to
6-digit dir; `<hash40>` = 40-hex SHA1); `thumbnail_url` is the `small` version — identical scheme to Te
Ahu/VUW. The landing page is **bot-walled** (AWS WAF, `x-amzn-waf-action: challenge`, HTTP 202) but
irrelevant — the `/records/images/` CDN is not walled and the strategy needs no page fetch. `robots.txt`
and `sitemap.xml` at the domain root are also WAF-blocked (`403`, generic CloudFront block page), and
even **Vernon's own public demo site** (`browser.vernonsystems.com`) hits the identical CloudFront bot
challenge — confirming this is a platform-wide default, not something Nelson specifically configured.

## ★★ Exhaustive ceiling check — `xlarge` is genuinely the largest public derivative

The user pushed back on an initial "xlarge is the ceiling" claim and asked for real verification. Steps
taken (all against a live record, `178109/1a34360d5030db2842e38d7f825e8324c19f149c`, "Ornament, Wolf in
Trap"):

1. **13 alternate derivative-name guesses** directly on the CDN: `original`, `fullsize`, `full`,
   `tilepic`, `xxlarge`, `master`, `preview`, `raw`, `print_preview`, `crop`, `display`, `thumbnail`,
   plus case variants (`Display`, `XLarge`, `Large`) — **all 403**. Only `nano` (35×25), `tiny`
   (75×53), `small`, `medium`, `large`, `xlarge` return 200. This matches Vernon's own documented set of
   8 default Image Derivatives (Nano/Tiny/Small/Medium/Large/XLarge/Display/Thumbnail) — Nelson simply
   never generated/published `Display` or `Thumbnail` as separate derivatives.
2. **Query-param resize tricks** (`?w=4000`, `?width=4000`, `?size=full`, `?full=1`, `?d=4000`,
   `?resize=4000`) on the `xlarge` URL — all return 200 but are **byte-identical** to the plain URL
   (`cmp` confirmed) — CloudFront ignores the query string entirely; no dynamic-resize route exists.
3. **The real Vernon Browser vendor API** — found the Swagger spec at
   `https://apidocs.browser.vernonsystems.com/assets/e9d642cfa50af08c7c2390c995d56e58-swaggerV3_2.json`
   (host `browser.vernonsystems.com`, `basePath: /api/v3`). It documents an `ImageDerivative` schema
   (`identifier`, `url`, `width`, `height`) via `/opacobjects/{opacObjectId}` etc. Confirmed the API is
   live and path-mounted on Nelson's own host: `https://collection.nelsonmuseum.co.nz/api/v3/
   opacobjects/68` → **HTTP 401** ("Aborting request as authorization headers are missing"), i.e. it
   bypasses the WAF challenge (proper JSON error, not a 202 challenge) but requires an API key we don't
   have. Auckland Museum's public instance (`collection-api.aucklandmuseum.com`) returns the identical
   401 shape, confirming this is a real, generally-authenticated API pattern across Vernon Browser
   installs, not something Nelson-specific.
4. **Vendor documentation research** — Vernon Systems documents IIIF support **only for eHive**, not for
   Vernon Browser/Vernon CMS. Vernon Browser help docs describe 8 default Image Derivatives (Nano, Tiny,
   Small, Medium, Large, XLarge, Display, Thumbnail); nothing about a hidden zoom/tile service.
5. **Wayback Machine — recent archived object detail page** (`/objects/1000/carmane`, snapshot
   2024-02-06) — fetched and inspected the actual HTML: plain `<img>` tags against exactly
   `small`/`medium`/`large`/`xlarge` (same 4 tiers we use), **zero** references to OpenSeadragon, IIIF,
   DZI, deepzoom, zoomify, or leaflet anywhere in the page. A `download.min.js` reference is the generic
   third-party `download.js` client-side blob-save library (triggers a save of whatever's already
   displayed), not a hi-res unlock.
6. **EXIF on the served `xlarge` JPEG** — `make: OLYMPUS CORPORATION`, `model: TG-6` (a compact camera
   with a native ~12 MP / 4000×3000 sensor) — confirms the true source photo is far higher-resolution
   than the published 1200×851 `xlarge`, but it is **deliberately not published**: the `original`/
   `fullsize`/etc. tiers return S3 `<Error><Code>AccessDenied</Code></Error>` (a real S3 ACL denial, not
   a CloudFront/WAF artifact), consistent with Vernon Browser's login-gated originals policy (same as Te
   Ahu/VUW).
7. **DNS/subdomain sweep** — `www.nelsonmuseum.co.nz` (200, marketing site) and
   `collection.nelsonmuseum.co.nz` (the Vernon Browser install) are the only two live hosts;
   `media./images./api./cdn./search./admin.nelsonmuseum.co.nz` all fail to connect (no such host).

**Conclusion: `xlarge` (1200 px long side, master-capped) is genuinely the public ceiling** — this is a
deliberate platform/vendor policy (originals require Vernon CMS credentials we cannot obtain), not a gap
in this investigation.

## Measurements (Discovery Playbook)

- **150-page uniform HEAD census** (pages sampled uniformly across all ~9,939 pages of the ~198,770-
  record collection, one record per sampled page): **null-image = 0 (0.0%)**; **large_403 (fully stale —
  ALL size tiers 403 on retry) = 7 (4.7%)**; **both_ok (large 200 AND xlarge 200) = 143**;
  **xlarge_missing_only (large 200 but xlarge not 200) = 0**. The 7 fully-stale records were individually
  re-checked (all size tiers, repeated after a delay) and are genuinely dead at the source — not a
  network blip — but this pre-exists our change (the harvested `large` URL already 403s for them; the
  swap makes no difference either way).
- **40-record pixel-dimension survey** (separate uniform sample): `xlarge` vs `large` = **24 win / 13
  equal / 0 smaller** (3 further records were the fully-stale case, both tiers 403, excluded from the
  ratio stats); area ratio **min 1.000 / median 1.288 / max 2.251**. Lower median than Te Ahu/VUW's 2.25×
  because many Nelson masters are natively smaller than 800 px (portrait glass-plate negatives commonly
  measured ~591–650 px on the long side, so `large`'s 800-px box already captures the full master and
  `xlarge`'s 1200-px box can't add anything — hence the higher equal-rate here, 13/37 ≈ 35%, vs
  Te Ahu's 0/64).

## Decision

**Group B ADD via REUSE of `stringSwap(from: "/records/images/large/", to: "/records/images/xlarge/")`**
— same helper as Te Ahu 45, no new code. Justified because the 150-page census found **0/143** "large
succeeds but xlarge missing" cases (unlike VUW's 1.2%), so the plain unconditional swap is safe — no
HEAD-probe (`vernonBrowserLargest`) needed here. Weight 0.002 (consistent with Te Ahu 45 / VUW 46).

## Implementation

- `URLProcessor.swift` — new registry entry `strategies["Nelson Provincial Museum"] = stringSwap(from:
  "/records/images/large/", to: "/records/images/xlarge/")` + a comment documenting the platform
  correction, the census findings, and the exhaustive ceiling check. **No new function.** Also: renamed
  `collectiveAccessLargest` → `vernonBrowserLargest` and corrected the Te Ahu 45 / VUW 46 comments
  (platform-label correction, not a behaviour change).
- `NZImageApi.swift` — `collectionWeights["Nelson Provincial Museum"] = 0.002`.
- `progress.json` — order 47: platform `boutique` → `vernonBrowser`; status → `committed`; baseline /
  chosen / notes / weight filled in. Orders 45/46: `platform` field corrected `collectiveAccess` →
  `vernonBrowser`, `notes` text corrected (no other fields changed).

## Verification

- `swift build` exit 0 (both the rename and the new registry entry).
- CollectionTester ×6 → **6/6 HTTP 200**, all served `xlarge` URLs (dispatch confirmed):
  - "Thomas, Miss" — 594×800 → 680×916 (1.30× area)
  - "Fair, wedding" — 597×800 → 680×911 (1.29× area)
  - "Ornament, Wolf in Trap" — 800×567 → 1200×851 (2.25× area)
  - "Bunny, Miss" — 646×800 → 680×842 (1.11× area)
  - "Rai Valley A&P Show, 1934" — 640×500 → 640×500 (1.00×, already native — no loss)
  - "Gill" — 593×800 → 680×917 (1.31× area)
- Regression: additive only (new registry entry + weight; `stringSwap` unchanged, `vernonBrowserLargest`
  rename is a pure rename with no behaviour change — VUW re-verified via `swift build` passing). A URL
  lacking the `/records/images/large/` substring passes through unchanged.

## Example live URLs (for the approval gate)

- **Win (2.25×)** — "Ornament, Wolf in Trap":
  `https://collection.nelsonmuseum.co.nz/records/images/large/178109/1a34360d5030db2842e38d7f825e8324c19f149c.jpg`
  (800×567) →
  `https://collection.nelsonmuseum.co.nz/records/images/xlarge/178109/1a34360d5030db2842e38d7f825e8324c19f149c.jpg`
  (1200×851). Landing page: `https://collection.nelsonmuseum.co.nz/objects/G2276` (bot-walled — open in
  an actual browser).
- **Equal (no loss)** — "Rai Valley A&P Show, 1934":
  `https://collection.nelsonmuseum.co.nz/records/images/xlarge/99350/0c8f78a1701d29c7e7e0f7cea76a6ff2dd446116.jpg`
  (640×500, unchanged from `large`). Landing page: `https://collection.nelsonmuseum.co.nz/objects/101225`.

## Commit

- Change commit: "Nelson Provincial Museum (47): committed Group B ADD -- 3rd Vernon Browser site;
  REUSED stringSwap, no new code, no deploy; PLUS retroactive Vernon Browser platform-label correction
  for Te Ahu 45 / VUW 46 (was CollectiveAccess/Pawtucket)". The SHA is recorded by the follow-up "Record
  SHA … for collection 47" commit.
