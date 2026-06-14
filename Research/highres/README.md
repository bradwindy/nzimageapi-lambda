# High-Resolution Collection Sweep — Durable Record

This directory is the **single source of truth** for the high-res collection sweep.
A fresh Claude Code session with zero prior context can resume the work using only
these files.

## Current resume state (updated 2026-06-14)

**Wellington removal: done.** Collections **1–37 terminal** (Howick 17 RE-DONE; TAPUHI 25 committed via a
self-hosted JP2→JPEG converter; Canterbury 26, Auckland Art Gallery 27, Culture Waitaki 28, South
Canterbury Museum 29, V.C. Browne 30 all no-improvement; **Te Hikoi 31 + Te Toi Uku 32 committed
IMPROVEMENTS**, **Te Ūaka 33 + Wyndham 34 committed Group B ADDs** — all four `boutique`-mislabel-actually-
eHive, `ehiveIIIFLargest`, 800→1000/1200/up-to-4000px; **Feilding 35 committed Group B ADD** — Recollect
new-gen **signed-IIIF**, the ~25 MP TIFF original routed through the **now-generic JP2+TIFF converter**, up to
~13 MP live; **Clutha 36 committed Group B ADD** — `boutique`-mislabel-actually-**Recollect** `downloadwiz`,
`recollectLargest`, masters up to 26 MP, median 4.27×; **John Kinder 37 committed Group B ADD** —
`boutique`-mislabel-actually-**Recollect** `downloadwiz`, **TWO-ASSET** (cf. NAM), new reusable
`recollectOgImageMaster` scrapes the node `og:image` → the master-bearing primary asset id, masters up to
42.7 MP, median 3.81×). The per-collection sweep is **UNPAUSED — next is order 38 (Tasman Heritage).**
`progress.json` is authoritative; this is a human summary.

