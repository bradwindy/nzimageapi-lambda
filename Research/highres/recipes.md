# Backend-Platform Recipes

Per-platform **detection signals** + **extraction recipes** for the high-res sweep.

> These recipes are a **floor, not a ceiling**. For EVERY collection — even known
> platforms (Recollect, IIIF, eHive, PastPerfect, Flickr) — run the **Discovery
> Playbook** (bottom of this file) and actively try to beat the recipe. Record the
> comparison in the collection's log. When a creative technique cracks a boutique
> site, add it here as a new platform entry so later collections reuse it instantly.

**Resolution metric:** decoded pixel area (width × height) of the final
browser-displayable image. Largest wins, even if it is a slow 20 MB+ fetch.
Convert JP2/TIFF via a proxy if `sips` can't decode it. Latency is acceptable.

**Request-time rule:** the Lambda only *constructs* URLs (plus ≤ a couple of light
HEAD/HTML calls). It NEVER downloads a full image at request time. All pixel
measurement happens **offline at investigation time**; the winning URL pattern is
hard-coded per collection.

---

## recollect (Axiell Recollect)
- **Detect:** `<meta recollect="…">`; footer "RECOLLECT © Recollect Limited";
  paths `/nodes/view/<id>`, `/assets/display/<id>-<size>`.
- **Extract:** asset ID usually already in `large_thumbnail_url`
  (`/assets/display/<id>-<size>`) → rip directly; else GET landing page `og:image`
  (`…-max`) and rip the ID.
- **Compare** `https://<domain>/assets/downloadwiz/<id>` (master) **vs**
  `…/assets/display/<id>-max`; pick larger; **default `downloadwiz`**.
- Plain GET + browser UA.
- Reuse/extend `recollectDownloadUrlString` + `recollectDomainMap` in URLProcessor.
- **Known domains:** dunedin, nam, paekoroki.tauranga.govt.nz, massey, hastings,
  huttcity, antarctica, hocken, waimakariri (all `*.recollect.co.nz` except
  paekoroki.tauranga.govt.nz).
- **VERIFIED (plan):** paekoroki asset — `-600` and `-max` byte-identical at
  1000×996, but `/assets/downloadwiz/<id>` = 5000×4982 (25× pixels). So `-max` is
  NOT always largest; downloadwiz wins. Never hard-code `-max`.

### Verified findings (recollect)
- **paekoroki.tauranga.govt.nz (Tauranga, 2026-06-02):** Three record classes. CAT1
  (~63%): `/assets/downloadwiz/<id>` = original master ~4600–5200 px (15–36 MP), served
  `application/octet-stream` + `Content-Disposition: attachment` + `nosniff` (downloads
  rather than displays inline, but renders in `<img>`; user accepts download). CAT2
  (~31%): no master — `downloadwiz` 302→"goDownload failed"; `-max` is the ceiling
  (~1000–1500 px) and ALL larger tokens (`-1200`…`-4000`) return the same capped image.
  CAT3 (~6%): asset deleted — `-600`/`-max` 302→"Requested Asset does not exist".
- **Strategy `recollectLargest`:** HEAD-probe `downloadwiz` *following redirects*; status
  200 ⟺ master present → use it; else use `/assets/display/<id>-max`. Asset id = digits
  between `display/` and the first `-`.
- **Master is hotlink-protected:** weserv/cloudimg/thumbnailer all get **403** fetching
  `downloadwiz` server-side; a `Range` header makes it 302. So the master can only be
  delivered as the raw `downloadwiz` URL (no proxy).
- **Pitfall:** Alamofire's HEAD is fine *following* redirects, but `Redirector.doNotFollow`
  misreported these 302s — and a stale lambda on :7000 masked test results. Use
  `headStatusFollowingRedirects` + kill :7000 between `CollectionTester` runs.
