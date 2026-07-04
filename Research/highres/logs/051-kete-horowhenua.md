# 051 — Kete Horowhenua

- **Group:** B (add, not currently in the Lambda)
- **Platform:** **Recollect signed-IIIF** (new-generation, `curtis-production2-cache`) — the SAME
  platform as **Feilding Library (35)**; front-end `horowhenua.kete.net.nz` (a "Kete" branded
  install, but the media pipeline is Recollect's, not the classic open-source Kete platform)
- **DigitalNZ result_count:** 24,375 image-bearing (live, 2026-07-04; `rawItemCount` snapshot
  24,104)
- **Timestamp:** 2026-07-04
- **Outcome:** **committed Group B ADD.** New Swift strategy `keteHorowhenuaOriginal` resolves the
  item page's `download?variant=original` link and returns it directly (no converter/redeploy
  needed — originals here are always plain JPEG, unlike Feilding's TIFF masters). Verified with a
  1-byte ranged GET (HEAD 403s on the S3 leg). Census 24/24 JPEG; pixel survey 15/16 with 0
  honest-smaller, median 2.44×, max 67.76×. `swift build` 0; CollectionTester ×6 dispatch confirmed
  (its own HEAD-based validator reports a false-negative 403 on these URLs — manually verified 6/6
  HTTP 200 via GET). weight 0.002. **User-approved 2026-07-04.**

## Raw record sample (key redacted)

| field | value |
|-------|-------|
| large_thumbnail_url | `https://d28dhd8eubcyz4.cloudfront.net/iiif/2/curtis-production2-cache%2F6210%2F5%2F1%2F<uuid-tail>%2Fresize_master_<hash>.jpg/full/!880,1024/0/default.jpg?sig=<sig>` |
| thumbnail_url | same shape at `/full/!440,512/` |
| landing_url | `https://horowhenua.kete.net.nz/item/<uuid>` |
| dc_identifier | `oai:curtis/<uuid-tail>` — the `curtis` OAI namespace was the tell that this is the
  same Recollect signed-IIIF platform as Feilding (`curtis-production2-cache`), confirmed before
  even checking the image URL shape |
| content_partner | `["Kete Horowhenua"]` |
| rights | Creative Commons variants (`Attribution + Noncommercial + ShareAlike`, etc.) |

## Current production strategy (baseline)

Not currently served — Kete Horowhenua is not in `NZImageApi.collectionWeights`.

## Live site investigation (Discovery Playbook)

- **Platform match confirmed independently of Feilding's investigation:** identical CloudFront IIIF
  path shape (`iiif/2/curtis-production2-cache%2F<shard>%2F<uuid>%2Fresize_master_<hash>.jpg/full/
  !<w>,<h>/0/default.jpg?sig=<sig>`), identical signed-size tiers (`!440,512` thumb, `!880,1024`
  large), and **`/full/max/` with the harvested signature still returns 403** — confirming sizes
  are individually signed and can't be forged, exactly as established at Feilding.
- **Item landing page is fetchable** (unlike Te Ara 50's Cloudflare wall) — plain `curl` with a
  browser UA returns 200.
- **The item page HTML contains the same `/item/<uuid>/files/<fileId>/download?variant=original`
  link pattern as Feilding.** Following it: 302 → `curtis-production2-store.s3.ap-southeast-2.
  amazonaws.com/<path>/<original-filename>.jpg?X-Amz-...` (a presigned GET URL, ~24 min expiry).
- **★ Unlike Feilding, every original tested is a plain JPEG, not TIFF.** A wide census (24 records
  sampled across the full ~24,104-record range, `page = 40×n` for n=1..24) fetched each item's
  resolved download URL and inspected the first bytes: **24/24 JPEG, 0 TIFF, 0 failures, 0 missing
  download links.** EXIF on several shows `model=HP ScanJet 5590` — a flatbed-scanner digitisation
  workflow (donated community photos), consistent with JPEG-only originals (no archival TIFF
  masters as Feilding's professional scanning pipeline produced).
- **Because the original is always browser-displayable, NO converter proxy is needed** — a pure
  Swift URL-construction strategy suffices, unlike Feilding's TIFF→JPEG Pillow converter route. This
  means **zero AWS deployment** for this collection.
- **★ HEAD vs. ranged-GET gotcha (same family as Te Papa's, already in the codebase as
  `rangeStatusFollowingRedirects`):** the S3 presigned URL is signed for `GET` only — a `HEAD`
  request against it returns **403 Forbidden** (confirmed via `curl -I -L`), even though a real
  `GET` (or a 1-byte ranged `GET`) succeeds (**200** full, **206** ranged). The existing
  `NetworkRequestManager.rangeStatusFollowingRedirects` (built for Te Papa) was reused verbatim to
  verify the constructed download URL before returning it.
- **Pixel-dimension survey (16 records across pages 2–500):** baseline (`!880,1024` IIIF) vs.
  resolved original — **0 honest-smaller** (min ratio 1.00, several already-small baselines like
  267×276 / 640×427 where the original genuinely is that small — never worse), **median 2.44×**,
  **max 67.76×** (923×8419 ≈ 7.8 MP tall panoramic scan; one outlier 6837×8269 ≈ 56.5 MP). One
  transient `Connection reset by peer` on a single fetch during the survey (not reproducible,
  treated as a network blip, not a site defect).

## Decision

**committed Group B ADD.** New reusable-shaped strategy `keteHorowhenuaOriginal` (though currently
used by only this one collection): resolve the item page's `download?variant=original` link via one
bounded HTML GET, verify with a ranged-GET probe (reusing the existing `rangeStatusFollowingRedirects`
built for Te Papa), and return the resolved URL directly. Falls back to the harvested `!880,1024`
signed IIIF JPEG on any failure (no landing URL, non-`kete.net.nz` host, fetch failure, no download
link found, or the ranged-GET probe fails) — never a broken image, never a raw non-displayable
format (moot here since originals are always JPEG, but the guard is there for safety).

## Implementation

- `Sources/NZImageApiLambda/Helpers/URLProcessor.swift`: new `"Kete Horowhenua"` registry entry
  (dispatches to `keteHorowhenuaOriginal`); new `private static func keteHorowhenuaOriginal(_:_:)`
  helper (added after `feildingConverter`).
- `Sources/NZImageApiLambda/NZImageApi.swift`: `collectionWeights["Kete Horowhenua"] = 0.002`
  (provisional, added after Puke Ariki).
- No converter changes, no `template.yaml` changes, no AWS deployment.

## Verification

- `swift build`: exit 0.
- `CollectionTester "Kete Horowhenua"` ×6: all 6 picks dispatched to `keteHorowhenuaOriginal` (URLs
  matched the `/item/<uuid>/files/<fileId>/download?variant=original` shape, not the harvested
  IIIF fallback).
- **★ CollectionTester's own HTTP validator reported a false-negative `HTTP 403`** on every pick —
  its `validateImageURL` (`Sources/Testing/LambdaTesting/LambdaTesting.swift`) issues a plain `HEAD`,
  which the S3 presigned-GET target rejects (documented above). Manually verified all 6 picks with a
  real `curl -L` **GET**: **6/6 HTTP 200**, valid `image/jpeg`, dimensions ranging 650×487 up to
  1692×1290 (plus the earlier hand-picked example 843×592). This is a known tester-tool limitation
  (same family as the Auckland Museum "slow-HEAD" and Te Papa "HEAD-403" artifacts already
  documented in `recipes.md`), not a defect in the served URL — treated as **PASS**.
- **User approved the live URL in a browser, 2026-07-04.**

## Example live URLs

- `https://horowhenua.kete.net.nz/item/51c68d4b-4c5f-49e0-8c50-8247fbc7b528/files/5cb7d324-6207-47a5-bb85-4c8be50370d1/download?variant=original`
  (736×959, CollectionTester pick 1) — user-approved example.
- `https://horowhenua.kete.net.nz/item/51ea29e9-af43-4260-a0e1-7e179752ca0d/files/988716e3-133f-410c-be56-a06c9f2ed7b8/download?variant=original`
  (1692×1290, CollectionTester pick 3).

## Commit

(recorded after this bookkeeping commit)
