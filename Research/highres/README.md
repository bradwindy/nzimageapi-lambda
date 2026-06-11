# High-Resolution Collection Sweep — Durable Record

This directory is the **single source of truth** for the high-res collection sweep.
A fresh Claude Code session with zero prior context can resume the work using only
these files.

## Current resume state (updated 2026-06-11)

**Wellington removal: done.** Collections **1–29 terminal** (Howick 17 RE-DONE; TAPUHI 25 committed via a
self-hosted JP2→JPEG converter; Canterbury 26, Auckland Art Gallery 27, Culture Waitaki 28, South
Canterbury Museum 29 all no-improvement). The per-collection sweep is **UNPAUSED — next is order 30 (V.C.
Browne & Son NZ Aerial Photograph Collection).** `progress.json` is authoritative; this is a human summary.

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
| 17 | Howick Historical Village NZMuseums | eHive | **RE-DONE** (was wrongly no-improvement) — migrated passthrough→`ehiveIIIFLargest`; `iiif.ehive.com` master TIFF serves up to ~14× (3000×2001) for ~85%, honest native for the rest. User still emailed museum for true TIFF originals |
| 18 | Mataura Museum NZMuseums | eHive | committed ADD — new `ehiveIIIFLargest` (IIIF `/full/full/` master TIFF, 1.56×–36×; 28/28 win) |
| 19 | New Zealand Portrait Gallery NZMuseums | eHive | committed ADD — `ehiveIIIFLargest` (24/24 win, 1.27×–49.3×, up to 21 MP; no anomalies) |
| 20 | Waimate Museum and Archives PastPerfect | pastPerfect | no-improvement — PPO display capped at 950px; true originals exist as 403-locked S3 upload zips (`imageuploads2/0000001110/`). User to seek access |
| 21 | Te Papa Collections Online | tepapa media | committed — new `tePapaLargest`: ranged-GET probe → `/full` direct for ~62% open-access (21–97 MP), weserv `/preview` unchanged for in-copyright |
| 22 | Auckland Museum Collections | aklMuseumCloudimg | committed — **fixed broken pipeline** (J: prefix + unencoded path → 404 for all); `aklMuseumCloudimg` strips drive prefix + percent-encodes the `object_av_link`, `org_if_sml=1` native master (0.36–71 MP) |
| 23 | Auckland Libraries Heritage Images | thumbnailer | **blocked + REMOVED** — DigitalNZ harvest fully degraded (0/700 have any image URL; hard-fails every request; was weight 0.182 = largest). Content already served by Kura Heritage (order 16) at full IIIF res |
| 24 | Hawke's Bay Knowledge Bank | knowledgeBankMaster | committed — **fixed broken weserv** (weserv 404s on its CDN); new `knowledgeBankMaster` scrapes landing for the honest `/master/` original (up to 76 MP), direct; honest harvested fallback (never the upscaled `/images/<base>.jpg` rendition) |
| 25 | TAPUHI | ndha (Rosetta JP2) | committed — self-hosted Python+Pillow **JP2→JPEG converter Lambda** (SAM stack, Function URL) + `tapuhiConverter` strategy; verified live (3737×2148 / 4000×3066, renders in Chrome); 700px `NLNZStreamGate` fallback. See `logs/025-tapuhi.md` |
| 26 | Canterbury Museum | vernon (Vernon CMS) | no-improvement — shipped `large→xlarge` swap already serves the public ceiling. `xlarge` (~1000–1200px box) is the max public derivative; `display`/`original`/`master`/`full`/`xxlarge` all S3 403; no public IIIF/zoom; object pages AWS-WAF-walled; the site's own "download" serves `xlarge` (user-confirmed). NOT eMuseum — Vernon (detected via the 404 page's `vernon-*.min.js`). Left in legacy `switch` (shared with Culture Waitaki) |
| 27 | Auckland Art Gallery Toi o Tāmaki | vernon (Vernon CMS) | no-improvement — shipped `medium→xlarge` swap already serves the reliable public ceiling (`xlarge` 1600px box; above → 403, 18/18; = the gallery's own `zoom_image`). Ruled out: live `-api` CDN `original` (3000px) is a ~4% edge-cache lottery, **not derivable** from the harvested URL (stable SHA-1 but non-linear dir remap), needs a per-request artwork-page fetch, not gallery-surfaced; eHive (account 3236) masters only 800px; no public IIIF/zoom. Left in legacy `switch` |
| 28 | Culture Waitaki | vernon (Vernon CMS) | no-improvement — clean Canterbury clone; shipped `large→xlarge` already serves `xlarge` (1200px box, 2.25× area over harvested `large`; above → 403, 14/14). No `-api` host (all candidates fail to resolve), no public IIIF (WAF-blocked), object pages WAF-walled; eHive (account 3011) **migrated to this Vernon site** (only a profile image left). Shares the legacy `switch` `case` with Canterbury 26 — **both occupants now verified no-improvement** |
| 29 | South Canterbury Museum | pastPerfect (was `boutique`) | no-improvement — **PastPerfect Online** (`museum_58`), same as Waimate 20: passthrough `large_thumbnail_url` is the 950px display ceiling; larger s3 variants 404, true originals 403-locked upload zips (`imageuploads2/0000000058/`), `/Media/<GUID>` is an HTML viewer, no IIIF, eHive 3359 migrated. **~9% of records dead at source** (s3+landing+Media all imageless; unfixable) — left as-is (no HEAD-check/retry; would only hard-fail). Stays in passthrough group |

**✅ Order 25 (TAPUHI) committed (2026-06-09) — sweep UNPAUSED.** The broken weserv-JP2 pipeline (weserv
**cannot decode JP2 → HTTP 404**) was replaced by a self-hosted **Python+Pillow JP2→JPEG converter Lambda**
deployed with the Swift Lambda under one **AWS SAM stack** (`template.yaml`, `Makefile`, `converter/`). The
Swift `tapuhiConverter` strategy returns `<JP2_CONVERTER_URL>/?url=<encoded FL JP2 stream>`; the converter
host-allowlists `ndhadeliver.natlib.govt.nz`, keeps grayscale, downscales the long side ≤4000px under the
6 MB Function URL cap, and falls back to the 700 px `NLNZStreamGate` access copy if the resolve throws or the
env var is unset. **Verified live on AWS** (renders in Chrome; canonical FL73782300 → 3737×2148, random
FL73383211 → 4000×3066). **Follow-up fix (2026-06-09):** the resolve now reads the stateless **Rosetta METS**
(`&dps_func=mets`) instead of scraping the ieViewer HTML — which omitted FL PIDs for most records — lifting
the deployed converter hit rate **~37% → ~93%**; and the converter decodes a **reduced JP2 level**
(`image.reduce`) so 48–69 MP masters that used to time out now convert in seconds (2048 MB / 60 s). **Cutover pending:** SAM created a NEW HTTP API endpoint
(`…/image`) + the converter Function URL and did NOT adopt the old hand-made function/API — repoint
clients/DNS to the new `ImageApiEndpoint`, then retire the old function (rollback path kept). Full detail in
`logs/025-tapuhi.md`. **Next: order 27 (Auckland Art Gallery Toi o Tāmaki).**

**✅ Order 26 (Canterbury Museum) no-improvement (2026-06-10).** Platform is **Vernon CMS** (Vernon
Systems — the eHive vendor), NOT eMuseum; detected via the 404 page's `vernon-common.min.js` /
`vernon-shortlist.min.js` because the object pages are **AWS-WAF-challenged** (HTTP 202
`x-amzn-waf-action: challenge`, uncrawlable by curl/Lambda/Wayback). Images on S3+CloudFront
`/records/images/<size>/<dir>/<sha1>.jpg`. The shipped `large→xlarge` swap already serves the public
ceiling: the Vernon token ladder caps at **`xlarge` (~1000–1200 px box)** and
`display`/`original`/`master`/`full`/`xxlarge` all S3-403 (uniform, not rights-gated); no public IIIF
(`/apis/iiif` + `/iiif` 404), no reachable zoom, `object_url` null, Wayback empty. `xlarge` is honest
(== `large` for sub-800px originals, 1.5–2.25× for bigger). The object page's "download from Collections
Online" serves `xlarge` (user-confirmed in-browser). An earlier "paid-only originals" claim was a
subagent inference — **withdrawn** (the Image Service page publishes no price). No code change; left in
the legacy `switch` (precedent: other no-improvement Group-A collections). See `logs/026-canterbury-museum.md`.

**✅ Order 27 (Auckland Art Gallery Toi o Tāmaki) no-improvement (2026-06-11).** Also **Vernon CMS**
(`artgallery-collection.cdn.aucklandunlimited.com/records/images/<size>/<dir>/<sha1>.jpg`), harvested at the
**`medium`** (400px) token. Shipped `medium→xlarge` already serves **`xlarge` = 1600 px box** (200 for 18/18;
everything above `xlarge` → 403, uniform) — the same ceiling the gallery's own artwork page displays (its
`zoom_image` field is `xlarge`; no `download`/IIIF/OpenSeadragon on the AAG page). **Two Vernon lessons
Canterbury didn't surface:** (1) **a second CDN host** `artgallery-collection-**api**.cdn…` (the live
website's host) exposes an extra **`original` = 3000 px** token — but it's a **disjoint** record set (SHA-1
hash **stable** across hosts, yet the `<dir>` bucket remaps **non-linearly**: 12457→13856 = +1399 but
646→7620 = +6974; the harvested dir+hash 403s on `-api`), `original` is an **unreliable ~4% edge-cache
lottery** (`0/21` + `0/70` + `0/7`-gentle-with-a-200-control all 403; only ~4 records ever 200, flipping —
ruled out rate-limiting), it's **not derivable** from the harvested URL (would need a per-request
artwork-page remap: id stable from harvested landing + slug from title), and the gallery never surfaces it.
(2) **eHive ≠ the high-res source:** AAG is on eHive (account **3236**, `iiif.ehive.com` master service live)
but its eHive masters are only **800×608** — *worse* than the Vernon `xlarge`; a museum can keep high-res in
Vernon CMS while pushing only thumbnails to eHive (always measure both). **Stale-harvest:** the harvested
`landing_url` + DigitalNZ `source` redirect both 404 (AAG restructured), but the artwork **id is stable**
(`/artwork/4166` ↔ `/artwork/4166/totaranui-i`) and the harvested image CDN still serves `medium`/`large`/
`xlarge` (200), so the shipped strategy is unaffected. No code change; left in the legacy `switch`. See
`logs/027-auckland-art-gallery-toi-o-tamaki.md`.