- **hocken.recollect.co.nz (Hocken Digital Collections, 2026-06-02):** thumb-id `downloadwiz` 404
  (42/42, master disabled for the indexed asset). NAM-style og:image two-asset EXISTS (og dw=200)
  but the og id is the **same image** and its master is capped ~2500px (often == og `-max`,
  sometimes < thumb `-max`) — not worth the per-request landing fetch. `-max` is the practical
  ceiling (~2000px, 2–6 MP) and ≥ `-600` across an 18-record sample (2–4×). **ADDED via new reusable
  `recollectDisplayMax`** (rip id → `/assets/display/<id>-max`, NO downloadwiz probe — use this when
  an instance's thumb master is uniformly 404 but `-max` > `-600`). Caveat: a small-original subset
  has `-600` *upscaled* larger (by pixel count) than the true `-max`; `-max` is the honest res.
- **huttcity.recollect.co.nz (Lower Hutt MyRecollect, 2026-06-02):** healthy Recollect, Tauranga-style.
  `downloadwiz` masters 200 for 25/25 sampled (~5000px originals, 3.9–28 MP) vs ~1 MP `-600`; a few
  dead records (404). og:image id == thumb id. **ADDED via `recollectLargest`.**
- **hastings.recollect.co.nz (Hastings Recollect, 2026-06-02):** healthy Recollect, Tauranga-style.
  `downloadwiz` masters present for ~96% (24/25), large originals 1.5–59 MP (octet-stream), vs ~1 MP
  `-600`. ~4% dead records (display+downloadwiz 404). og:image id == thumb id. **ADDED via
  `recollectLargest`** (registry + recollectDomainMap). Confirms the reusable recollect master
  strategy generalises across instances.
- **prc.recollect.co.nz → pcanzarchives.recollect.co.nz (Presbyterian Research Centre, 2026-06-02):
  MIGRATED + LOGIN-WALLED.** A Recollect site can move domains and go private. `prc.recollect.co.nz`
  301/302-redirects to `pcanzarchives.recollect.co.nz`, but the DigitalNZ-harvested asset ids 404 on
  the new domain (re-IDed; no old→new mapping) and node pages 302→`/users/login`. DigitalNZ's data is
  stale → the Lambda's passthrough emitted broken 404s. **Outcome: blocked + removed from the
  Lambda.** ⇒ Lesson: for any Recollect collection, if `/assets/display/<id>` redirects to a
  *different* `*.recollect.co.nz` host and/or `/nodes/view/<id>` lands on `/users/login`, the source
  has migrated/gone private — check before assuming a fixable strategy. (Relevant to other recollect
  collections still queued: Hocken, Lower Hutt, Hastings, Tāmiro, He Purapura.)
- **nam.recollect.co.nz (National Army Museum, 2026-06-02):** **two-asset records.** The DigitalNZ
  `large_thumbnail_url` id (e.g. 13722) is a master-less thumbnail asset — `downloadwiz` 404
  (50/50), `-600`==`-max` capped ~1000px. The node's `og:image` points to a DIFFERENT, newer
  primary asset id (e.g. 31444) that DOES have a master — `downloadwiz/<ogId>` = 200 for 41/41
  records, decoding 1.2–5.2 MP (originals, octet-stream + attachment). ⇒ `recollectLargest` (which
  rips the large_thumbnail id) would REGRESS this collection to ~1000px; you MUST scrape the landing
  `og:image` to reach the master. The existing `og:image→downloadwiz` strategy is already optimal
  (no-improvement). **Lesson:** when the large_thumbnail id's `downloadwiz` 404s but the collection
  *looks* like it should have masters, check whether the landing `og:image` uses a different id with
  a master before concluding "no master." (No fallback in the current code, but 41/41 had masters.)
- **adam.antarcticanz.govt.nz (Antarctica NZ ADAM, 2026-06-02):** downloadwiz **disabled** —
  `/assets/downloadwiz/<assetId>` 404s for **184/184** sampled records ("goDownload failed").
  Display pyramid hard-capped at **width ~1000 px**: `-600` (= `large_thumbnail_url`) is
  byte-identical to `-max`, and `-1000…-4000` all clamp to the same file; `-original/-full/-master`
  and `/assets/{download,original,file,fullsize,master}/<id>` 404. The `?u=<sig>` token does not
  unlock anything larger. og:image advertises the true original (e.g. 3196×2152) but it is not
  served by any anonymous route. The "Download" button → `/nodes/download/<nodeId>` is a JS dialog
  that calls downloadwiz (fails). **Outcome: no-improvement** — baseline passthrough already at the
  ceiling. ⇒ Lesson: a Recollect instance can have masters fully disabled; always sample
  downloadwiz before assuming Tauranga-style master availability. Note `landing_url` carries a
  **node id** (`/nodes/view/<node>`), distinct from the **asset id** in the image URL.
- **massey.recollect.co.nz (Tāmiro, 2026-06-02):** all-master. `downloadwiz` 200 for 75/75; ~2700px
  (5 MP) vs ~1 MP `-600` (==`-max`). **0 CAT2, 0 dead in sample** → the existing bare-`downloadwiz`
  (no fallback) already serves the master for ~100%. **no-improvement** (a `recollectLargest` probe
  would only add a wasted HEAD since the fallback never fires). Left in the legacy `switch`.
- **dunedin.recollect.co.nz (He Purapura Marara Scattered Seeds, 2026-06-06):** healthy-but-mixed,
  community-contributed. Uniform 100-record sample: **CAT1 ~90%** (`downloadwiz` master 200, 3–23×
  the ~1000px display tier, `-600`==`-max`), **restricted/login-walled ~10%** (`/nodes/view/<n>`
  302→`/users/login`; downloadwiz + all `display/<id>-*` 404 anonymously — community uploads not
  publicly released; unfixable, NOT deleted), **CAT2 ~0.6%** (downloadwiz 302→404 but `-600`/`-max`
  200). ⇒ Unlike Tāmiro, He Purapura HAS a CAT2 tail that the bare-`downloadwiz` no-fallback case
  served as a **broken 404**. **Migrated to `recollectLargest`** (registry; removed from the
  Tāmiro-shared legacy case). Strict improvement: master unchanged on CAT1, CAT2 fixed → `-max`, no
  regression on restricted. ⇒ **Lesson:** "restricted/login-walled" records (node→`/users/login`,
  all assets 404) are a distinct category from CAT2/CAT3 — they're private, not gone, and unfixable
  anonymously; a biased page sample can wildly over/under-count them, so sample uniformly across the
  full result set. The bare-`downloadwiz` (no fallback) is safe ONLY when CAT2==0 (Tāmiro); prefer
  `recollectLargest` whenever any CAT2 exists.

---

## flickr
- **Detect:** `object_url`/`source_url` on `live.staticflickr.com` or
  `*.staticflickr.com`; `flickr.com/photos/...` landing.
- **Extract:** `object_url` is often already full-res. If `staticflickr.com`,
  upgrade the size suffix toward `_o` (original) / `_6k`/`_5k`/`_4k`/`_3k`/`_k`;
  or call `flickr.photos.getSizes` (needs a Flickr API key) for the Original.
- **Collections:** Alexander Turnbull, Ministry for Culture Te Ara, Dunedin City
  Council Archives, State Library of NSW, Australian National Maritime Museum.

### Verified findings (flickr)
- **Secret rule (confirmed: flickr.com/services/api/misc.urls.html + secondary sources):** sizes
  `_b`(1024)/`_c`(800)/`_z`(640) and everything **below** `_h` share the photo's **base secret**, so
  they're reachable by a pure string swap on a harvested static URL. `_h`(1600) and `_k`(2048) each
  use a **unique per-photo secret**; `_o`(original) uses `originalsecret`. ⇒ `_b` is the largest size
  obtainable WITHOUT the photo page / `getSizes` API (needs a key). **Flickr never upscales** —
  requesting a size larger than the original returns the original at that URL (HTTP 200, not 404), so
  `_z`→`_b` is safe for every record.
- **Reusable `flickrLargest` (URLProcessor):** swap the size token to `_b`. Filename is
  `<id>_<secret>[_<size>].jpg` and `<id>`/`<secret>` never contain `_`, so split on `_`: 3+ parts ⇒
  replace the trailing size token with `b`; 2 parts (no token = the `_500` default) ⇒ append `_b`.
- **Ministry for Culture and Heritage Te Ara Flickr (2026-06-06):** `object_url` null; harvested `_z`
  (640). Max-size distribution over 63 uniform photos: `_b` 56, `_c` 4, `_z` 3 — **0 exceed 1024**.
  Pool is web-resolution uploads; per-request page-scraping for `_h`/`_k`/`_o` not worth it (≈0%
  benefit + fragility/latency). **ADDED via `flickrLargest`** (registry + weight 0.015). Baseline
  `_z` 640 → `_b` 1024 = 2.56× area. ⇒ Lesson for the remaining Flickr collections (12–15): check
  `object_url` first (Turnbull serves originals there) — `flickrLargest` is the fallback when only a
  capped static `_z`/`_c` is harvested; sample the max-size distribution before assuming originals exist.
- **Alexander Turnbull Library Flickr (2026-06-06):** **Flickr Commons** account
  (`nationallibrarynz_commons`) — `object_url` is the `_o` **original** for 50/50 uniform sample (0
  null, 0 non-jpg; all `image/jpeg` HTTP 200), 5.8–25.9 MP vs `_z` 0.3 MP. ⇒ When a record has an
  `_o` `object_url`, that's the Flickr ceiling (`_b` only ever ≤ `_o`); `objectUrlDirect` is optimal,
  no resolution gain available. **no-resolution-improvement.** Committed a strict-≥ cleanup only:
  migrated the legacy case to the registry as `result.objectUrl ?? flickrLargest(...)` — identical on
  ~100% (object_url present), and upgrades the null fallback from raw `_z`(640) to `_b`(1024).
  ⇒ **General Flickr rule:** prefer `object_url` (the `_o` original, common on Commons / download-
  enabled accounts); use `flickrLargest` (`_b`) only when `object_url` is absent or itself capped.
- **Dunedin City Council Archives Flickr (2026-06-06):** account `95014006@N04`; identical shape to
  Turnbull — `object_url` = `_o` original for 45/45 uniform sample (0 null, all `image/jpeg`),
  0.4–27.7 MP vs `_z` 0.3 MP. **ADDED** via the general Flickr rule (registry closure
  `object_url ?? flickrLargest`) + weight 0.002. Confirms the rule generalises across Flickr accounts.
- **⚠️ CORRECTION — the largest sizes need the PHOTO PAGE, not a same-secret swap (2026-06-06).**
  `_b`/`_c`/`_z` share the base secret, but `_h`/`_k`/`_o` (up to the full original, tens of MP) use
  **per-photo alternate secrets** that live ONLY in the photo page's embedded size model (or the
  paid `getSizes` API). The size URLs there are **JSON-escaped (`\/`)** — you MUST de-escape before
  grepping, and **filter strictly to `<photoId>_<secret>_<size>`** so related/recommended photos on
  the page don't leak in. A scrape of the main-page `displayUrl` list (without de-escaping) silently
  undercounts → this is why the Te Ara order-11 "0/63 exceed 1024" was wrong (some Te Ara photos are
  `_h`/`_k`/`_o`, up to ~13 MP).