> **Vendor note (corrected 2026-06-14):** **Recollect** (both the `*.recollect.co.nz` `downloadwiz`
> sites and the `recollectcms.com` signed-IIIF sites) is made by **Recollect Ltd** (spun out of
> **NZMS — New Zealand Micrographic Services** — in 2019). It is **NOT** an Axiell product, and the
> two are **one vendor's two product generations**, not two vendors. (Earlier records in this sweep
> wrongly said "Axiell Recollect" / "two vendors" — being corrected. The genuine **Axiell** product
> in this sweep is **Axiell Arena**, the Archives NZ portal in order 03.)

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
| 30 | V.C. Browne & Son NZ Aerial Photograph Collection | boutique (commercial site) | no-improvement — company's own ASP.NET sales site; passthrough `large_thumbnail_url` is the only free image, ~700–756px and **watermarked** ("Copyright V.C. Browne & Son"). Full scrape found no anonymous larger/clean route (larger suffixes/dirs/handlers/resize all 404/ignored; `/Images/` not listable; `Detail.aspx` is an error page; CAPTCHA-gated; Wayback has only thumbs); clean high-res is **paid**. User declined removal. ~5% dead at source. Stays in passthrough group |
| 31 | Te Hikoi Museum | ehiveIIIF (was `boutique`) | **committed IMPROVEMENT** — **live eHive** (account 3278), was mis-placed in the passthrough group serving the `_l` 800px derivative. Moved to the existing proven `ehiveIIIFLargest` (same as Mataura 18 / Howick 17 / Portrait Gallery 19) → IIIF `full/full` master. Te Hikoi's public master is **capped at exactly 1000px** (bimodal exact-800/1000 = server-side cap; true ≤20MB original is sign-in-only). **80% of records 800→1000 (×1.56 area), 20% already ≤800 → native, 0/70 worse or failed.** `swift build` 0; CollectionTester ×3 HTTP 200 |
| 32 | Te Toi Uku, Crown Lynn and Clayworks Museum | ehiveIIIF (was `boutique`) | **committed IMPROVEMENT** — **live eHive** (account 3384), 2nd `boutique`-mislabel-actually-eHive in a row. Same fix → `ehiveIIIFLargest` IIIF `full/full` master. Public master **capped at 1200px** (higher than Te Hikoi's 1000): **66/70 → 1200 (×2.25 area), 2 → 1000, 2 → ≤800; 68/70 (97%) gain.** Health: `_l` 200 70/70, IIIF 200 70/70, bigger 68 / equal 1 / honest-smaller 1 (de-faked 793 vs upscaled-800 `_l`) / 0 failures. `swift build` 0; CollectionTester ×3 HTTP 200 (1200×1053 vs `_l` 800×702) |
| 33 | Te Ūaka The Lyttelton Museum | ehiveIIIF (was `boutique`) | **committed Group B ADD** — **live eHive** (account 5362), 3rd `boutique`-mislabel-actually-eHive in a row; was **NOT in the Lambda** (no weight → never served; recent Lyttelton Museum rebrand). **Added** `ehiveIIIFLargest` + `collectionWeights` 0.009 (provisional). **MIXED masters** (120-rec full sample): ≤800: 48 (40%, parity), 1000: 54 (45%, ×1.56), **4000/12 MP: 18 (15%, ×25 area)** → 60% gain, 0 worse, 0 failures. 4000px batch (`cpa*` ids) is real native (info.json pyramid + `full/max`). Sampling trap noted (hex-only regex hid the 4000px non-hex ids). `swift build` 0; CollectionTester ×4 HTTP 200 |
| 34 | Wyndham & Districts Historical Museum | ehiveIIIF (was `boutique`) | **committed Group B ADD** — **live eHive** (account 3102), 4th `boutique`-mislabel-actually-eHive in a row; was **NOT in the Lambda** (no weight → never served). **Added** `ehiveIIIFLargest` + `collectionWeights` 0.002 (provisional). **Near-uniform 1000px** masters (120-rec full sample via info.json, min 1000): **801–1000: 118 (98%, ×1.56 over 800px `_l`), >3000: 2 (~2%)**; a spread check hit a **4242×7065 (~30 MP)** master. Master min 1000 > `_l` cap 800 ⇒ every IIIF ≥ `_l`, **0 worse / 0 failures** (no honest-smaller possible). All ids 32-hex (no order-33 sampling trap). **~1.5% (60/3937) records null-image at source** (hard-fail pick, left as-is cf. 29). `swift build` 0; CollectionTester ×4 HTTP 200 |
| 35 | Feilding Library | recollectIIIF (was `boutique`) | **committed Group B ADD** — **Recollect new-generation signed-IIIF** (`recollectcms.com`, `curtis-production2-cache`), the same vendor's newer generation vs the older `*.recollect.co.nz downloadwiz` sites (both **Recollect Ltd / NZMS**, not Axiell); was **NOT in the Lambda** (no weight → never served). Harvested signed IIIF derivative is hard-capped at **≈880×886 (0.78 MP)** — the **CloudFront signature is path-bound**, so `/full/max/` → **403 `SignatureDoesNotMatch`** (public ceiling `!1170,1170` = 1.36 MP). The **~25 MP TIFF original** (item page `…/files/<fileId>/download?variant=original` → 302 → presigned S3) is **undisplayable + 504s weserv**, so routed through the **existing self-hosted Pillow converter — now a generic JP2+TIFF master→JPEG proxy** (multi-host `ALLOWED_HOSTS`, libtiff build-assert), via new `feildingConverter` (one HTML GET for the `<fileId>`) → ≤4000 px JPEG (up to ~16 MP). **Graceful fallback to the signed `!880,1024` JPEG** (login-walled records). **Deployed live** (in-place SAM update, 3 Modify/0 replace); 6/6 local + 4/4 live picks HTTP 200 `image/jpeg` (up to 13.4 MP); TAPUHI regression unchanged. `collectionWeights` 0.002 (provisional). See `logs/035-feilding-library.md` |
| 36 | Clutha Heritage | recollect (was `boutique`) | **committed Group B ADD** — healthy **Recollect** (`clutha.recollect.co.nz`, the older `downloadwiz` generation — NOT Axiell), **not boutique**; was **NOT in the Lambda** (no weight → never served). `downloadwiz` master present for **99.5%** (784/788; JPEG octet-stream/attachment, up to **6000×4379 = 26 MP**) vs the `-600`==`-max` ~1000 px display cap → **34/36 pixel-sample win, median 4.27×, max 36×**; 2/36 honest-smaller (small originals whose `-600` is upscaled-fake; master gives honest native). Added via the existing **`recollectLargest`** (HEAD-probe `downloadwiz` → master, else `-max`) + `recollectDomainMap`. The 4 newest-batch records (16437–16443) are CAT2 → `-max` fallback (200). No login-wall, all rights public. **Identity quirk:** "Clutha Heritage" is the DigitalNZ `primary_collection` (the `collection` field is `[]`/themed); the Lambda already queries `primary_collection` so the key works. **Vanity redirect:** `clutha.recollect.co.nz` → `heritage.cluthadc.govt.nz` (followed transparently). Pure code change (no deploy). `swift build` 0; CollectionTester ×4 HTTP 200 master (2.0×–6.5× over baseline). `collectionWeights` 0.002 (provisional). See `logs/036-clutha-heritage.md` |
| 37 | John Kinder Theological Library | recollect (was `boutique`) | **committed Group B ADD** — **Recollect** `downloadwiz` (`kinderlibrary.recollect.co.nz`, footer "Recollect Limited" — NOT Axiell), **not boutique**; was **NOT in the Lambda** (no weight → never served). **★ TWO-ASSET pattern (cf. NAM 02):** the harvested `large_thumbnail_url` id is a **master-less display derivative** (`downloadwiz/<thumbId>` 404, `display/<thumbId>-600`==`-max`==`-4000` all ≈1000 px), while the **node `og:image` points to a DIFFERENT primary asset id whose `downloadwiz` master IS present**. Uniform 80-rec survey: thumb-dw 200 = **0/80**, og id differs = **80/80**, og-dw 200 = **80/80 (100%)**, 0 login-walls. Pixel sample (32): **22 win (median 3.81×, max 43×/31.5 MP)**, 8 equal (small ≤1000 px native), 2 honest-smaller (upscaled-fake `-600` → honest 800 px native). Master = JPEG octet-stream/attachment, up to **7383×5779 = 42.7 MP**. `recollectLargest` (rips the master-less thumb id) would **regress every record to ~1000 px** ⇒ added the **NEW reusable `recollectOgImageMaster`** (one node-page HTML GET → SwiftSoup `og:image` → `slice` the og id → HEAD-probe `downloadwiz/<ogId>`, else `-max`; harvested-`url` fallback). Pure code change (no deploy). `swift build` 0; CollectionTester ×5 HTTP 200 master (decoded 42.7/24.5/28.1/12.1 MP + one 1.0 MP small native). `collectionWeights` 0.002 (provisional). See `logs/037-john-kinder-theological-library.md` |

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

**✅ Order 30 (V.C. Browne & Son) no-improvement (2026-06-11).** A commercial aerial-photography **sales
site** (the firm's own ASP.NET WebForms site, `www.vcbrowne.com`, `Detailprom.aspx`). The passthrough
`large_thumbnail_url` (`…/Images/<album>/<file>.jpg`) is the **only freely-available image** — uniformly
**~700–756 px and WATERMARKED** ("Copyright V.C. Browne & Son", baked into the JPEG; *viewed to confirm*).
A **full site scrape** (user-requested) found **no anonymous route** to anything larger or un-watermarked:
larger suffixes (`-HR/-L/-XL/-ORIG/_large/-2000`) and parallel hi-res dirs (`/HiRes//Originals//Large/…`)
all 404; resize params (`?w=/?width=/?size`) ignored; `/Images/` not directory-listable (403);
`Detail.aspx` (non-`prom`) is an **error page**, `Order/Basket` are stubs; the detail page is
**CAPTCHA-gated**; no `.ashx` image handler; `robots.txt`/`sitemap.xml` 404; Wayback has **only the `-TH`
thumbnails**. Clean full-resolution scans are the company's **paid product**. (The HTML's "watermark"
strings are an ASP.NET `TextBoxWatermarkBehavior` form-hint — a red herring, not an image watermark.) User
**considered but declined removal** (images are genuine, if watermarked). ~5 % of records are dead at
source (404). No code change; stays in the passthrough group. See
`logs/030-v-c-browne-son-nz-aerial-photograph-collection.md`.

**✅ Order 31 (Te Hikoi Museum) committed IMPROVEMENT (2026-06-12).** Platform identified (was `boutique`):
**live eHive**, account **3278** (`images.ehive.com/accounts/3278/…_l.jpg`). Te Hikoi was **mis-placed in
the passthrough group** serving the `_l` **800 px** derivative, even though the codebase already has the
proven **`ehiveIIIFLargest`** strategy (Mataura 18 / Howick 17 / Portrait Gallery 19). Moved it into the
`strategies` registry → IIIF `full/full` over the master TIFF. Te Hikoi's public master is **capped at
exactly 1000 px** — a 70-record spread is **bimodal exact-800 / exact-1000** (min 800, max 1000, median
1000), i.e. a **server-side public cap**, not natural original sizes (eHive docs: the true ≤20 MB original
is **sign-in-only**). Result: **56/70 (80%) gain 800→1000 (×1.56 area); 14/70 (20%) already ≤800 → native;
0/70 worse or failed** (`_l` 200 70/70, IIIF default.jpg 200 70/70). The honest endpoint is `full/full`
(=`full/max`=1000 px); eHive **upscales** fixed-width requests above the master (`full/2000,`→2000 px fake),
so `ehiveIIIFLargest` deliberately uses `full/full` only. A **much smaller** eHive account than the others
(1000 px cap vs up to ~12–21 MP). `swift build` 0; CollectionTester ×3 HTTP 200 image/jpeg (1000×667 vs
`_l` 800×534; 800×533 vs 800×533 no-regression). **Lesson: a "boutique"-classified collection can actually
be live eHive — always probe `images.ehive.com` and route via `ehiveIIIFLargest`, never passthrough.** See
`logs/031-te-hikoi-museum.md`.

**✅ Order 32 (Te Toi Uku, Crown Lynn and Clayworks Museum) committed IMPROVEMENT (2026-06-12).** **2nd
`boutique`-mislabel-actually-eHive in a row** — live eHive account **3384**, same situation as Te Hikoi 31.
Moved from the passthrough group → the existing proven **`ehiveIIIFLargest`** (IIIF `full/full` over the
master TIFF). Te Toi Uku's public master is **capped at 1200 px** (higher than Te Hikoi's 1000 px): a
70-record spread is min 793 / max 1200 / median 1200 — **66/70 → 1200 px (×2.25 area), 2 → 1000, 2 → ≤800;
68/70 (97%) gain**. Parity: `_l` 200 70/70, IIIF default.jpg 200 70/70, **bigger 68 / equal 1 /
honest-smaller 1 / failures 0**. The one honest-smaller record (`2bfc22a5`) has a genuine 793 px native
(info.json `sizes` max = 793) but eHive **upscaled its `_l` to a fake 800 px** — IIIF serves the honest 793
(real detail), per **honest-native-always** (orders 17/18, Kura 16). Honest endpoint is `full/full`
(=`full/max`=1200 px); fixed-width requests above the master upscale (so not used). `swift build` 0;
CollectionTester ×3 HTTP 200 image/jpeg (1000×750; **1200×1053 vs `_l` 800×702**; 900×1200). **Lesson: eHive
accounts each set their own public IIIF cap (800 / 1000 / 1200 / full native up to ~21 MP) — sample the
distribution per account; the `ehiveIIIFLargest` transform is identical.** See
`logs/032-te-toi-uku-crown-lynn-and-clayworks-museum.md`.