**✅ Order 28 (Culture Waitaki) no-improvement (2026-06-11).** A **clean Vernon CMS clone of Canterbury
(26)** — `collection.culturewaitaki.org.nz/records/images/<size>/<dir>/<sha1>.jpg` (image host == landing
host), harvested at **`large`**, object pages `/objects/<id>` **AWS-WAF-walled** (202 empty / 403
CloudFront). Ladder caps at **`xlarge` = 1200 px box** (above → 403, 14/14); shipped `large→xlarge` already
serves it — a genuine **2.25× area** win over the harvested `large` (800 px), honest (masters ≥1200 px).
Ruled out: **no `-api` CDN host** (unlike AAG 27 — `collection-api…`/`collection.cdn…`/`collection-api.cdn…`
all fail to resolve, so no `original` route), **no public IIIF/zoom** (`/apis/iiif`+`/iiif` 403, WAF-blocked),
and **eHive account 3011 is dead/migrated** (the Kōtuia aggregator org-page-3011 carries only the account
*profile* image and links to this Vernon site — the museum moved its collection off eHive onto Vernon;
`ehiveaccountid:3011` is a stale harvest id). Shares the legacy `switch` `case` with Canterbury 26 — **both
occupants now verified no-improvement.** No code change. See `logs/028-culture-waitaki.md`.