- **`flickr.photos.getSizes` is NOT usable here:** Flickr now requires **Flickr Pro (paid)** to
  create an API key. Use the page scrape instead.
- **Reusable `flickrLandingLargest` (URLProcessor):** for Flickr collections with **null
  `object_url`**. Fetch `result.landingUrl`, `replacingOccurrences("\\/", "/")`, `NSRegularExpression`
  `live\.staticflickr\.com/[0-9]+/<photoId>_[0-9a-z]+_([0-9a-z]+)\.(jpg|png|gif)`, pick the max by
  `flickrSizeRank` (o>6k>5k>4k>3k>k>h>b>c>z>w>m>n>q>t>s). One bounded HTML GET/request; falls back to
  `flickrLargest` (`_b`) on no-landing/fetch-fail/no-match. Decision tree per Flickr collection:
  `object_url` present (Turnbull, Dunedin CC) → serve it (`_o`, free, no fetch); `object_url` null
  (SLNSW, ANMM, Te Ara) → `flickrLandingLargest`.
- **State Library of New South Wales Flickr (2026-06-06):** account `statelibraryofnsw`, high-res
  Commons; `object_url` null; landing page exposes `_o` originals up to **44.9 MP** (7792px; mixed —
  small scans too). **ADDED via `flickrLandingLargest`** + weight 0.001. CollectionTester ×3 → `_o`
  9.1 MP vs `_z` 0.3 MP (~30×).