**✅ Order 33 (Te Ūaka The Lyttelton Museum) committed Group B ADD (2026-06-12).** **3rd
`boutique`-mislabel-actually-eHive in a row** — live eHive account **5362** (~18,588 records). **Was NOT in
the Lambda:** no `collectionWeights` entry, so `weightedRandomPick()` never selected it (`Te Ūaka` is a
recent rebrand of Lyttelton Museum, post-dating the 2024 weights snapshot). **Added** a `strategies` entry →
the existing proven **`ehiveIIIFLargest`** AND `collectionWeights` **0.009** (provisional rawItemCount-share,
renormalized in the final pass). Te Ūaka's masters are **MIXED** (unlike Te Hikoi's 1000 / Te Toi Uku's 1200
single caps): a 120-record sample across the FULL collection = min 800 / max 4000 / median 1000 — **≤800: 48
(40%, parity), 1000: 54 (45%, ×1.56), 4000 px / 12 MP: 18 (15%, ×25 area)** → **72/120 (60%) gain, 0 worse, 0
failures**. The 4000 px batch (the older `cpa*`-token ids) is a **real native master** (info.json pyramid
125→4000, 6 scaleFactors; `full/full`==`full/max`; `full/6000,` upscales-fake). **★ Sampling trap recorded:**
an initial hex-only id regex BIASED the sample to the 1000 px newer uploads and MISSED the 4000 px non-hex
ids — classify eHive ids by the actual `ehiveIIIFLargest` rule (drop only the last `_<size>`). `swift build`
0; CollectionTester ×4 HTTP 200 image/jpeg (972×1000; **800×600 non-hex parity record**; 1000×765; 997×1000;
plus verified 4000×3000 `cpa` master). See `logs/033-te-uaka-the-lyttelton-museum.md`.