**✅ Order 29 (South Canterbury Museum) no-improvement (2026-06-11).** Platform identified (was `boutique`):
**PastPerfect Online** (`s3.amazonaws.com/pastperfectonline/images/museum_58/…`, landing
`timdc.pastperfectonline.com`) — the **same platform as Waimate (20)**. The passthrough
`large_thumbnail_url` **is** the display image, hard-capped at **950 px long side** = the public ceiling.
No larger anonymous route: larger s3 variants (`original/`/`large/`/`.tif`/`full/`) 404; `<file>-2.jpg` is
the same 950 px; `/Media/<GUID>` is an **HTML viewer page**, not an image; no IIIF/zoom; the "Original/Copy"
strings are catalog field labels. True originals exist only as **403-locked upload zips**
(`imageuploads2/0000000058/…Images###.zip`, GET = 403); eHive **3359** is migrated/legacy. Same resolution
outcome as Waimate 20 — no code change, stays in the passthrough group. **New caveat: ~9 % of records are
dead at source** (well-spread 250-sample = 8.8 %; older T-numbered photo batch ~16 %): the harvested s3 URL
404s, **and** the thumb + landing + `/Media` viewer reference no image (0/8 recoverable) — the image was
removed from PastPerfect (zombie records), unfixable anonymously. The Lambda validates only non-null
`large_thumbnail_url` (no HEAD-check / retry loop — `DigitalNZAPIDataSource.swift:108-117`), so ~9 % of
South Canterbury picks return a broken image; **left as-is** (user decision — a HEAD-probe would only turn a
broken image into a hard error with no alternate to serve, cf. Tauranga 01 CAT3 / He Purapura 10). User will
**not** pursue the museum's paid repro service. See `logs/029-south-canterbury-museum.md`.