- **Australian National Maritime Museum Flickr (2026-06-06):** account `anmm_thecommons`. Despite
  being a high-res Commons account, `object_url` IS populated (= `_o` original, 35/35 sampled, 4–28 MP)
  — so it's the Turnbull/Dunedin shape, NOT object_url-null like SLNSW. **ADDED via
  `object_url ?? flickrLandingLargest`** (original for free when present; page-scrape original as the
  null fallback) + weight 0.001. ⇒ Always check `object_url` per record — Commons membership does NOT
  imply `object_url` is null.
- **Te Ara Flickr RETROFIT (2026-06-06):** order 11 was committed as `flickrLargest` (`_b`/1024) on a
  flawed "0/63 exceed 1024" reading. **Switched to `flickrLandingLargest`.** A subset has `_h`/`_k`/`_o`
  originals (up to ~13 MP); also fixes records whose harvested `_z`/`_b` base secret is **stale (HTTP
  410)** by recovering a live alternate secret from the page. ⇒ Final Flickr decision tree:
  `object_url` present → serve it (free `_o`); `object_url` null → `flickrLandingLargest` (scrape).

---

## iiif (IIIF Image API)
- **Detect:** URL contains `/iiif/`, `info.json`, `/full/…/0/default.jpg`;
  viewers OpenSeadragon/Mirador/Universal Viewer.
- **Extract:** fetch `info.json`; read `width`/`height`, `maxWidth`/`maxHeight`/
  `maxArea`, `sizes[]`. Request v3 `/full/max/0/default.jpg` or v2
  `/full/<maxW>,/0/default.jpg`. Check the Presentation manifest for the true
  original if the service caps below it. Compare v2 vs v3 endpoints.
- **Improvement target:** replace Kura's hardcoded `2048` with the real
  `info.json` max.

### Verified findings (iiif)
- **Kura Heritage Collections Online = CONTENTdm (2026-06-06).** `kura.aucklandlibraries.govt.nz`,
  OCLC CONTENTdm, IIIF 2.0 level2. `large_thumbnail_url` is the CONTENTdm `singleitem` image API
  (`/digital/api/singleitem/image/photos/<id>/default.jpg`); the asset id sits between `/image/photos/`
  and `/default.jpg`. IIIF base: `/iiif/2/photos:<id>/`.
- **Native capped at 2000 px long side; no larger master.** `info.json` `width`/`height` and `sizes[]`
  top out at the native size (0/30 sampled > 2048; many exactly 2000). The CONTENTdm download
  endpoints (`utils/getfile/...`, `digital/api/collection/photos/id/<id>/download`) return the SAME
  native — there is no bigger preservation file. `/full/2828,/` and `/full/4000,/` → **403**.
