# High-Resolution Collection Sweep — Durable Record

This directory is the **single source of truth** for the high-res collection sweep.
A fresh Claude Code session with zero prior context can resume the work using only
these files.

## Current resume state (updated 2026-07-04)

**Wellington removal: done.** Collections **1–47 terminal** (Howick 17 RE-DONE; TAPUHI 25 committed via a
self-hosted JP2→JPEG converter; Canterbury 26, Auckland Art Gallery 27, Culture Waitaki 28, South
Canterbury Museum 29, V.C. Browne 30 all no-improvement; **Te Hikoi 31 + Te Toi Uku 32 committed
IMPROVEMENTS**, **Te Ūaka 33 + Wyndham 34 committed Group B ADDs** — all four `boutique`-mislabel-actually-
eHive, `ehiveIIIFLargest`, 800→1000/1200/up-to-4000px; **Feilding 35 committed Group B ADD** — Recollect
new-gen **signed-IIIF**, the ~25 MP TIFF original routed through the **now-generic JP2+TIFF converter**, up to
~13 MP live; **Clutha 36 committed Group B ADD** — `boutique`-mislabel-actually-**Recollect** `downloadwiz`,
`recollectLargest`, masters up to 26 MP, median 4.27×; **John Kinder 37 committed Group B ADD** —
`boutique`-mislabel-actually-**Recollect** `downloadwiz`, **TWO-ASSET** (cf. NAM), new reusable
`recollectOgImageMaster` scrapes the node `og:image` → the master-bearing primary asset id, masters up to
42.7 MP, median 3.81×; **Tasman 38 committed Group B ADD** — same `downloadwiz` TWO-ASSET, **reused**
`recollectOgImageMaster` (no new strategy) **+ a Clutha-style vanity redirect** to
`heritage.tasmanlibraries.govt.nz`; required a shared `fetchHTML` fix to carry the browser UA across the
cross-host redirect, masters up to ~10 MP, median 3.14×; **Western Bay Community Archives 39 committed
Group B ADD** — same `downloadwiz` TWO-ASSET, **reused** `recollectOgImageMaster` (no new strategy, no
vanity redirect), masters up to **57 MP** live, median 11.7×, with ~3% of harvested ids stale from a past
site migration → graceful fallback); **War Art Online 40 committed Group B ADD** — Archives NZ war
paintings on **NDHA/Rosetta**, 100% have a **TIFF preservation master** (~5000 px) reached via the same
Rosetta METS path as TAPUHI but TIFF not JP2, routed through the **already-deployed** generic JP2+TIFF
converter (`ndhadeliver` already allowlisted ⇒ **pure Swift, no redeploy**); ~80% of records (900 px
baseline) get a **~20× win**, ~20% (already ~5000 px baseline) **passthrough native**, ~1–2% (multi-page
PDF) convert one page — decided from the METS access-JPEG byte size since the Lambda can't decode images);
**Far North District Libraries Rediscovery 41 committed Group B ADD** — 8th `boutique`-mislabel-actually-
**Recollect** (`fndclibraries.recollect.co.nz`, classic `downloadwiz`), the 4th **TWO-ASSET** case →
**reused `recollectOgImageMaster`** (no new code, no domain-map entry, no deploy); og-`downloadwiz` master
**59/60 (98%)**, **58/60 pixel-win, median 23.4×, up to ~38 MP**; ~1.7% stale nodes (logo `og:image`) →
graceful harvested-`-600` fallback; **Pakiaka Rotorua Heritage Online 42 committed Group B ADD** — 9th
`boutique`-mislabel-actually-**Recollect** (`rotorua.recollect.co.nz`), the 5th **TWO-ASSET** case **+ a
2nd vanity redirect** (→ `pakiaka.rotorualibrary.govt.nz`) → **reused `recollectOgImageMaster`** (no new
code, no deploy); harvested baseline is the small `-280` thumbnail, og-`downloadwiz` master **64/64 (100%)**,
**63/64 pixel-win, median 11.7×, up to 144× / 24 MP**, 0 stale/dead); **Victoria and Albert Museum 43
committed Group B ADD** — the V&A's own **IIIF** service (`framemark.vam.ac.uk`), new `vamIIIFLargest`
(`/full/max/`, id == harvested filename stem; pure URL build, no deploy); the harvested `media.vam.ac.uk`
legacy host is **404 for ~⅓ of records**, and IIIF is a **strict Pareto win** (12 win / 8 equal / **0 lose**,
median 10.6×, up to 2500px) that also **fixes the dead-media 404s**); **The University of Waikato Art
Collection 44 committed Group B ADD** — 5th `boutique`-mislabel-actually-**eHive** (account 8668), **reused
`ehiveIIIFLargest`** (no new code, no deploy); IIIF `/full/full` **not rights-gated** despite uniform "All
rights reserved" (35/35); survey of the image-bearing records = **28 win / 0 equal / 7 honest-smaller** (~20%
fake-upscaled `_l`), median **2.25×**, up to **40.6 MP**; **★ but 61.5% of the 540 records are null-image at
source** → hard-fail the pick (HTTP 400, pre-existing Lambda behaviour, identical for the baseline) → weight
set to the 0.001 floor); **Te Ahu Museum 45 committed Group B ADD** — a **new platform for the sweep**,
**Vernon Systems "Vernon Browser"** (`collection.teahumuseum.nz`, S3/CloudFront), **reused `stringSwap`**
(first registry use) for a pure path-segment swap `/records/images/large/` → `/records/images/xlarge/`;
`xlarge` (1200px ≈ 1.44 MP) is the largest **public** variant (originals 403-locked behind login), a strict
**1.56–2.25×** (median 2.25×) improvement, **100% available, 0 null-image, no honest-smaller fork**);
**Ngā Puhipuhi o Te Herenga Waka—VUW Art Collection 46 committed Group B ADD** — the **2nd Vernon Browser**
site (Te Pātaka Toi **Adam Art Gallery**, VUW; `universityartcollection.adamartgallery.nz`), NEW
reusable **`vernonBrowserLargest`** (HEAD-probe `xlarge`, fall back to `large`) because **~1.2% of records
have a `large` but no `xlarge`** (a blind swap would 403); strict 1.0–2.25× (median 2.25×), 1200px ceiling,
no honest-smaller fork); **Nelson Provincial Museum 47 committed Group B ADD** — the **3rd Vernon Browser**
site, by far the largest (**~198,770 records**), **reused `stringSwap`** (a 150-page uniform census found
0% missing-`xlarge`, unlike VUW); strict 1.0–2.25× (median **1.29×** — more modest than Te Ahu/VUW since
many masters are natively <800px), 0 honest-smaller fork, 4.7% pre-existing fully-stale records
(unaffected either way). **★ Platform-label correction (found during 47's investigation): this whole
platform is Vernon Systems' "Vernon Browser" (same vendor as eHive), not "CollectiveAccess / Pawtucket" as
45/46 were originally logged** — confirmed via a Wayback Machine snapshot showing `vernon-common.min.js`
and a "Vernon Browser" modal title; corrected retroactively across `URLProcessor.swift`
(`collectiveAccessLargest` renamed `vernonBrowserLargest`), `progress.json`, `recipes.md`, this README, and
the sweep memory — no behaviour changed, only the label. The per-collection sweep is **UNPAUSED — next is
order 48 (Puke Ariki).**
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
| 38 | Tasman Heritage | recollect (was `boutique`) | **committed Group B ADD** — **Recollect** `downloadwiz` (`tasman.recollect.co.nz`, footer "Recollect Limited", Tasman District Libraries), **not boutique**; was **NOT in the Lambda**. **Same TWO-ASSET shape as John Kinder 37** (thumb `downloadwiz` 404 0/80; node `og:image` → a DIFFERENT primary asset, og `downloadwiz` 200 **80/80 = 100%**) — **reused `recollectOgImageMaster`, no new strategy code** — **PLUS a Clutha-style vanity redirect** `tasman.recollect.co.nz` → `heritage.tasmanlibraries.govt.nz` (og:image + master both on the vanity host; the strategy's og-host logic targets it automatically). Pixel sample (32): **26 win (median 3.14×, max 15.44×/10 MP)**, 3 equal (small native), 3 honest-smaller (upscaled-fake `-600` → honest native); og widths up to **9803 px**. **★ Required a shared `fetchHTML` fix:** the vanity host 403s any non-browser-UA request, and Alamofire wasn't carrying the session UA across the cross-host redirect → the og:image scrape silently fell back; fixed by also sending the UA as a per-request header (carried onto the redirected request). Additive — Kinder ×2 regression-clean; Feilding's local `!880,1024` fallback is env-gated (no `JP2_CONVERTER_URL` locally), not from this change. Pure code change (no deploy). `swift build` 0; CollectionTester ×4 HTTP 200 (3 masters 2.4–4.0 MP + 1 `-max` fallback). `collectionWeights` 0.002 (provisional). See `logs/038-tasman-heritage.md` |
| 39 | Western Bay Community Archives | recollect (was `boutique`) | **committed Group B ADD** — **Recollect** `downloadwiz` (`westernbay.recollect.co.nz`, footer "Recollect Limited", Western Bay District Council), **not boutique**; was **NOT in the Lambda**. **Same TWO-ASSET shape as John Kinder 37 / Tasman 38** (harvested thumb asset id master-less — `downloadwiz/<aid>` 404, `display/<aid>-600`==`-max` ~1000 px; node `og:image` → a DIFFERENT primary asset, og `downloadwiz` 200 **29/29 = 100%** of live nodes) — **reused `recollectOgImageMaster`, no new strategy code**. **No vanity redirect** (nodes + master served directly on the recollect.co.nz host). Pixel sample (24): **24/24 win (median 11.72×, max 34.57×/~25 MP, min 2.74×)**; CollectionTester served up to **8411×6763 ≈ 57 MP**. **★ Newer Recollect generation** (also exposes `assets/pic/<nodeId>`, but the legacy `assets/display/<assetId>` scheme still resolves for ~97%). **★ ~3% stale harvested ids** — a past site migration renumbered nodes/assets and DigitalNZ never re-synced; those `nodes/view/<nid>` 302 to a `/pages/error404` page (no `og:image`) → graceful fallback to the harvested `url` (itself 404); additive (Group B) ⇒ not a regression. (Lesson: page-1-only sampling over-counted staleness at ~11% vs ~3% uniform.) Pure code change (no deploy). `swift build` 0; CollectionTester ×6 HTTP 200 (`downloadwiz` masters 9–57 MP). `collectionWeights` 0.002 (provisional). See `logs/039-western-bay-community-archives.md` |
| 40 | War Art Online | ndha (was `boutique`) | **committed Group B ADD** — **NDHA/Rosetta** (`ndhadeliver.natlib.govt.nz/NLNZStreamGate`), holding inst **Archives NZ** (landing `archives.govt.nz` Incapsula-WAF-walled → no alternate route); was **NOT in the Lambda**. **Same `NLNZStreamGate/get?dps_pid=IE<n>` shape as National Publicity Studios 03, but — unlike 03 — a TIFF `PRESERVATION_MASTER` DOES exist** (`NCWA_*.tif`, ~5000 px, 40–65 MB, anonymously streamable) via the same Rosetta METS path as TAPUHI 25 — **TIFF not JP2**, routed through the **now-generic JP2+TIFF converter** (Feilding 35); `ndhadeliver` already in `ALLOWED_HOSTS` ⇒ **pure Swift change, no AWS redeploy**. New `warArtConverter`/`resolveWarArtFLStreamURL`/`warArtMasterFLPID`. **★ The harvested baseline is BIMODAL and the Lambda can't decode images:** `NLNZStreamGate` returns a **900 px** access JPEG (~80%, older IE1204… batch), an **already ~5000 px** JPEG (~20%, newer IE257…/IE807… batches), or a **multi-page PDF** (~1–2%). No robust METS signal (`preservationType`=`DERIVATIVE_COPY` for both tiers; `techMD` width only on the master + unreliable), so the case split is decided from the access-JPEG `fileSizeBytes`: PDF→convert one TIFF page; access ≥700 KB→**passthrough native ~5000 px**; else→convert the master (≤110 MB cap, so the 1/30 **908 MB** outlier falls back to its full-res baseline). **User chose heuristic-passthrough (pure Swift)** over always-convert / converter-decides-redeploy; the 700 KB threshold is graceful at the fuzzy byte boundary (few-% may render 4000 px vs 5000 px; never broken). Surveys: 30-rec master **30/30**; 100-rec baseline **Case1 80% / Case2 20% / Case3 ~1–2%**; ~80% get **~20× area**. `swift build` 0; CollectionTester ×8 (7 converter + 1 passthrough, all HTTP 200); LIVE converter up to **12.7 MP (4000×3173)** in 5.7–7.3 s; passthrough record native **5000×4745 (23.7 MP)**. `collectionWeights` 0.002 (provisional). See `logs/040-war-art-online.md` |
| 41 | Far North District Libraries Rediscovery | recollect (was `boutique`) | **committed Group B ADD** — **8th `boutique`-mislabel-actually-Recollect** (`fndclibraries.recollect.co.nz`, the classic `downloadwiz` generation, Far North District Libraries, CC BY-NC/BY-NC-ND); was **NOT in the Lambda**. **The 4th NAM-style TWO-ASSET case** (cf. John Kinder 37 / Tasman 38 / Western Bay 39): the harvested thumb id is mostly master-less (`downloadwiz/<thumbId>` 200 only **31/105 ~30%**, `display/<thumbId>-600`==`-max`==`-4000` ~1000 px), while the node `og:image` points to the master-bearing primary asset (og id == thumb id for ~30%, **differs for 77/105 ~73%**, usually `+1`/small offset) whose `downloadwiz` master IS present — so **REUSED `recollectOgImageMaster`, no new strategy code, no `recollectDomainMap` entry** (the helper uses the og:image's own host), **no vanity redirect, no AWS deploy**. Uniform survey (60 recs): og present **60/60**, og-`downloadwiz` 200 = **59/60 (98%)**; pixel **58 win / 1 equal / 0 honest-smaller**, ratio **min 1.0 median 23.4× max 57.6×** (up to 7590×5042 ≈ **38 MP** from a ~1000 px baseline). **★ UA-gate red herring:** every `assets/…` URL **403s without a browser UA**, and the og:image's `display/<id>-max?u=<32-hex>` `?u=` looks like a signed token but is a **cache-buster** (works with/without) — the real gate is the User-Agent (cf. Tasman 38), which `fetchHTML`/`headStatusFollowingRedirects` both send; the master is served directly (no cross-host redirect). **~1.7% stale nodes** (no real `og:image` — the page serves the site logo) → graceful fallback to the harvested `-600`; additive (Group B), not a regression. Master = `application/octet-stream` + `Content-Disposition: attachment` + `nosniff`, **byte-identical to the approved Clutha 36 / Hastings 6 masters** (renders in `<img>`). `swift build` 0; CollectionTester ×6 HTTP 200 `downloadwiz` masters (18.3 / 0.9 / 29.5 / 21.4 / 25.0 / 28.5 MP). `collectionWeights` 0.002 (provisional). See `logs/041-far-north-district-libraries-rediscovery.md` |
| 42 | Pakiaka Rotorua Heritage Online | recollect (was `boutique`) | **committed Group B ADD** — **9th `boutique`-mislabel-actually-Recollect** (`rotorua.recollect.co.nz`, classic `downloadwiz`, Rotorua Library — Te Aka Mauri); was **NOT in the Lambda**. **The 5th NAM-style TWO-ASSET case AND the 2nd with a Clutha/Tasman-style vanity redirect** `rotorua.recollect.co.nz` → **`pakiaka.rotorualibrary.govt.nz`** — so **REUSED `recollectOgImageMaster`, no new strategy code, no `recollectDomainMap` entry** (the helper builds the master URL from the og:image's own host = the vanity host → a **direct** probe, no cross-host redirect), **no AWS deploy**. The harvested `large_thumbnail_url` is the **small `-280` thumbnail** (≈500 px, 0.17 MP); the display pyramid extends **past 1000 px** (`-280` 499×333, `-600` 999×667, `-max` 1845×1232). The node `og:image` points to the master-bearing primary asset on the vanity host (og id differs from thumb id for **50/64 ~78%**), and `downloadwiz/<ogId>` is **≥ `-max` for every record** (a true larger master for ~40%, up to **6000×4000 = 24 MP**; == `-max` for ~60%). Uniform survey (64 recs across 16 pages): og present **64/64**, og-`downloadwiz` 200 = **64/64 (100%)**, **0 stale/dead, 0 login-walls**; pixel **63 win / 1 equal / 0 honest-smaller**, ratio **min 1.0 median 11.7× max 144×**. **★ UA-gate** (403 without a browser UA; the og:image's `?u=<32-hex>` is a cache-buster, not a signed token) **behind a cross-host vanity redirect** is exactly why `recollectLargest` is wrong (rips the master-less thumb id — `downloadwiz/<thumbId>` 404 for the two-asset ~78%, verified — and its probe would cross-host-redirect through the UA-gate), while `recollectOgImageMaster`'s direct-to-vanity probe works (64/64). Master = `application/octet-stream` + `attachment` + `nosniff`, byte-identical to approved Clutha 36 / Hastings 6 / Far North 41 (renders in `<img>`). Live `result_count` **1,571** (rawItemCount snapshot was 1,374 — collection grew; updated). `swift build` 0; CollectionTester ×6 HTTP 200 `downloadwiz` masters (0.6 / 2.2 / 9.1 / 1.1 / 10.8 / 24.0 MP). `collectionWeights` 0.002 (provisional). See `logs/042-pakiaka-rotorua-heritage-online.md` |
| 43 | Victoria and Albert Museum | iiif (was `boutique`) | **committed Group B ADD** — the **V&A's own IIIF Image API** (`framemark.vam.ac.uk`, London); was **NOT in the Lambda**. **First non-NZ, non-CONTENTdm pure-IIIF ADD.** The harvested `large_thumbnail_url` is the V&A **legacy image host** `media.vam.ac.uk/.../collection_images/<batch>/<id>.jpg` — ~640–768 px where present, **HTTP 404 for ~⅓ of records** (host being retired). The IIIF service serves the same asset keyed by the **SAME `<id>` == the harvested filename stem** (confirmed via the V&A object API `meta.images._iiif_image`), so the IIIF URL is derivable **purely from the filename** — new **`vamIIIFLargest`** emits `framemark.vam.ac.uk/collections/<id>/full/max/0/default.jpg` (pure URL build, **no request-time fetch, no AWS deploy**). **★ Strict Pareto improvement** (head-to-head, 30 recs): IIIF `/full/max/` vs the harvested media image = **win 12 / equal 8 / lose 0** (median **10.6×**, max 17.2×), AND it **fixes the ~⅓ dead-media 404s** (framemark resolves 100%). Bimodal: ~half have a high-res master → **2500 px (4.2–4.9 MP)**, ~half are genuinely low-res → IIIF returns honest native ~640–768 px (== old media, no regression). **★ 2500 px is the hard public ceiling** (info.json `maxWidth`/`maxHeight` = 2500; profile supports `sizeAboveFull`, so `/full/max/` is used — never a fixed width — to avoid fake-upscaling the small-native records; verified a `/full/4000,` request clamps to 2500; manifest exposes nothing larger; rights "© V&A"). framemark needs **no browser UA**. Live `result_count` **564** (rawItemCount snapshot 549). `swift build` 0; CollectionTester ×6 HTTP 200 `image/jpeg` (768×576 ×3 low-res + 1797×2500 / 2500×1875 / 1676×2500 high-res). `collectionWeights` 0.001 (provisional). See `logs/043-victoria-and-albert-museum.md` |
| 44 | The University of Waikato Art Collection | ehive (was `boutique`) | **committed Group B ADD** — **5th `boutique`-mislabel-actually-eHive** (account **8668**; landing `ehive.com/collections/8668/objects/<id>` wires up **OpenSeadragon** over `iiif.ehive.com`); was **NOT in the Lambda**. **REUSED `ehiveIIIFLargest`, no new strategy code, no AWS deploy** — builds `iiif.ehive.com/iiif/2/accounts%2f8668%2fobjects%2fimages%2f<id>.tif/full/full/0/default.jpg` from the harvested 800 px `_l` URL. **★ The IIIF `/full/full` is NOT rights-gated** despite uniform `rights: "All rights reserved"` (license null) — **35/35** served 200 `image/jpeg` (we serve exactly what the University publishes through its own public viewer). Uniform 78-record survey (35 image-bearing): native vs `_l` = **28 win / 0 equal / 7 honest-smaller** (~20% — eHive fake-upscaled the `_l` from a smaller real master → IIIF returns the **honest** smaller native, per the established eHive honest-native-always policy; cf. Howick 17), area ratio **min 0.200 / median 2.25× / max 95.2×**, biggest native **7803×5202 ≈ 40.6 MP**. **★ But 61.5% of the 540 records are null-image at source** (`large_thumbnail_url` null; per-page empty rate 16% p1 → 86% p3/p5) → those picks **hard-fail to HTTP 400** via `checkHasTitleAndLargeImage` (no retry loop) — **pre-existing Lambda behaviour, identical for the baseline**; the global DigitalNZ `category=Images` query is **not** changed (out of scope). `swift build` 0; CollectionTester 16 picks → **5 image successes / 11 null-image 400s** (Black Puriri 886×1200, Plain Song Elegy 807×1200, Te Whiti poster 848×1200, Stoneware jar 1200×922 = wins 2.25×; Back to the Future 8 512×768 & 8 of Wands 547×657 = honest-smaller), all HTTP 200 `image/jpeg`. `collectionWeights` **0.001** (floor — reflects the 61.5% null-image rate). See `logs/044-the-university-of-waikato-art-collection.md` |
| 45 | Te Ahu Museum | vernonBrowser (was `boutique`) | **committed Group B ADD** — a **new platform for the sweep**: **Vernon Systems "Vernon Browser"** (the museum's own CMS at `collection.teahumuseum.nz`, images on **AmazonS3** behind CloudFront), **not** eHive/Recollect; was **NOT in the Lambda**. **REUSED `stringSwap` (first registry use), no new strategy code, no AWS deploy** — pure path-segment swap `/records/images/large/` → `/records/images/xlarge/`. **★ `xlarge` (1200 px long side ≈ 1.44 MP) is the largest PUBLIC media version** — `original`/`fullsize`/`full`/`huge`/`tilepic`/`xxlarge`/`master`/… all **403** (Vernon Browser gates originals behind login). Size ladder: small 123×150 / medium 328×400 / **large 657×800 (harvested)** / **xlarge 985×1200**. `xlarge` targets 1200 px vs `large`'s 800 px, both capped at the master (no upscale), so **`xlarge` ≥ `large` always and never exceeds the master → no honest-smaller fork**. **Null-image census all 506 records = 0 (0.0%)** (the exact opposite of Waikato 44). Uniform 64-record survey: `xlarge` **63 win / 0 equal / 0 smaller / 0 missing**, area ratio **min 1.562 / median 2.250 / max 2.254**, biggest 1200×1199 ≈ 1.44 MP; **1/64 (~1.6%) had a `large` that itself 403'd** (pre-broken baseline at source — the swap is no worse; additive ⇒ not a regression). Landing page is **bot-walled** (CloudFront HTTP 202 ~2 KB challenge) but irrelevant — the `/records/images/` CDN isn't, and the swap needs no page fetch. `swift build` 0; CollectionTester ×6 → **6/6 HTTP 200** `xlarge` (Ahipara 1200×905 / Greenstone Pendant 1200×494 / Awanui 1200×906 / Cigarette Holder 850×1200 / Far North 1200×856 / Peria 1200×892, each exactly 1.5×/side = 2.25× area). `collectionWeights` **0.002** (provisional). See `logs/045-te-ahu-museum.md` |
| 46 | Ngā Puhipuhi o Te Herenga Waka—VUW Art Collection | vernonBrowser (was `boutique`) | **committed Group B ADD** — the **2nd Vernon Systems "Vernon Browser"** site of the sweep (after Te Ahu 45): Te Pātaka Toi **Adam Art Gallery** (VUW university art collection, `universityartcollection.adamartgallery.nz`, images on **AmazonS3** behind CloudFront); was **NOT in the Lambda**. **NEW reusable `vernonBrowserLargest` (async HEAD-probe + fallback), no AWS deploy** — swap `/records/images/large/` → `/records/images/xlarge/`, **HEAD-probe the `xlarge` and fall back to the harvested `large` when it is absent**. **★ Why a probe, not Te Ahu's pure `stringSwap`:** a full HEAD scan of all 486 image-bearing records found **6 (1.2%) with a `large` (200) but NO `xlarge` (403)** — a blind swap would serve a broken 403; the HEAD is reliable (**HEAD == GET for all 486**, 0 mismatches). Same ladder as Te Ahu: small 150×117 / medium 400×313 / **large 800×626 (harvested)** / **xlarge 1200×939**; `original`/`fullsize`/etc. all **403** (login-gated) → **`xlarge` ≈ 1.42 MP is the public ceiling**. `xlarge` is master-capped (never upscaled) → **no honest-smaller fork**. Uniform 61-record survey: `xlarge` **46 win / 13 equal / 0 smaller / 2 missing**, area ratio **min 1.000 / median 2.249 / max 2.253**. Null-image census all 488 = **2 (0.4%)** → HTTP 400 hard-fail (pre-existing, negligible). `swift build` 0; CollectionTester ×6 → **6/6 HTTP 200** `xlarge` (The Single Cloud 606×1200 / Continuum VII 1200×493 / Light Installation 1200×830 / Untitled 1200×778 / Untitled (Puvis) 728×944 / Exotic Plant 812×1200); **fallback verified** (record 50811364 `xlarge` 403 → served `large` 800×648 200). `collectionWeights` **0.002** (provisional). See `logs/046-nga-puhipuhi-o-te-herenga-waka-victoria-university-of-wellington-art-collection.md` |
| 47 | Nelson Provincial Museum | vernonBrowser (was `boutique`) | **committed Group B ADD** — the **3rd Vernon Systems "Vernon Browser"** site of the sweep (after Te Ahu 45 / VUW 46), by far the largest (`collection.nelsonmuseum.co.nz`, **~198,770** image-bearing records); was **NOT in the Lambda**. **This investigation uncovered the platform-label correction: the whole platform is Vernon Systems' "Vernon Browser" (same vendor as eHive), not "CollectiveAccess / Pawtucket" as 45/46 were originally logged** — confirmed via a Wayback Machine snapshot of the homepage showing `vernon-common.min.js` and a "Vernon Browser" modal title; corrected retroactively (no behaviour change to 45/46, only the label + the `collectiveAccessLargest`→`vernonBrowserLargest` rename). **REUSED `stringSwap` (same as Te Ahu 45), no new code, no AWS deploy** — pure path-segment swap `/records/images/large/` → `/records/images/xlarge/`. A **150-page uniform HEAD census** (spanning the full ~9,939-page range) found **0% null-image** and, critically, **0/143 "large 200 but xlarge missing"** cases (unlike VUW's 1.2%), so the plain unconditional swap is justified — no HEAD-probe needed. **7/150 (4.7%) of records are fully stale at the source** (ALL size tiers 403, confirmed on retry) — pre-existing dead assets, unaffected by the swap either way. 40-record pixel survey: `xlarge` **24 win / 13 equal / 0 smaller**, area ratio **min 1.000 / median 1.288 / max 2.251** — more modest than Te Ahu/VUW's 2.25× median since many Nelson masters (glass-plate portrait negatives) are natively narrower than the 800 px `large` box. **★★ Exhaustively confirmed `xlarge` is the true public ceiling** (per explicit user request to verify harder): tried 13 alternate derivative-name guesses (`original`/`fullsize`/`full`/`tilepic`/`xxlarge`/`master`/`preview`/`raw`/`print_preview`/`crop`/`display`/`thumbnail` + case variants, all 403); confirmed query-param resize tricks are ignored by CloudFront (byte-identical); found and inspected the real Vernon Browser vendor API (`apidocs.browser.vernonsystems.com`, `ImageDerivative` schema, requires an API key we don't have); researched Vernon Systems docs (IIIF only documented for eHive); inspected a Feb-2024 Wayback Machine snapshot of a live object page (plain `<img>` tags, no OpenSeadragon/IIIF/DZI/zoomify viewer); EXIF on a served `xlarge` confirms the true source photo is far higher-res (12 MP Olympus TG-6) but deliberately not published (S3 `AccessDenied`, not a WAF artifact). `swift build` 0; CollectionTester ×6 → **6/6 HTTP 200** `xlarge`; 5/6 measured gains (1.11×–2.25× area), 1/6 already native (1.0×, no loss). `collectionWeights` **0.002**. See `logs/047-nelson-provincial-museum.md` |

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

**✅ Order 38 (Tasman Heritage) committed Group B ADD (2026-06-14).** A 6th `boutique` mislabel — **Recollect**
`downloadwiz` (`tasman.recollect.co.nz`, footer "Recollect Limited", Tasman District Libraries). **Was NOT in
the Lambda.** **The same NAM-style TWO-ASSET pattern as John Kinder 37** (the harvested `large_thumbnail` id is
a master-less display derivative — `downloadwiz/<thumbId>` 404, `display/<thumbId>-600`==`-max`==`-4000`
~1000 px — while the node `og:image` points to a DIFFERENT primary asset whose `downloadwiz` master IS present),
**so it REUSED `recollectOgImageMaster` — no new strategy code, just a registry entry + weight.** Uniform 80-rec
survey: thumb-`downloadwiz` 200 = **0/80**, og id differs = **80/80**, og-`downloadwiz` 200 = **80/80 (100%)**,
all on the vanity host, all masters real JPEGs, 0 login-walls. Pixel sample (32): **26 win** (median **3.14×**,
max **15.44×**/10 MP), 3 equal (small native), 3 honest-smaller (upscaled-fake `-600` → honest native); og
widths up to **9803 px**. **★ Two extra twists vs Kinder:** (1) a **Clutha-style vanity redirect**
`tasman.recollect.co.nz` → **`heritage.tasmanlibraries.govt.nz`** (the og:image + master both live on the vanity
host; `recollectOgImageMaster` uses the og:image's own host so it targets the vanity domain automatically); and
(2) it **required a shared `fetchHTML` fix** — the vanity host **403s any request lacking a browser UA**, and
Alamofire/URLSession does **not** reliably reapply the session `httpAdditionalHeaders` UA to the **redirected**
request on a **cross-host** 301/302, so `fetchHTML` got the 403 error page (no `og:image`) and the scrape
silently fell back. Fixed by **also sending the UA as a per-request header** (which URLSession copies onto the
redirected request); additive/strictly-improving (Kinder ×2 regression-clean; Feilding's local `!880,1024`
fallback is purely because `JP2_CONVERTER_URL` is unset in the **local** env — `feildingConverter` guards on it
before `fetchHTML` — not from this change). (Also re-hit the **stale `:7000`** trap, which masked the fix until
cleared — the bundled `killProcessOnPort` calls `/usr/bin/lsof`, which doesn't exist here; `lsof` is at
`/usr/sbin/lsof`.) `collectionWeights` **0.002** (provisional). Pure code change (no AWS deploy). `swift build` 0;
CollectionTester ×4 HTTP 200 (3 `downloadwiz` masters 2.4–4.0 MP + 1 `-max` fallback). See
`logs/038-tasman-heritage.md`.

**✅ Order 39 (Western Bay Community Archives) committed Group B ADD (2026-06-14).** A 7th `boutique` mislabel —
**Recollect** `downloadwiz` (`westernbay.recollect.co.nz`, footer "Recollect Limited", Western Bay District
Council). **Was NOT in the Lambda.** **The same NAM-style TWO-ASSET pattern as John Kinder 37 / Tasman 38** (the
harvested `large_thumbnail` asset id is a master-less display derivative — `downloadwiz/<aid>` 404,
`display/<aid>-600`==`-max` ~1000 px — while the node `og:image` points to a DIFFERENT primary asset whose
`downloadwiz` master IS present), **so it REUSED `recollectOgImageMaster` — no new strategy code, just a registry
entry + weight.** **No vanity redirect** (nodes + master served directly on `westernbay.recollect.co.nz`). Uniform
30-rec survey: live nodes **29/30 (97%)**, og-`downloadwiz` 200 = **29/29 (100%)** of live nodes; pixel sample
(24): **24/24 win** (median **11.72×**, max **34.57×**/~25 MP, min 2.74×); CollectionTester served up to
**8411×6763 ≈ 57 MP**. **★ Two notes:** (1) a **newer Recollect generation** — the site also exposes
`assets/pic/<nodeId>`, but the legacy `assets/display/<assetId>` scheme still resolves for ~97%, so the two-asset
strategy applies unchanged; (2) **~3% of harvested ids are stale** — a past site migration renumbered nodes/assets
and DigitalNZ never re-synced those records, so `nodes/view/<nid>` 302s to a `/pages/error404` page (no `og:image`)
and `recollectOgImageMaster` cleanly falls back to the harvested `url` (itself 404). Additive (Group B) ⇒ not a
regression. (Lesson: don't trust a page-1-only sample for the stale fraction — it read ~11% on page 1 but ~3%
uniformly.) `collectionWeights` **0.002** (provisional). Pure code change (no AWS deploy). `swift build` 0;
CollectionTester ×6 HTTP 200 (`downloadwiz` masters 9–57 MP). See `logs/039-western-bay-community-archives.md`.

**✅ Order 40 (War Art Online) committed Group B ADD (2026-06-14).** Archives NZ's National Collection of War
Art (WWI/WWII paintings & drawings) — platform identified (was `boutique`): **NDHA / National Library Rosetta**
(`ndhadeliver.natlib.govt.nz/NLNZStreamGate/get?dps_pid=IE<n>`), the **same delivery shape as National Publicity
Studios 03 and TAPUHI 25**; holding institution **Archives NZ** (landing `archives.govt.nz` is
**Incapsula/Imperva-WAF-walled** → a 212-byte JS-challenge stub, no alternate route). **Was NOT in the Lambda**
(no `collectionWeights` → never served). **★ Unlike National Publicity Studios 03 (which had only an access rep),
War Art DOES have a TIFF `PRESERVATION_MASTER`** — the Rosetta METS (`…&dps_func=mets`) lists an `image/tiff` FL
(`NCWA_*.tif`, 8-bit RGB, **~5000 px, 40–65 MB**) whose `…&dps_func=stream` serves the TIFF **anonymously**
(HTTP 200, direct 200, no S3 redirect). It's reached by the **same METS path as TAPUHI 25** but is **TIFF not JP2**,
so it's routed through the **now-generic JP2+TIFF Pillow converter** (generalised at Feilding 35); since
`ndhadeliver.natlib.govt.nz` was already in the deployed converter's `ALLOWED_HOSTS` (from TAPUHI), this is a
**pure Swift change — NO converter change, NO AWS redeploy** (new `warArtConverter` → `resolveWarArtFLStreamURL`
(IE→METS) → `warArtMasterFLPID` → `<JP2_CONVERTER_URL>/?url=<encoded FL stream>`; TIFF needs no reduced-level
trick, decodes in 5–7 s live). **★ The one wrinkle — a BIMODAL baseline the Lambda can't pixel-measure:**
`NLNZStreamGate/get` returns either a **900 px** access JPEG (**~80 %**, older IE1204… batch), an **already
~5000 px** full-res JPEG (**~20 %**, newer IE257…/IE807… batches), or a **multi-page `combinedPDF.pdf`**
(**~1–2 %**, compilations — not `<img>`-displayable). The Swift Lambda has **no image decoder** (the converter's
whole reason to exist) and **there is no robust METS signal** (`preservationType`=`DERIVATIVE_COPY` for **both**
the 900 px and 5000 px access tiers; `techMD tiff:ImageWidth` exists only on the master and is unreliable), so the
case split is decided from the **access JPEG's `fileSizeBytes`** (== the served byte length): a PDF → convert the
largest TIFF page; access ≥ **700 KB** → **passthrough the native ~5000 px baseline** (the converter's 4000 px
ceiling would only shrink it); else → convert the master. The picker caps at the converter's **110 MB** download
limit, so the **1/30 outlier 908 MB master** is rejected → falls back to its already-full-res 6039 px baseline.
**User chose "heuristic passthrough (pure Swift)"** over always-convert (would shrink the 20 % to 4000 px) and over
a converter-decides AWS redeploy; the 700 KB threshold is **graceful at the fuzzy byte boundary** (the **pixel**
gap 1452 ↔ 4347 px is clean, the **byte** gap isn't, so a few-% of records may render at 4000 px instead of native
~5000 px — never broken). **Lesson: an NDHA collection can serve full-res access JPEGs for some digitisation
batches and 900 px for others — parse the METS (don't conclude "no master" from the NLNZStreamGate shape, cf. 03)
AND measure the baseline distribution.** Surveys: 30-rec master **30/30 (100 %)**; 100-rec baseline **Case1 80 % /
Case2 20 % / Case3 ~1–2 %**; ~80 % get **~20× area**. `swift build` 0; CollectionTester ×8 (**7 converter +
1 passthrough, all HTTP 200**); LIVE deployed converter up to **12.7 MP (4000×3173)** in 5.7–7.3 s; passthrough
record native **5000×4745 (23.7 MP)**. `collectionWeights` **0.002** (provisional). See `logs/040-war-art-online.md`.

**✅ Order 41 (Far North District Libraries Rediscovery) committed Group B ADD (2026-06-16).** The **8th
`boutique`-mislabel-actually-Recollect** (`fndclibraries.recollect.co.nz`, the classic `downloadwiz`
generation, Far North District Libraries, CC BY-NC/BY-NC-ND) and the **4th NAM-style TWO-ASSET case**, so
it **REUSED `recollectOgImageMaster`** — registry entry + `collectionWeights` **0.002** only, **no new
strategy code, no `recollectDomainMap` entry** (the helper builds the master URL from the `og:image`'s own
host), **no vanity redirect, no AWS deploy.** Was **NOT in the Lambda** (no weight → never served). The
harvested thumb id is mostly master-less (`downloadwiz/<thumbId>` 200 only **31/105 ~30%**;
`display/<thumbId>-600`==`-max`==`-4000` byte-identical ~1000 px), while the node `og:image` points to the
master-bearing primary asset — id **== thumb id for ~30%**, **differs for 77/105 (~73%)** (usually `+1` or a
small offset). Uniform survey 2 (60 records across all 15 pages): `og:image` present **60/60**,
og-`downloadwiz` 200 = **59/60 (98%)**; pixel **58 win / 1 equal / 0 honest-smaller**, area ratio **min 1.0,
median 23.4×, max 57.6×** (up to 7590×5042 ≈ **38 MP** from a ~1000 px baseline). **★ A UA-gate red herring:**
every `assets/…` URL **403s without a browser User-Agent** (118-byte stub), and the node `og:image` is
`display/<id>-max?u=<32-hex>` — the `?u=` *looks* like a per-asset signed token (cf. the Feilding-35
path-bound CloudFront signature) but is just a **cache-buster** (works with or without it); the real gate is
purely the **User-Agent** (same as Tasman 38). `NetworkRequestManager.fetchHTML` and
`headStatusFollowingRedirects` **both already send a browser UA**, and the master is served **directly** (no
cross-host redirect), so the session-level UA suffices and the helper works unchanged. **~1.7% of nodes are
stale** (no real `og:image` — the page returns the site logo `theme/.../logo.mobile.png`) →
`recollectOgImageMaster`'s `slice(from: "display/", to: "-")` returns nil → **graceful fallback to the
harvested `-600`** (still a valid ~1000 px image); additive (Group B), so not a regression (cf. Western
Bay 39's ~3%). The `downloadwiz` master is `application/octet-stream` + `Content-Disposition: attachment` +
`X-Content-Type-Options: nosniff` — **byte-identical to the already-approved Clutha 36 / Hastings 6
masters** (renders in `<img>`; direct navigation downloads the `.jpg`); the `nosniff` is standard Recollect,
not anomalous. `swift build` 0; CollectionTester ×6 → **6/6 HTTP 200** `downloadwiz` masters (decoded
**18.3 / 0.9 / 29.5 / 21.4 / 25.0 / 28.5 MP**, five large + one honest small native 793×1098). **Lesson: a
Recollect `?u=` query on the `og:image` is a cache-buster, not a path-bound signature — probe with vs without
a browser UA before assuming a token is required.** See `logs/041-far-north-district-libraries-rediscovery.md`.

**✅ Order 42 (Pakiaka Rotorua Heritage Online) committed Group B ADD (2026-06-16).** The **9th
`boutique`-mislabel-actually-Recollect** (`rotorua.recollect.co.nz`, classic `downloadwiz`, Rotorua
Library — Te Aka Mauri), the **5th NAM-style TWO-ASSET case**, and the **2nd with a Clutha/Tasman-style
vanity redirect** `rotorua.recollect.co.nz` → **`pakiaka.rotorualibrary.govt.nz`** — so it **REUSED
`recollectOgImageMaster`** (registry entry + `collectionWeights` **0.002** only; **no new strategy code, no
`recollectDomainMap` entry, no AWS deploy**). Was **NOT in the Lambda** (no weight → never served). The
harvested `large_thumbnail_url` is the **small `-280` thumbnail** (≈500 px, 0.17 MP) — and the Recollect
display pyramid here extends **past 1000 px** (`-280` 499×333, `-600` 999×667, `-max` 1845×1232), unlike Far
North 41 where `-600`==`-max`. The node `og:image` points to the master-bearing primary asset **on the
vanity host** (og id == thumb id for 14/64, **differs for 50/64 ~78%**); `downloadwiz/<ogId>` 200 = **64/64
(100%)** and is **≥ `-max` for every record** — a **true larger master for ~40%** (26/64, up to 6000×4000 =
**24 MP**) and **== `-max` for ~60%** (38/64; small originals). Uniform survey (64 records across all 16
pages): pixel (chosen vs the `-280` baseline) **63 win / 1 equal / 0 honest-smaller**, ratio **min 1.0,
median 11.66×, max 144.14×**; **0 stale/dead, 0 login-walls** (cleaner than Far North's 1.7% / Western Bay's
3%). **★ Why `recollectOgImageMaster`, not `recollectLargest`:** the assets are **UA-gated** (403 without a
browser UA; the og:image's `?u=<32-hex>` is a cache-buster, not a signed token — cf. Far North 41) **behind
a cross-host vanity redirect**, and the harvested thumb id is **master-less for the two-asset ~78%**
(`downloadwiz/<thumbId>` 404, verified thumb 11610→404 vs og 12166→200). `recollectOgImageMaster` builds the
master URL from the og:image's **own (vanity) host**, so the `downloadwiz` HEAD probe is a **direct** request
(no cross-host redirect) and the session UA applies (verified 64/64); `recollectLargest` would both rip the
wrong id and have to follow the redirect through the UA-gate. Master = `application/octet-stream` +
`Content-Disposition: attachment` + `nosniff`, byte-identical to the approved Clutha 36 / Hastings 6 / Far
North 41 masters (renders in `<img>`). Live `result_count` **1,571** (the rawItemCount snapshot was 1,374 —
the collection grew; updated). `swift build` 0; CollectionTester ×6 → **6/6 HTTP 200** `downloadwiz` masters
on the vanity host (decoded **0.6 / 2.2 / 9.1 / 1.1 / 10.8 / 24.0 MP**). See
`logs/042-pakiaka-rotorua-heritage-online.md`.

**✅ Order 43 (Victoria and Albert Museum) committed Group B ADD (2026-06-16).** The first **non-NZ,
pure-IIIF** ADD of the sweep — the **V&A's own IIIF Image API** at `framemark.vam.ac.uk` (London). Was **NOT
in the Lambda** (no weight → never served). The harvested `large_thumbnail_url` is the V&A's **legacy image
host** `media.vam.ac.uk/media/thira/collection_images/<batch>/<id>.jpg`, which is being retired — it serves
only ~640–768 px where present and **404s for ~⅓ of records**. The IIIF service serves the same asset keyed
by the **SAME `<id>`** (the harvested filename stem == the V&A object API's `meta.images._iiif_image`
identifier), so the IIIF URL is derivable **purely from the harvested filename** — new **`vamIIIFLargest`**
emits `framemark.vam.ac.uk/collections/<id>/full/max/0/default.jpg` (pure URL construction, like Kura 16; **no
request-time fetch, no AWS deploy**; defensively strips a `_jpg_w` suffix; falls back to the harvested URL on
an unexpected shape). **★ Strict Pareto improvement** (head-to-head, 30 records): IIIF `/full/max/` vs the
harvested media image = **win 12 / equal 8 / lose 0** (area ratio min 1.0, median **10.6×**, max 17.2×), AND
it **fixes the ~⅓ dead-media 404s** (framemark resolves 100% — 36/36 info.json, 30/30 `/full/max/`). The
collection is **bimodal**: ~half have a high-res master → **2500 px (4.2–4.9 MP)**; ~half are genuinely
low-res masters → IIIF returns the honest native ~640–768 px (== the old media image, no regression). **★ 2500
px is the hard public ceiling** — info.json profile is IIIF 2 level1 with `maxWidth`/`maxHeight` = 2500 and
`supports: sizeAboveFull`, so a **fixed width would fake-upscale** the small-native records (the Kura 16
lesson); `/full/max/` returns honest native ≤ 2500 (verified: a 768-native record stays 768, and a
`/full/4000,` request **clamps to 2500**, byte-identical to `/full/max/`). The IIIF presentation manifest
(`iiif.vam.ac.uk/collections/O<n>/manifest.json`) exposes **nothing larger** than framemark, and rights are
"© V&A, London" (public delivery deliberately capped at 2500). `framemark` needs **no browser UA**. Live
`result_count` **564** (rawItemCount snapshot 549). `swift build` 0; CollectionTester ×6 → **6/6 HTTP 200
`image/jpeg`** framemark IIIF URLs (768×576 ×3 low-res masters; 1797×2500 / 2500×1875 / 1676×2500 high-res).
**Lesson: a museum's harvested image host can be a retired legacy CDN — check for its IIIF service
(`info.json`) keyed by the same asset id, which both enlarges and fixes the dead harvest.** See
`logs/043-victoria-and-albert-museum.md`.

**✅ Order 44 (The University of Waikato Art Collection) committed Group B ADD (2026-06-17).** The 5th
`boutique`-mislabel-actually-**eHive** (account **8668**; the landing pages `ehive.com/collections/8668/…`
wire up OpenSeadragon over `iiif.ehive.com`) — cf. Te Hikoi 31 / Te Toi Uku 32 / Te Ūaka 33 / Wyndham 34.
Was **NOT in the Lambda**. **REUSED `ehiveIIIFLargest`, no new strategy code, no AWS deploy** — the
account-agnostic helper builds `iiif.ehive.com/iiif/2/accounts%2f8668%2fobjects%2fimages%2f<id>.tif/full/full/0/default.jpg`
from the harvested 800 px `_l` URL. **★ The IIIF `/full/full` is NOT rights-gated** despite a uniform
`rights: "All rights reserved"` (license null): **35/35** image-bearing records served 200 `image/jpeg` (the
rights gate only affects the `_xl`/`_o` derivative suffixes) — we serve exactly the image the University
publishes through its own public viewer, at the native master. Uniform 78-record survey (35 image-bearing):
native vs the 800 px `_l` = **28 win / 0 equal / 7 honest-smaller** (~20% — eHive **fake-upscaled the `_l`**
to the 800 px box from a smaller real master, so the IIIF returns the **honest** smaller native; never
upscaled, `sizeAboveFull` is NOT in the profile `supports`; consistent with the user's eHive
honest-native-always policy, cf. Howick 17 / Te Ūaka 33), area ratio **min 0.200 / median 2.25× / max
95.2×**, biggest native **7803×5202 ≈ 40.6 MP**. **★ But 61.5% of the 540 records are null-image at source**
(`large_thumbnail_url` null; `thumbnail_url`/`object_url` also null — art-catalogue records with no published
image; per-page empty rate climbs 16% p1 → 86% p3/p5): those picks throw `nullImageOrTitle` in
`NZRecordsResult.checkHasTitleAndLargeImage()` → `NZImageApi.image()` returns nil → the handler returns
**HTTP 400** (there is no retry loop). This is **pre-existing Lambda behaviour, identical for the baseline**;
the global DigitalNZ `category=Images` query is **not** changed (a one-collection additive change must not
touch it). The low weight (**0.001**, the floor) reflects this. `swift build` 0; CollectionTester 16 picks →
**5 image successes / 11 null-image 400s** (Black Puriri 886×1200 / Plain Song Elegy 807×1200 / Te Whiti
poster 848×1200 / Stoneware jar 1200×922 = wins 2.25×; Back to the Future 8 512×768 & 8 of Wands 547×657 =
honest-smaller), all HTTP 200 `image/jpeg`. **Lesson: `category=Images` does NOT guarantee a published image
— census the null-`large_thumbnail_url` rate for any art/catalogue collection; a high rate means a
proportional HTTP 400 hard-fail rate (pre-existing) and argues for a floor weight.** See
`logs/044-the-university-of-waikato-art-collection.md`.

**✅ Order 45 (Te Ahu Museum) committed Group B ADD (2026-06-17).** A **new platform for the sweep** —
**Vernon Systems "Vernon Browser"** (the museum's own collection CMS at `collection.teahumuseum.nz`; images on
**AmazonS3** behind CloudFront), **not** eHive or Recollect. Was **NOT in the Lambda**. The harvested
`large_thumbnail_url` (`…/records/images/large/<NN>/<hash>.jpg`) is the 800 px **large** media version; the
**xlarge** version (1200 px long side ≈ 1.44 MP) is the **largest public** one — `original`/`fullsize`/`full`/
`huge`/`tilepic`/`xxlarge`/`master`/… all **403** (Vernon Browser gates originals behind login). **REUSED
`stringSwap` (its first registry use), no new strategy code, no AWS deploy** — pure path-segment swap
`/records/images/large/` → `/records/images/xlarge/`. `xlarge` targets 1200 px vs `large`'s 800 px and both are
**capped at the master** (Vernon Browser does not upscale), so **`xlarge` ≥ `large` always and never exceeds
the master → no fake-upscale / honest-smaller fork** (unlike eHive's `_l`). **Null-image census all 506 records
= 0 (0.0%)** — the exact opposite of Waikato 44. Uniform 64-record survey: `xlarge` **63 win / 0 equal / 0
smaller / 0 missing**, area ratio **min 1.562 / median 2.250 / max 2.254**; **1/64 (~1.6%) had a `large` that
itself 403'd** (pre-broken at source; the swap is no worse; additive ⇒ not a regression). The landing page is
bot-walled (CloudFront HTTP 202 challenge) but irrelevant — the `/records/images/` CDN is not, and the swap
needs no page fetch. `swift build` 0; CollectionTester ×6 → 6/6 HTTP 200 `xlarge`, each 2.25× area over
`large`. **Lesson: for a self-hosted Vernon Systems "Vernon Browser" site, the harvested `…/images/large/…` is one
of a named media-version ladder — probe `xlarge` (and only that is public; `original` is login-gated) and swap
the path segment; no upscale risk because the versions are master-capped.** See `logs/045-te-ahu-museum.md`.

**✅ Order 46 (Ngā Puhipuhi o Te Herenga Waka—Victoria University of Wellington Art Collection) committed
Group B ADD (2026-06-18).** The **2nd Vernon Systems "Vernon Browser"** site (after Te Ahu 45) — Te Pātaka Toi
**Adam Art Gallery** (VUW's university art collection, `universityartcollection.adamartgallery.nz`, images on
**AmazonS3** behind CloudFront). Was **NOT in the Lambda**. Same media-version ladder as Te Ahu (small/medium/
**large 800**/**xlarge 1200**; `original`/etc. **403** login-gated → `xlarge` ≈ 1.42 MP is the public
ceiling). **NEW reusable `vernonBrowserLargest` (async), no AWS deploy** — swaps `large` → `xlarge` but
**HEAD-probes the `xlarge` and falls back to the harvested `large`** when it's absent. **★ Why a probe and not
Te Ahu's pure `stringSwap`:** a full HEAD scan of all 486 image-bearing records found **6 (1.2%) with a
`large` (200) but NO generated `xlarge` (403)** — a blind swap would serve a broken 403 for those. The HEAD
probe is reliable here: **HEAD == GET for all 486 records** (0 mismatches; the 6 missing show `large`
HEAD=200/GET=200, `xlarge` HEAD=403/GET=403). `xlarge` is master-capped (never upscaled) → **no honest-smaller
fork**. Uniform 61-record survey: `xlarge` **46 win / 13 equal / 0 smaller / 2 missing**, area ratio **min
1.000 / median 2.249 / max 2.253**. Null-image census all 488 = **2 (0.4%)** → HTTP 400 hard-fail (pre-existing,
negligible). `swift build` 0; CollectionTester ×6 → 6/6 HTTP 200 `xlarge`; fallback verified (record 50811364
`xlarge` 403 → served `large` 200). Te Ahu 45's cheaper synchronous `stringSwap` is left unchanged (0% missing
there). **Lesson: Vernon Browser `xlarge` availability is per-site — full-scan the missing-`xlarge` rate; if
>0, use the HEAD-probe `vernonBrowserLargest` (HEAD == GET on this CDN) rather than a blind `stringSwap`.**
See `logs/046-nga-puhipuhi-o-te-herenga-waka-victoria-university-of-wellington-art-collection.md`.

**✅ Order 47 (Nelson Provincial Museum) committed Group B ADD (2026-07-04).** The **3rd Vernon Systems
"Vernon Browser"** site (after Te Ahu 45 / VUW 46), by far the largest —
`collection.nelsonmuseum.co.nz`, **~198,770** image-bearing records vs the ~500-record boutique sites.
Was **NOT in the Lambda**. **This investigation is what uncovered the platform-label correction** (see
below): a Wayback Machine snapshot of the homepage showed `vernon-common.min.js` and a "Vernon Browser"
modal title, proving the platform is **Vernon Systems' "Vernon Browser"**, not "CollectiveAccess /
Pawtucket" as 45/46 were originally logged (same vendor as eHive; corrected retroactively, no behaviour
change). **REUSED `stringSwap`** (same as Te Ahu 45) — pure path-segment swap
`/records/images/large/` → `/records/images/xlarge/`, no new code, no deploy. A **150-page uniform HEAD
census** (spanning the collection's full ~9,939-page range) found **0% null-image** and **0/143 "large
200 but xlarge missing"** cases (unlike VUW's 1.2%), so the plain unconditional swap is justified — no
HEAD-probe needed. **7/150 (4.7%) fully stale at source** (ALL size tiers 403 on retry) — pre-existing,
unaffected by the swap either way. 40-record pixel survey: `xlarge` **24 win / 13 equal / 0 smaller**,
area ratio **min 1.000 / median 1.288 / max 2.251** — more modest than Te Ahu/VUW's 2.25× median since
many Nelson masters (glass-plate portrait negatives) are natively narrower than the 800 px `large` box.
**★★ The user pushed back and asked for real verification that `xlarge` is genuinely the ceiling** — so
this investigation went further than usual: tried 13 alternate derivative-name guesses (all 403),
confirmed query-param resize tricks are ignored by CloudFront (byte-identical response), found and
inspected the real Vernon Browser vendor API (`apidocs.browser.vernonsystems.com` — a documented
`ImageDerivative` schema, but gated by an API key we don't have), researched Vernon Systems docs (IIIF
is only documented for eHive, not Vernon Browser), and inspected a Feb-2024 Wayback Machine snapshot of
a live object page (plain `<img>` tags, no OpenSeadragon/IIIF/DZI/zoomify viewer anywhere). EXIF on a
served `xlarge` confirms the true source photo is far higher-res (shot on a 12 MP Olympus TG-6) but
deliberately not published (S3 `AccessDenied`, not a WAF artifact) — same login-gated-originals policy
as Te Ahu/VUW. `swift build` 0; CollectionTester ×6 → 6/6 HTTP 200 `xlarge`; 5/6 measured gains
(1.11×–2.25× area), 1/6 already native (no loss). **Lesson: even a ~200k-record Vernon Browser site can
have a 0% missing-`xlarge` rate — still worth a wide uniform census (not a small sample) before
committing to the cheaper `stringSwap` over the HEAD-probe variant; and when a user asks "is this
really the ceiling," there's real due diligence available beyond guessing derivative names — check the
vendor's actual API/docs and archived snapshots of live pages for hidden zoom/tile viewers.** See
`logs/047-nelson-provincial-museum.md`.

**★ Platform correction (2026-07-04, found during order 47):** Te Ahu 45 and VUW 46 (and now Nelson 47)
were logged throughout this file as **"CollectiveAccess / Pawtucket"**. That label is **wrong** — the
platform is **Vernon Systems' "Vernon Browser"** (the same NZ company that makes eHive), confirmed via a
Wayback Machine snapshot of `collection.nelsonmuseum.co.nz` showing `vernon-common.min.js` and a
"Vernon Browser" modal title in the archived front-end HTML. All URL schemes, size ladders, and
measurements recorded for 45/46 are unaffected — only the platform name was wrong. Corrected in
`URLProcessor.swift` (comments + the `collectiveAccessLargest` helper renamed `vernonBrowserLargest`),
`progress.json` (`platform` field), `recipes.md` (section renamed `collectiveAccess` →
`vernonBrowser`), this README, the individual `logs/045-*.md` / `logs/046-*.md` files (correction notes
added), and the sweep memory.

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