**Also learned (order 25):** `thumbnailer.digitalnz.org` is **decommissioned (NXDOMAIN)** — the
`thumbnailerProxy` recipe/helper is dead (helper is unreferenced; remove in the final cleanup).

**★ eHive lesson (CORRECTED 2026-06-07 — the order-17 Howick conclusion was WRONG):** the `_l` (800px)
suffix is NOT the ceiling. eHive runs a **public IIIF Image API 2.0 service over the master TIFF** at
**`iiif.ehive.com`** (a *separate host* from `images.ehive.com`), wired to each object page's
**OpenSeadragon** viewer. Grep the landing-page HTML for `iiif`/`openseadragon`/`tileSources` to find
`info: "https://iiif.ehive.com/iiif/2/accounts%2f<acct>%2fobjects%2fimages%2f<id>.tif/info.json"`.
`/full/full/0/default.jpg` returns the full native master as JPEG **for every record regardless of
rights** (NOT rights-gated, unlike the `_xl`/`_o` suffixes which 500). The Swift strategy
`ehiveIIIFLargest` builds this URL purely from the `_l` URL (drop the last `_<size>` segment, `.jpg`→
`.tif`, `/`→`%2f`). Edge case (~11% of Howick): eHive sometimes **upscales `_l` to 800px** from a
smaller real master — IIIF then returns the honest (smaller) native; user chose honest-native-always
(consistent with Kura 16).

**IIIF note (Kura):** for any IIIF service NEVER hardcode a width — `sizeAboveFull` makes a fixed
width > native UPSCALE (fake pixels). Read `info.json`; request `/full/max/`. (Kura's native is capped
at 2000px; no larger master via download endpoints.)

**Flickr cluster (orders 11–15) COMPLETE.** Final Flickr decision tree (in `recipes.md`): `object_url`
present → serve the `_o` original (free, no fetch — Turnbull 12, Dunedin 13, ANMM 15); `object_url`
null → `flickrLandingLargest` (scrape the photo page for `_h`/`_k`/`_o`, `_b` fallback — SLNSW 14, Te
Ara 11). Reusable registry helpers: `flickrLargest` (`_b` swap), `flickrLandingLargest` (page-scrape).
`getSizes` API is unavailable (Flickr Pro now required for a key).

**Legacy `switch` remaining (NOT yet migrated to the registry)** — these are the still-untouched
collections (each migrates to the registry as it's processed): Tāmiro (sole recollect occupant,
no-improvement), Auckland Libraries Heritage (thumbnailer), Auckland Museum (cloudimg),
Culture Waitaki (large→xlarge; shares this `case` with Canterbury 26 — **BOTH verified
no-improvement (Canterbury 2026-06-10, Culture Waitaki 2026-06-11), intentionally left in the
switch**), passthrough group (Antarctica, National
Publicity, South Canterbury, Waimate, Te Toi Uku, Te Hikoi, V.C. Browne), TAPUHI
(fetchTapuhiHighResUrl), Hawke's Bay (weserv), Auckland Art Gallery (medium→xlarge; **verified
no-improvement 2026-06-11, intentionally left in the switch** — Vernon CMS, `xlarge` is the public
ceiling), National Army Museum (og:image→downloadwiz). Migrated to the registry so far: all Recollect (1–10), all Flickr
(11–15), Kura (16), **eHive (Howick 17, Mataura 18, NZ Portrait Gallery 19) via `ehiveIIIFLargest`**,
**Te Papa (21) via `tePapaLargest`**.

**Reusable strategies in `URLProcessor` (registry):** `recollectLargest` (HEAD-probe `downloadwiz`
→ master, else `-max`; for instances WITH masters), `recollectDisplayMax` (rip id → `-max`, no
probe; for instances where the thumb `downloadwiz` is uniformly 404 but `-max` > `-600`, e.g.
Hocken). Recollect domains live in `recollectDomainMap`. **`ehiveIIIFLargest`** (eHive): rewrite the
`images.ehive.com/.../<id>_l.jpg` URL to `iiif.ehive.com/iiif/2/<enc>.tif/full/full/0/default.jpg`
(honest native master; pure string build, no fetch).

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