- **`sizeAboveFull` ⇒ a hardcoded width UPSCALES.** The old `/full/2048,/` interpolated every image to
  2048-wide fake pixels (portrait native 1378 → 2048). Use **`/full/max/`** (== `/full/full/` here) for
  the honest native. ⇒ **Lesson:** for any IIIF service, NEVER hardcode a width — read `info.json` and
  request `/full/max/` (v2) or `/full/max/` (v3); a profile listing `sizeAboveFull` means a fixed width
  > native yields interpolation, not detail. Decision (quality vs pixel-count, like Hocken): user chose
  honest native. **Migrated switch → registry.**

---

## ehiveIIIF (NZMuseums / eHive)
- **Detect:** `nzmuseums.co.nz` / `ehive.com` hosts.
- **Extract:** public derivatives often capped ~800×800 unless public-domain. Look
  for IIIF `info.json` / pan-zoom for full res; eHive also has a public REST API
  (developers.ehive.com) and rights-gated full-size. Explore all routes.
- **Collections:** Howick Historical Village, Mataura Museum, NZ Portrait Gallery.

### Verified findings (ehiveIIIF)
- **eHive image URLs:** `https://images.ehive.com/accounts/<acct>/objects/images/<imageId>_<token>_<size>.jpg`.
  Public size suffixes: `_t` 75, `_s` 150, `_m` 400, **`_l` 800** (long side). `_l` is the anonymous
  max; `_xl`/`_o`/`_full`/`_master`/no-suffix/base-id all **HTTP 500**, `?size=original` ignored.
- **The 800px cap is server-side by RIGHTS TYPE, not URL-level (and per-account).** eHive docs: public
  viewers get either the full original OR 800×800, set per account/rights; **signed-in users get the
  original** (no public URL/mechanism). No public IIIF/DeepZoom for capped accounts (`.dzi`,
  `/info.json`, `/iiif/.../info.json` → 404/500). REST API (developers.ehive.com) is OAuth-gated. No
  known anonymous tool/trick (dezoomify respects the server cap).
- **"Public Domain unlocks the original anonymously" — NOT reliable.** It's an account setting; tested
  on Howick's single PD record (`21faf96e…`) → still `_l` 800px (`_xl`/`_o` 500). So a PD rights value
  does NOT guarantee a larger anonymous image; the account must have enabled full-res public access.
- **★★★ CORRECTION (2026-06-07, order 18 Mataura): eHive HAS a public IIIF Image API 2.0 service over
  the MASTER TIFF — on a SEPARATE host, `iiif.ehive.com` (not `images.ehive.com`).** The earlier
  finding "no public IIIF for capped accounts" was WRONG: it only probed `images.ehive.com/.../info.json`
  and the `_xl`/`_o` suffixes. The real service is wired to each object page's **OpenSeadragon** viewer:
  `info: "https://iiif.ehive.com/iiif/2/accounts%2f<acct>%2fobjects%2fimages%2f<imageId>_<token>.tif/info.json"`
  (identifier = the master TIFF, size suffix dropped, `.jpg`→`.tif`, `/`→`%2f`). **Discovery key:** grep
  the landing-page HTML for `iiif` / `openseadragon` / `tileSources` and pull the `info` URL.
  - **`/full/full/0/default.jpg` returns the FULL NATIVE master** as browser `image/jpeg`, for **every
    record regardless of rights** (the IIIF endpoint is NOT rights-gated, unlike the `_xl`/`_o` suffixes
    which 500). `/full/full/` == `/full/max/` (byte-identical; no `maxWidth/maxArea` declared ⇒ true
    native, never upscaled — passes the Kura lesson).
  - **Swift strategy `ehiveIIIFLargest` (URLProcessor):** from `images.ehive.com/accounts/<a>/objects/
    images/<id>_<token>_l.jpg`, drop the **last** `_<size>` segment (the id itself has an underscore),
    `.jpg`→`.tif`, `/`→`%2f`, build `https://iiif.ehive.com/iiif/2/<enc>/full/full/0/default.jpg`. Pure
    string construction, no request-time fetch. Handles UUID-style ids (`<hex>_l.jpg`, one underscore).