**✅ Order 34 (Wyndham & Districts Historical Museum) committed Group B ADD (2026-06-12).** **4th
`boutique`-mislabel-actually-eHive in a row** — live eHive account **3102** (3,937 records). **Was NOT in the
Lambda** (no `collectionWeights` entry → never served). **Added** a `strategies` entry → the proven
**`ehiveIIIFLargest`** AND `collectionWeights` **0.002** (provisional rawItemCount-share). Unlike Te Ūaka 33's
mixed masters, account 3102 is **near-uniform 1000 px**: a 120-record full-collection sample (measured via
info.json, **0 errors**) = min 1000 / max 4581 / median 1000 → **801–1000: 118 (98%, ×1.56 area over the 800
px `_l`), >3000: 2 (~2%)** (4581×2690, 3199×4351 ≈ 12–14 MP); a 15-record `_l`-vs-IIIF spread check also hit a
**4242×7065 (~30 MP)** master. Because the master **min is 1000 px and the `_l` suffix caps at 800 px**, IIIF
`full/full` is **always ≥ `_l`** → **0 worse, 0 failures** (no honest-smaller anomaly is even possible here,
unlike Te Toi Uku 32's de-faked 793 px record). **All ids are 32-hex** (no older non-hex `cpa*` tokens, so the
order-33 sampling trap did not recur — still classified by the drop-last-`_<size>` rule). **New caveat:
~1.5% (60/3,937) of records have a null `large_thumbnail_url`** (no image harvested); the data source picks a
random record and `.checkHasTitleAndLargeImage()` throws with no retry, so ~1.5% of Wyndham picks hard-fail —
**left as-is** (well below South Canterbury 29's ~9%; HEAD/retry out of scope per precedent). `swift build` 0;
CollectionTester ×4 HTTP 200 image/jpeg. See `logs/034-wyndham-districts-historical-museum.md`.

**✅ Order 35 (Feilding Library) committed Group B ADD (2026-06-12).** First **Recollect
new-generation signed-IIIF** collection — `recollectcms.com`, cache `curtis-production2-cache`,
the **newer product generation of the same vendor** as the `*.recollect.co.nz downloadwiz` sites
(both are **Recollect Ltd / NZMS** — NOT Axiell, NOT two vendors; corrected 2026-06-14). **Was NOT in the Lambda**
(no `collectionWeights` → never served). The harvested `large_thumbnail_url` is a **CloudFront-signed IIIF
derivative hard-capped at ≈880×886 (0.78 MP)**: the **signature is bound to the exact derivative path**, so
mutating `/full/!880,1024/` → `/full/max/` returns **403 `SignatureDoesNotMatch`** — larger IIIF sizes cannot
be forged (the site pre-signs only `{!440,512, !880,1024, !1170,1170}`; the public ceiling `!1170,1170` is just
1.36 MP). The **true ~25 MP TIFF original** is reachable via the item page's
`…/files/<fileId>/download?variant=original` link (302 → short-lived presigned S3), but **TIFF is not
browser-displayable and the ~75 MB file 504s weserv**. **User decision:** route it through the **existing
self-hosted Pillow converter Lambda (the TAPUHI one) — now a generic JP2 + TIFF master→JPEG proxy.** The
converter was generalized (`ALLOWED_HOST` → multi-host **`ALLOWED_HOSTS`**, env-tunable `DOWNLOAD_TIMEOUT`, a
build-time **`libtiff` assert**; **TIFF reuses the generic `convert_to_jpeg` with no new decode code**), and a
new Swift **`feildingConverter`** strategy does **one bounded HTML GET** of the landing page to recover the
`<fileId>` (it exists only in the page HTML), then emits `<JP2_CONVERTER_URL>/?url=<download endpoint>`; the
converter follows the 302 to S3 itself, downloads the TIFF, and returns a **≤4000 px JPEG (up to ~16 MP)**.
**Graceful fallback to the signed `!880,1024` JPEG** on any failure (login-walled records with no public
original). **Deployed live** under the existing SAM stack (in-place update — 3 `Modify`/0 replace; Function
URL + API endpoint unchanged): 6/6 local + 4/4 live forced-Feilding picks → HTTP 200 `image/jpeg`, multi-MP
(Stanway 1898 **4000×3358 / 13.4 MP** in 5.45 s cold; Macarthur St 4000×3000 / 12 MP; honest native when
smaller; never upscaled), TAPUHI regression unchanged (8.0 MP). `collectionWeights` **0.002** (provisional).
**Likely reuse: Manawatū Heritage (52)** (same Manawatu District Libraries) and possibly Kete Horowhenua (51) —
confirm per-collection. See `logs/035-feilding-library.md`.

**✅ Order 36 (Clutha Heritage) committed Group B ADD (2026-06-14).** Another `boutique`-mislabel — actually
**healthy Recollect** (`clutha.recollect.co.nz`), the **older `downloadwiz` generation** (NOT the Feilding-35
signed-IIIF generation; both are **Recollect Ltd / NZMS**, **NOT Axiell**). **Was NOT in the Lambda** (no
`collectionWeights` → never served). Same shape as Hastings (6) / Lower Hutt (7): the harvested
`/assets/display/<id>-600` is the ~1000 px display tier (`-600`==`-max`), while `/assets/downloadwiz/<id>`
serves the **JPEG master** (octet-stream/attachment, renders in `<img>`) for **99.5%** of records (784/788
uniform sample; up to **6000×4379 = 26 MP**). **Added** via the existing **`recollectLargest`** (HEAD-probe
`downloadwiz` following redirects → master, else `-max`) + a `recollectDomainMap` entry + `collectionWeights`
**0.002** (provisional). **34/36 pixel-sample win** (median **4.27×**, max 36×); **2/36 honest-smaller** —
small originals whose `-600` is **upscaled-fake** to ~1000 px, where the master/`-max` give the honest native
(the established honest-native-always choice, cf. Hocken 8 / Kura 16). The 4 non-200 records (16437–16443, the
newest batch) are **CAT2** — `downloadwiz` 404 but `-600`/`-max` 200, so `recollectLargest` serves `-max` (no
breakage). **No login-wall, all rights public/open** (no He-Purapura restricted tail). **★ Two gotchas:**
(1) "Clutha Heritage" is the DigitalNZ **`primary_collection`**, not the `collection` field
(`and[collection][]` → 0; the Lambda already queries `primary_collection` and dispatches on
`display_collection`="Clutha Heritage", so the single key works for query + weights + registry + domain map);
(2) `clutha.recollect.co.nz` **301-redirects to the council vanity domain `heritage.cluthadc.govt.nz`** —
both serve the master, the redirect is followed transparently (`headStatusFollowingRedirects` + browsers), so
the harvested `*.recollect.co.nz` host is kept (consistent with the other map entries). Pure code change (no
AWS deploy — unlike Feilding 35). `swift build` 0; CollectionTester ×4 HTTP 200 master (2.0×–6.5× over
baseline). See `logs/036-clutha-heritage.md`.

**✅ Order 37 (John Kinder Theological Library) committed Group B ADD (2026-06-14).** A 5th `boutique`
mislabel — actually **Recollect** `downloadwiz` (`kinderlibrary.recollect.co.nz`, footer "Recollect Limited",
**NOT Axiell**). **Was NOT in the Lambda** (no `collectionWeights` → never served). **★ This one is the
NAM-style TWO-ASSET pattern (order 02), now generalised into a reusable strategy.** The harvested
`large_thumbnail_url` id is a **master-less display derivative** — `downloadwiz/<thumbId>` 404s
("goDownload failed"), and `display/<thumbId>-600`==`-max`==`-1000…-4000` are all byte-identical ≈1000 px
(the size token unlocks nothing) — while the **node page's `og:image` references a DIFFERENT primary asset
id** (e.g. thumb 374245→og 374380) whose **`downloadwiz` master IS present**. Uniform **80-record survey**:
thumb-`downloadwiz` 200 = **0/80**, og id differs from thumb id = **80/80**, og-`downloadwiz` 200 =
**80/80 (100%)**, **0** login-walls / **0** dead nodes / **0** missing-og; og widths min 318 / median 1927 /
max 6587. **Pixel sample (32):** **22 win** (median **3.81×**, max **43.49×** / 31.5 MP), **8 equal** (small
≤1000 px native — master == display, no fakery), **2 honest-smaller** (the `-600` upscales small originals to
fake ~1000 px; `downloadwiz` serves the honest 800 px native — honest-native-always, cf. Clutha 36 / Hocken 8
/ Kura 16). Master = JPEG `application/octet-stream`+`attachment`, up to **7383×5779 = 42.7 MP**. Because the
harvested thumb id has **no master**, `recollectLargest` (which rips that id) would **regress every record to
~1000 px** — so I added the **NEW reusable `recollectOgImageMaster`**: one bounded `fetchHTML(landingUrl)` →
SwiftSoup `meta[property=og:image]` → `slice` the og id (`display/ … -`) → HEAD-probe `downloadwiz/<ogId>`
following redirects, serve on 200 else `display/<ogId>-max` (using the og:image's own host); fall back to the
harvested `url` on any failure. (The legacy NAM switch case is the same idea minus the master-probe/`-max`
fallback; left intact as already-optimal. The new helper is the reusable home for this pattern.)
`collectionWeights` **0.002** (provisional). Pure code change (no AWS deploy). `swift build` 0; CollectionTester
×5 HTTP 200 `downloadwiz` master (decoded 42.7 / 24.5 / 28.1 / 12.1 MP + one 1.0 MP small native; every pick's
final URL is `downloadwiz/<ogId>`, ogId ≠ harvested thumb id). See
`logs/037-john-kinder-theological-library.md`.

**★ Vendor correction (2026-06-14, user-flagged):** **Recollect is made by Recollect Ltd (spun out of NZMS —
New Zealand Micrographic Services — in 2019), NOT Axiell.** Earlier sweep records (logs 001–010/035,
`recipes.md`, code comments, this README) wrongly labelled it "Axiell Recollect" and called the two product
generations "two vendors" — **both wrong: one vendor, two generations.** Corrected across the records in this
commit. The only genuine **Axiell** product in the sweep is **Axiell Arena** (the Archives NZ portal, order 03).

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
Publicity, South Canterbury, Waimate, V.C. Browne — **Te Hikoi 31 + Te Toi Uku 32 migrated OUT to the
registry via `ehiveIIIFLargest`**), TAPUHI
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
0.05 (added); Mataura 0.003, Portrait Gallery 0.001, **Te Ūaka 0.009 (added — Group B, order 33)**, **Wyndham 0.002 (added — Group B, order 34)**;
Presbyterian 0.014 (removed). Weights currently sum < 1.0 — expected; the final pass recomputes all
from `rawItemCount`.

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
