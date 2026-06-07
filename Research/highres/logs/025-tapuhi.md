# 025 — TAPUHI

- **Group:** A (re-check, already in Lambda; legacy `switch` → 5-step NDHA resolve → weserv webp)
- **Platform:** NDHA / Rosetta 8.3 (`ndhadeliver.natlib.govt.nz`), National Library NZ
- **DigitalNZ result_count:** 301,618 (live, 2026-06-07)
- **Timestamp:** 2026-06-07
- **Status:** **HELD — investigation complete, NOT committed.** User is **forking this conversation to
  build a self-hosted JP2→JPEG converter**. Do **NOT** re-investigate; do **NOT** auto-proceed to order
  26. No Swift code was changed (the legacy switch case is untouched and currently **broken**, see below).

## Raw record sample (key redacted)

| field | value |
|-------|-------|
| large_thumbnail_url | `https://ndhadeliver.natlib.govt.nz/NLNZStreamGate/get?dps_pid=IE334493` (700 px access JPEG) |
| object_url | `https://ndhadeliver.natlib.govt.nz/content-aggregator/getIEs?system=emu&id=180758` |
| landing_url | `http://natlib.govt.nz/records/<id>` |

## Current shipped strategy is BROKEN

`fetchTapuhiHighResUrl` (URLProcessor.swift) does a 5-step resolve:
1. extract `IE<n>` from the harvested `NLNZStreamGate/get?dps_pid=IE…`,
2. GET `DeliveryManagerServlet?dps_pid=IE…` → scrape `dps_dvs` session,
3. GET `view/action/ieViewer.do?dps_dvs=…&dps_pid=IE…` → scrape `FL<n>` PIDs,
4. HEAD each `DeliveryManagerServlet?dps_pid=FL…&dps_func=stream`, pick the largest by Content-Length,
5. **`https://images.weserv.nl/?url=<FL stream>&output=webp`**.

Step 4 correctly finds the **preservation master**, but it is a **JPEG 2000 (JP2)**, and **weserv
cannot decode JP2** → step 5 returns **HTTP 404** (`{"status":"error","code":404,"message":"Invalid or
unsupported image format"}`). ⇒ **TAPUHI serves a broken image for every record right now.**

Verified end-to-end (record 22479626, IE334493):
- baseline `NLNZStreamGate/get?dps_pid=IE334493` → **700×402** `image/jpeg` (the access copy).
- FL stream `DeliveryManagerServlet?dps_pid=FL73782300&dps_func=stream` → **3737×2148 (8 MP)**,
  `image/jp2;charset=UTF-8`, 6 MB JPEG 2000 (28× the access copy). Works with **no cookies** (stateless).
- weserv on that JP2 → **404 unsupported format**.

## Why we can't "just serve the JP2 URL"

JPEG 2000 browser support (verified via caniuse `jpeg2000.json`, 2026-06-07):
- **Chrome / Firefox / Edge: never supported** (0 versions).
- **Safari: supported v5–v17.6, REMOVED in Safari 18+** (current 26.x = no).
- **Global support ≈ 2.1% and falling.** A raw `.jp2` URL renders as a **broken image for ~98% of
  visitors.** (This is why NDHA serves JP2 only as the preservation master and hands out a 700 px JPEG
  access copy publicly.)

## No free/keyless JP2→JPEG proxy exists (exhaustively tested, 2026-06-07)

| proxy | result |
|-------|--------|
| images.weserv.nl / wsrv.nl | **404 "unsupported image format"** (libvips build has no OpenJPEG) |
| thumbnailer.digitalnz.org | **DEAD — NXDOMAIN** (DigitalNZ decommissioned it; also kills the `thumbnailerProxy` recipe) |
| cloudimg (`ajrctguoxo`, Auckland Museum's token) | **406** — account-locked to its own origins; we have no project cloudimg account |
| Cloudinary `res.cloudinary.com/demo/image/fetch` | **401** (demo fetch disabled) |
| Photon `i0.wp.com` | **404** "remote data could not be fetched" (won't fetch the query-string NDHA URL) |
| imagecdn.app | **503** |
| cdn.statically.io `/img/` | **403** (endpoint disabled) |
| natlib IIIF / djatoka | **none** (`/iiif/…` 404; Rosetta 8.3 viewer is fancybox, not a tile/IIIF viewer) |
| Rosetta scaling params (`scale`, `dps_scale`, `width`, `format`) | **ignored** — always returns the full JP2 |
| natlib JPEG renditions | only the **700 px** IE access copy + a **150 px** FL `dps_func=thumbnail`; nothing between |

## Self-conversion is PROVEN feasible (the chosen direction)

`Pillow` (standard pip wheel, OpenJPEG bundled — `features.check('jpg_2000') == True`) decoded the actual
NDHA FL JP2 → full **8 MP JPEG** (3737×2148, mode L grayscale → 2.5 MB JPEG @ q85). So a self-hosted
converter is viable.

### Proposed architecture (for the fork to build)

Keep the main Swift API as a **pure URL builder** (the project's design rule). Add a **separate JP2→JPEG
proxy** that the browser hits when it loads the image:

- **A small AWS Lambda (Python + Pillow) behind a Function URL.** Input: an NDHA PID. It either takes an
  `FL` PID directly, or takes the `IE` PID and does the 5-step server-side (steps 1–4 above, already
  implemented in Swift `fetchTapuhiHighResUrl` — port the logic), downloads the JP2, `Image.open` →
  `convert('RGB')` → optionally downscale (cap long side, e.g. ≤ 3000–4000 px, to bound response size) →
  return `image/jpeg`.
- **Cache** to avoid re-converting the same image: CloudFront in front of the Function URL, and/or write
  the JPEG to S3 keyed by PID and 302/serve from there. (The same random record can recur; conversion is
  ~1–2 s + a 6 MB download, so caching matters.)
- **Main Swift TAPUHI strategy** then becomes: resolve to the FL PID (reuse the existing 5-step) and
  return `https://<proxy-fn-url>/?fl=<FLPID>` (or just `?ie=<IEPID>` and let the proxy do the 5-step).
  No image download in the main Lambda — it only builds the proxy URL.

### How to wire TAPUHI once the proxy exists
1. Deploy the converter; get its Function URL (or CloudFront domain).
2. Add a `tapuhiConverter` strategy (or adapt `tapuhi`) that returns the proxy URL for the resolved
   FL/IE PID. Migrate the legacy `case "TAPUHI"` → registry in the same commit.
3. Verify: `CollectionTester "TAPUHI"` → 200 `image/jpeg`; `curl|sips` the proxy URL → multi-MP (≈8 MP);
   confirm it renders in Chrome (not just Safari). Then user-approval gate → commit.

## Fallback if the converter is abandoned
Passthrough the harvested 700 px `NLNZStreamGate/get?dps_pid=IE…` (universally displayable; fixes the
broken weserv-JP2 pipeline; no resolution gain). Not done — user chose to build the converter instead.

## Decision

**HELD pending the self-hosted JP2 converter** (user forking to build it, 2026-06-07). No code change in
this session. TAPUHI remains broken in production until either the converter lands or the 700 px fallback
is applied. Group A weight 0.011 unchanged.

## Commit

(research notes only; no Swift change — TAPUHI implementation deferred to the converter fork)