- **Mataura Museum NZMuseums (2026-06-07, order 18): ADD via `ehiveIIIFLargest`.** account 4033; 3,443
  records (3379 All-rights + 47 PD + others). IIIF native beat `_l` on **28/28 uniform sample, 0
  failures**: ~half at 1.56× (1000px masters; floor, since `_l` is 800px-capped), ~half 3.5×–36×
  (1500–4800px masters; max observed 4800×3502 = 16.8 MP). Suffix probe still caps at `_l` 800 (`_xl`/
  `_o`/`_full`/`_master` → 500; the 47 PD records' suffix route is also capped) — the win is ENTIRELY
  via the IIIF master endpoint. Weight 0.003 provisional. Committed (see progress.json).
- **★ Howick (order 17) RE-OPENED 2026-06-07:** account 3000 ALSO has `iiif.ehive.com` — tested records
  return up to 2816×2112 (5.9 MP, ~12× the `_l` 0.48 MP), about half have genuine 800px masters. The
  order-17 "no-improvement" (which checked the eHive UI + `_xl`/`_o` + `images.ehive.com`, but missed
  `iiif.ehive.com`) was WRONG. Re-done with `ehiveIIIFLargest` (see log 017 / 018). **LESSON for any
  eHive account: ALWAYS check `iiif.ehive.com/iiif/2/accounts%2f<acct>%2fobjects%2fimages%2f<id>.tif/
  info.json` — the `_l` 800px derivative is NOT the ceiling; the master TIFF is publicly served via
  IIIF regardless of rights or the eHive UI/login cap.**
- **New Zealand Portrait Gallery NZMuseums (2026-06-07, order 19): ADD via `ehiveIIIFLargest`.** account
  3272; 136 records (all "All rights reserved" — irrelevant). **24/24 uniform win, 0 honest-smaller, 0
  failures** (1.27×–49.3×; masters up to 5616×3744 = 21 MP). Cleanest eHive account (a portrait gallery
  uploads big masters; no upscaled-`_l` anomalies). Weight 0.001. ⇒ eHive cluster (17–19) COMPLETE.

---

## pastPerfect (`*.pastperfectonline.com`)
- **Detect:** host `*.pastperfectonline.com`.
- **Extract:** full-size at `/Media/<UUID>`; record page at `/Webobject/<UUID>`;
  plain GET.
- **Collection:** Waimate Museum and Archives PastPerfect.

### Verified findings (pastPerfect)
- _(append here)_

---

## vernon (Vernon CMS browser)
- **Detect:** Vernon viewer markup; derivative path token ∈
  nano/tiny/small/medium/large/xlarge/display/thumbnail/original.
- **Extract:** swap the token toward `xlarge`/`original`. Docs:
  vcms-help.vernonsystems.com. Verify at investigation time (ignore stale tags).

### Verified findings (vernon)
- _(append here)_

---

## Proxy / format toolbox

### weservProxy (images.weserv.nl)
- No resize param = native resolution. **71 MP cap.** ~700 req/3 min.
  `output=webp|jpg`. **Cannot do JP2.** Hotlink bypass + format convert.
- `https://images.weserv.nl/?url=<urlenc-without-scheme-ok>`; add
  `&output=webp` to force WebP.
- **Collections:** Te Papa, Hawke's Bay.

### Verified findings (Te Papa, order 21, 2026-06-07) — `tePapaLargest`
- **`media.tepapa.govt.nz/collection/<id>/{thumb|preview|full}`** (303-redirects to S3
  `co3-api-mediastorage`). Harvested `large_thumbnail_url` = `/preview` (≤1000 px). **`/full` is the
  master** (21–97 MP) but is served **ONLY for open-access records**; in-copyright ("All Rights
  Reserved"/"Copyright Te Papa", ~38% of 388k) return **HTTP 500** on `/full`. Rights facet: ~62%
  open-access (CC BY 147k + No Known Copyright 69k + CC BY-NC-ND 23k + small CC).
- **`/full` cannot be HEAD-probed (403) and weserv CANNOT proxy it (404)** — but it **embeds directly**
  (no hotlink protection) and a **1-byte ranged GET** (`Range: bytes=0-0`, follow redirects) cleanly
  distinguishes availability: open-access → **206** (1 byte), in-copyright → **500**. ⇒ added
  `NetworkRequestManager.rangeStatusFollowingRedirects` (works where HEAD is blocked) and
  `URLProcessor.tePapaLargest`: probe `/full`; serve it **directly** on 206/200, else
  `weservProxy(/preview)` (unchanged → no regression). **`/full` can exceed weserv's 71 MP cap** (a
  tester record was 97 MP) → must serve direct, not proxied.
- **Tester quirk:** `CollectionTester` validates with **HEAD**, which Te Papa blocks on `/full` (403) —
  shows a false "❌ 403". Verify `/full` with **GET** (what browsers do): all 200 `image/jpeg`.
- **Lesson for other "preview/derivative" media servers:** when HEAD is blocked and the proxy 404s, a
  bounded **ranged GET** is the robust per-request availability probe (never downloads the asset).

### cloudimgFullRes (cloudimg.io v7)
- Native-res hotlink/format proxy. Use `org_if_sml=1`, **drop fixed `height=`**.
  `force_format=jpeg` to normalize. Good for JP2 (unlike weserv).

### thumbnailerProxy (thumbnailer.digitalnz.org)
- `https://thumbnailer.digitalnz.org/?format=jpeg&src=<urlenc>`.
- **Collection:** ~~Auckland Libraries Heritage~~ — REMOVED (order 23, 2026-06-07): its DigitalNZ
  harvest is fully degraded (every record has a null `large_thumbnail_url` + a generic landing URL), so
  it hard-failed on every request; the same Auckland Libraries photos are served at higher resolution by
  **Kura Heritage Collections Online (order 16)** (the live Kura CONTENTdm `photos` collection). The
  `thumbnailerProxy` helper remains as a seeded reusable recipe (currently unreferenced).
- **General lesson:** when a Group A collection's harvest has gone all-null (`large_thumbnail_url` null
  across a uniform multi-page sample), it is unservable (`checkHasTitleAndLargeImage` throws, no retry)
  and should be removed unless its content isn't already covered elsewhere. Check whether the source
  migrated to a platform already served (here: Matapihi/aucklandcity → Kura CONTENTdm).

### objectUrlDirect
- Use `result.objectUrl` directly when it is the full-res original.
- **Collection:** Alexander Turnbull (+ any full-res object_url).

### stringSwap
- Swap a size token (`large`→`xlarge`, `medium`→`xlarge`; probe
  `xxlarge`/`original`).
- **Collections:** Canterbury Museum, Culture Waitaki, Auckland Art Gallery.

### passthrough
- Return `large_thumbnail_url` unchanged. Several boutique collections.

### genericBoutique
- No known platform: GET landing page for a larger `<img>`/`og:image`/downloadable
  original; try size-token swaps; fall back to thumbnailer/weserv; else passthrough.

---

## aklMuseumCloudimg (Auckland Museum)
- Call `https://collection-publicapi.aucklandmuseum.com/api/v3/opacobjects/<landingId>`,
  extract `object_av_link` first value, split on `|`, replace `\`→`/`, serve via
  cloudimg. **Hypothesis:** drop `height=1000`, add `org_if_sml=1` for native res.

### Verified findings (aklMuseumCloudimg, order 22, 2026-06-07)
- **The shipped pipeline was BROKEN (404 for every record).** The old code built
  `…/v7/_collectionsecure_/J:/Dir/…/X.jpg?c=11?ci_url_encoded=1&force_format=jpeg&height=1000`,
  keeping the **`J:` drive prefix** and leaving the path **unencoded** while passing
  `ci_url_encoded=1`. Every form 404s. The hypothesised `height=1000` upscale never even
  reached a valid image.
- **Harvested `large_thumbnail_url` changed** to
  `collection-api.aucklandmuseum.com/records/images/medium/<id>/<hash>.jpg` = **400 px**.
  Size tokens on that host: `small` 150, `medium` 400; `large`/`xlarge`/`full`/`original`/
  `master`/`raw` → **403** (signed/private). So the harvested host caps the public image at 400 px.
- **The working master route** (verified, what the landing page uses): take `object_av_link`
  first value (e.g. `J:\DocumentaryHeritage\…\full\X.jpg|20||…`), `\`→`/`, **strip the leading
  drive prefix `J:`** (the `_collectionsecure_` alias root maps to it), **percent-encode** the
  path (`/`→`%2F`, space→`%20`), then:
  `https://ajrctguoxo.cloudimg.io/v7/_collectionsecure_%2F<encoded>?ci_url_encoded=1&force_format=jpeg&org_if_sml=1`.
- **`org_if_sml=1` + NO width/height = honest native master, no upscaling.** Verified across 22
  records: native 0.36 MP → **71 MP** (7105×10015), 1.6×–471× the 400 px `medium`; `512 px`
  masters stay 512 px (no fake upscale). cloudimg processed a 71 MP master fine (no obvious cap
  hit, unlike weserv's 71 MP limit). The `?c=<cachebuster>` the site appends to the origin is
  NOT required (omitted).
- **No larger public source:** `media.aspx?id=…&hash=…` on the landing page → 404;
  `collection-api` `large`/`full` tokens → 403. The cloudimg `_collectionsecure_` master (the
  museum's own `full/` access master) is the ceiling.
- **Per-request cost:** one bounded JSON GET to the public API (unchanged); never downloads the
  image. Fall back to the harvested 400 px `medium` on nil landing id / API error / missing
  `object_av_link` so output is always a valid 200.
- **Tester artifact:** CollectionTester's 10 s HEAD times out on cloudimg's *cold* processing of
  a large master → reports "HTTP 0"; a warm HEAD returns 200 in ~2.5 s and every GET is 200
  image/jpeg. Treat slow large-master HEADs as PASS when GET confirms (per the plan).

---

## tapuhi (NDHA natlib)
- 5-step: IE PID → DVS session → FL PIDs → HEAD each for largest → output via proxy.
- **Risk:** weserv cannot do JP2 — if the FL stream is JP2, verify weserv actually
  returns an image; if not, switch to cloudimg `force_format=jpeg` or a natlib
  JPEG derivative.

### Verified findings (tapuhi / NDHA)
- **NLNZStreamGate variant (National Publicity Studios, 2026-06-02):** some NDHA collections give
  `large_thumbnail_url = https://ndhadeliver.natlib.govt.nz/NLNZStreamGate/get?dps_pid=IE<digits>`
  (not the `dps_pid=IE…&dps_func=...` shape). This streams the **access copy** directly. The
  TAPUHI 5-step (IE→DVS→ieViewer→FL) on these IEs finds a **single FL** whose `dps_func=stream`
  bytes are **byte-identical** to NLNZStreamGate/get — i.e. the FL *is* the access copy, no larger
  master. Only an "access" representation exists; `IE…&dps_func=download`/`downloadAll` → 404;
  `FL…&dps_func=download` → same access JPEG as attachment; `IE…&dps_func=thumbnail` → ~150px. No
  IIIF/Djatoka/zoom. ⇒ For NLNZStreamGate-shaped records the Rosetta master is not public; baseline
  passthrough is already the ceiling (~900px access copy). Distinguish from TAPUHI proper (order
  25), which DOES expose multiple FL streams incl. large masters — verify per collection.
- Landing institution can differ from image host: National Publicity Studios is held by **Archives
  NZ** (`collections.archives.govt.nz`, Axiell Arena/Liferay) but delivered via natlib NDHA. The
  Arena SPA embeds the same ndhadeliver streams; no separate public hi-res download.

---

# Discovery Playbook (mandatory in Step 2 for EVERY collection)

The first URL that returns an image is rarely the largest. Keep asking "is there a
bigger one, and how would I get it?" Exhaust A–G before recording `no-improvement`.
Be skeptical: confirm any technique against ≥2 sources. Log what you tried AND what
failed so re-checks don't repeat dead ends.

**A. Web research first** (always, even for known platforms): search "how to
download full resolution / original image from `<platform/site>`", "`<platform>`
image API / IIIF / deep zoom / max size", the platform's own docs / developer
reference / GitHub issues / library-help pages, and any institutional
image-request/download policy. Cross-check ≥2 sources.

**B. Front-end / page-source reverse engineering:** fetch raw HTML of `landing_url`
and any view/zoom page; dig `og:image`(+`:width/:height`), `twitter:image`,
`<link rel="image_src">`, oembed, `<img srcset>`, `<picture><source>`, `data-*`
(`data-zoom-image`, `data-large`, `data-original`, `data-full`, `data-src`,
`data-image-id`, `data-iiif`, `data-manifest`), embedded state (`__NEXT_DATA__`,
`window.__NUXT__`, `__INITIAL_STATE__`, `application/ld+json`, inline config), and
referenced JS/API hosts (`/api/`, `/graphql`, `/iiif/`, `/manifest`, `/info.json`,
`/download`, `/media/`, `/asset/`, `/derivative/`, `/dams/`, S3/Cloudinary/imgix).

**C. Detect image viewers → reconstruct source:**
- OpenSeadragon / Mirador / Universal Viewer / Leaflet-IIIF / Diva.js → IIIF image
  service (`info.json`) or manifest → request the largest allowed.
- Zoomify → `ImageProperties.xml` (full W/H; tiles under `TileGroupN/`).
- DeepZoom (Seadragon) → `*.dzi` + `*_files/` pyramid (max level = full res).
- IIPImage / IIPMooViewer → `FIF=…` endpoints (`&WID=` / `&CVT=jpeg`, or IIIF mode).
- CONTENTdm → IIIF endpoint + `/digital/api/` calls; IIIF max usually beats the
  default thumbnail.

**D. URL / parameter mutation (probe and measure):** size tokens
`small→medium→large→xlarge→xxlarge→original→master→full→raw→source→o`; dimension
params `w/h/width/height/size/maxsize/quality` (huge values + "don't upscale"
flag); strip size suffixes (`-600`,`-280`,`_thumb`,`/preview/`,`/thumbnail/`) or
swap for `/full/`,`/original/`,`/download/`; change extension/format
(`.jpg`↔`.tif`↔`.png`). Keep the largest browser-displayable (proxy-convert if
needed).

**E. Alternate host / alternate source:** `landing_url`, `source_url`, `object_url`,
and the institution's own catalogue often differ — try them all; the hi-res host may
be a separate DAMS/CDN/bucket. The same item at higher res on another official
aggregator is acceptable **only if verifiably the same item** (user holds rights;
NZ public-domain).

**F. Dead / down sites:** retry over time; try the Wayback Machine
(`web.archive.org`) and search-engine caches for the page or the image asset itself.
Only mark `blocked` after these fail (with HTTP evidence).

**G. Format/hotlink toolbox:** once the largest source is found, if it is
hotlink-protected / wrong-format / not browser-displayable, wrap it: weserv
(native, no JP2, 71 MP cap), cloudimg (`org_if_sml=1`, `force_format=jpeg`), or
thumbnailer.digitalnz.org. Measure the proxied output as the final image.

**H. When to stop:** stop when you have (a) a verified candidate that beats the
baseline, or (b) genuinely exhausted A–G with measurements logged. High effort
expected, but bounded. Record `no-improvement` (avenues tried) or `blocked`
(evidence).
