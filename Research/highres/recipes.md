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

## recollect (Recollect — by Recollect Ltd / NZMS, NOT Axiell)
> The `*.recollect.co.nz` `downloadwiz` platform is made by **Recollect Limited** (spun out of
> **NZMS — New Zealand Micrographic Services** — in 2019). It is **not** an Axiell product. The
> `recollectcms.com` signed-IIIF sites (see the `recollectIIIF` section) are the **same vendor's**
> newer product generation, NOT a second vendor.
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
- **clutha.recollect.co.nz (Clutha Heritage, order 36, 2026-06-14):** healthy Recollect, Tauranga-shape.
  **Group B ADD via `recollectLargest`.** `downloadwiz` master 200 for **784/788** uniform sample (99.5%;
  JPEG served `application/octet-stream`+`attachment`, up to 6000×4379 = 26 MP), vs the `-600`==`-max`
  ~1000 px display cap → **34/36 pixel-sample win (median 4.27×, max 36×)**; 2/36 honest-smaller (small
  originals whose `-600` is **upscaled-fake** to ~1000 px — master/`-max` give the honest native, cf.
  Hocken 8). The 4 non-200 records (16437–16443, the newest batch) are CAT2 — `downloadwiz` 404 but
  `-600`/`-max` 200, so `recollectLargest` serves `-max` (no breakage). **No login-wall, all rights
  public/open** (no He-Purapura restricted tail). **★ Identity quirk:** "Clutha Heritage" is the DigitalNZ
  **`primary_collection`**, not the `collection` field (`and[collection][]` → 0; `display_collection` on
  every record = "Clutha Heritage" so the registry/domain-map/weights key works). **★ Vanity-domain
  redirect:** `clutha.recollect.co.nz` **301-redirects to `heritage.cluthadc.govt.nz`** (council domain;
  `og:image` points there) — both serve the master; the redirect is followed transparently by
  `headStatusFollowingRedirects` and by browsers, so the harvested `*.recollect.co.nz` host works
  end-to-end (kept in `recollectDomainMap`, consistent with the other entries). NOT NAM-style two-asset
  (the thumbnail id's own `downloadwiz` already serves the master).
- **kinderlibrary.recollect.co.nz (John Kinder Theological Library, order 37, 2026-06-14): TWO-ASSET,
  ADD via NEW reusable `recollectOgImageMaster`.** The canonical NAM (order 02) two-asset shape,
  generalised into a registry strategy. The harvested `large_thumbnail_url` id is a **master-less display
  derivative** — `downloadwiz/<thumbId>` 404s ("goDownload failed") and `display/<thumbId>-600` == `-max`
  == `-1000…-4000` are all byte-identical ≈1000 px (the size token unlocks nothing) — while the **node
  page's `og:image` points to a DIFFERENT primary asset id** (thumb 374245→og 374380, thumb 378354→og
  398934, …) whose **`downloadwiz` master IS present**. Uniform 80-record survey: thumb `downloadwiz` 200
  = **0/80**, og id differs = **80/80**, og `downloadwiz` 200 = **80/80 (100%)**, 0 login-walls / 0 dead
  nodes / 0 missing-og; og widths min 318 / median 1927 / max 6587. Pixel sample (32): **22 win (median
  3.81×, max 43×/31.5 MP)**, 8 equal (small ≤1000 px native), **2 honest-smaller** (the `-600` upscales
  small originals to fake ~1000 px; `downloadwiz` serves the honest 800 px native — honest-native-always,
  cf. Clutha/Hocken/Kura). Master = JPEG `application/octet-stream`+`attachment` (up to 7383×5779 =
  42.7 MP). ⇒ `recollectLargest` (rips the master-less thumb id) would **regress every record to
  ~1000 px** — you MUST scrape the node `og:image` for the primary asset id. **`recollectOgImageMaster`
  (URLProcessor):** one bounded `fetchHTML(landingUrl)` → SwiftSoup `meta[property=og:image]` →
  `slice(display/ … -)` the og id → HEAD-probe `downloadwiz/<ogId>` following redirects, serve on 200 else
  `display/<ogId>-max`, using the og:image's own host; fall back to the harvested `url` on any failure.
  (NAM's legacy switch case is the same idea without the master-probe/`-max` fallback; it was left intact
  as already-optimal. Reuse `recollectOgImageMaster` for any future Recollect collection whose thumb-id
  `downloadwiz` is uniformly 404 but the node `og:image` carries a different master-bearing id.)
- **tasman.recollect.co.nz (Tasman Heritage, order 38, 2026-06-14): TWO-ASSET + VANITY REDIRECT, ADD by
  REUSING `recollectOgImageMaster`.** Same two-asset shape as John Kinder (thumb `downloadwiz` 404 0/80;
  node `og:image` → a DIFFERENT primary asset, og `downloadwiz` 200 **80/80 = 100%**; `-600`==`-max`
  ~1000 px), **plus a Clutha-style vanity redirect** `tasman.recollect.co.nz` → **`heritage.tasmanlibraries.govt.nz`**
  (the og:image and master both live on the vanity host; the uniform 80-rec survey saw og host =
  `heritage.tasmanlibraries.govt.nz` for all 80). Because `recollectOgImageMaster` builds the master URL
  from the **og:image's own host**, it targets the vanity domain automatically — **no new strategy code,
  just a registry entry + weight.** Pixel sample (32): **26 win (median 3.14×, max 15.44×/10 MP)**, 3
  equal (small ≤1000 px native), 3 honest-smaller; og widths min 318 / median 1855 / **max 9803**; master
  JPEG octet-stream/attachment (7/7 magic-checked). CollectionTester ×4 → 3 masters (2.4–4.0 MP) + 1 `-max`
  fallback, all HTTP 200.
  - **★ REQUIRED a shared `fetchHTML` fix (applies to ALL og:image/HTML-scrape strategies):** the vanity
    host **403s any request lacking a browser User-Agent**, and Alamofire/URLSession does **NOT** reliably
    reapply the session-level `httpAdditionalHeaders` User-Agent to the **redirected** request on a
    **cross-host** 301/302 — so `fetchHTML` got the vanity 403 error page (no `og:image`) and the scrape
    silently fell back to the `-600`. Fixed by **also sending the UA as a per-REQUEST header**
    (`session.request(endpoint, headers:)`), which URLSession **does** copy onto the redirected
    `URLRequest`. Additive (a no-op for non-redirecting hosts). ⇒ **Lesson:** any Recollect collection
    whose harvested `*.recollect.co.nz` landing host **cross-host-redirects to a council vanity domain**
    (Clutha 36, Tasman 38) needs the request-header UA to scrape the redirected page; check for a vanity
    redirect (`curl -sIL`) when an og:image scrape mysteriously returns the harvested URL.
  - **★ stale `:7000` recurred & masked the fix** — a leftover Kinder-era lambda held the port
    (`bind … errno 48`), so CollectionTester tested the OLD binary (passthrough). The bundled
    `killProcessOnPort` uses `/usr/bin/lsof` which **does not exist here** (`lsof` is at **`/usr/sbin/lsof`**),
    so its kill silently no-ops. Free `:7000` with `/usr/sbin/lsof -ti :7000 | xargs kill -9` between runs.
- **westernbay.recollect.co.nz (Western Bay Community Archives, order 39, 2026-06-14): TWO-ASSET (no
  vanity redirect), ADD by REUSING `recollectOgImageMaster`.** Same two-asset shape as John Kinder /
  Tasman: harvested thumb asset id is master-less (`downloadwiz/<aid>` 404; `display/<aid>-600`==`-max`
  ~1000 px); node `og:image` → a DIFFERENT primary asset (usually `aid+1`, sometimes a larger gap)
  whose `downloadwiz` master IS present. Uniform survey: live nodes 29/30, og `downloadwiz` 200 =
  **29/29 = 100%** of live nodes; pixel sample (24): **24/24 win (median 11.72×, max 34.57×/~25 MP,
  min 2.74×)**, CollectionTester served up to **8411×6763 ≈ 57 MP**. **No vanity redirect** (nodes +
  `downloadwiz` master served directly on `westernbay.recollect.co.nz`), so the helper is reused
  verbatim — **registry entry + weight only, no new code.**
  - **★ Newer Recollect generation, legacy scheme still works:** the site also exposes
    `assets/pic/<nodeId>` (node-id display image; `-600`/`-max` suffixes ignored), but the legacy
    `assets/display/<assetId>-…` scheme still resolves for ~97% of records, so the harvested baseline
    is mostly live and the two-asset strategy applies unchanged.
  - **★ ~3% stale harvested ids (site migration renumbered):** the most-recent / page-1 harvested
    records 404 — `nodes/view/<nid>` 302s to `/pages/error404` ("Item does not exist") and
    `assets/display/<aid>-600` 404s; DigitalNZ never re-synced them, and id collisions are coincidental
    (live `nodes/view/2633` is a DIFFERENT item than the harvested record that used asset 2633), so there
    is **no reliable old→new mapping**. The error404 page has **no `og:image`**, so `recollectOgImageMaster`
    cleanly falls back to the harvested `url` (itself 404). Additive (Group B) ⇒ not a regression. ⇒
    **Lesson:** don't sample only page 1 — its top records can be disproportionately stale; survey
    uniformly across all pages to get the true stale fraction (page-1-only first sample said ~11%, the
    uniform 30-rec survey said ~3%).
- **fndclibraries.recollect.co.nz (Far North District Libraries Rediscovery, order 41, 2026-06-16):
  TWO-ASSET (no vanity redirect), ADD by REUSING `recollectOgImageMaster`.** 8th
  boutique-mislabel-actually-Recollect, 4th two-asset case. Same shape as John Kinder 37 / Tasman 38 /
  Western Bay 39: the harvested thumb id is mostly master-less (`downloadwiz/<thumbId>` 200 only ~30%,
  `display/<thumbId>-600`==`-max`==`-4000` ~1000 px), while the node `og:image` points to the
  master-bearing primary asset (og id == thumb id for ~30%, differs — usually `+1` or a small offset —
  for ~70%). Uniform survey 2 (60 records): og present **60/60**, og-`downloadwiz` 200 = **59/60 (98%)**,
  pixel **58 win / 1 equal / 0 honest-smaller**, ratio **min 1.0 median 23.4× max 57.6×** (up to
  7590×5042 ≈ 38 MP); CollectionTester ×6 served masters 18.3–29.5 MP. Registry entry + weight only —
  **no new code, no domain-map entry** (`recollectOgImageMaster` uses the og:image's own host), no deploy.
  - **★ UA-gate red herring:** every `assets/…` URL **403s without a browser User-Agent** (118-byte
    stub), and the node `og:image` is `display/<id>-max?u=<32-hex>` — the `?u=` looks like a signed
    token but is **irrelevant** (works with or without it). The real gate is purely the **User-Agent**
    (same as Tasman 38). `fetchHTML` + `headStatusFollowingRedirects` both already send a browser UA,
    and the master is served **directly** (no cross-host redirect), so the session-level UA suffices and
    the helper works unchanged. ⇒ **Lesson:** a Recollect `?u=` query on the og:image is a cache-buster,
    not a path-bound signature — don't mistake it for the Feilding-35 signed-IIIF gate; probe with vs
    without a browser UA before assuming a token is required.
  - **★ ~1.7% stale nodes:** a few records' node `og:image` is the **site logo**
    (`theme/fndclibraries/img/logo.mobile.png`, no `display/<id>`) → `recollectOgImageMaster` cleanly
    falls back to the harvested `-600` (still valid). Additive (Group B) ⇒ not a regression.
  - **★ master header profile = approved precedent:** `application/octet-stream` +
    `Content-Disposition: attachment` + `X-Content-Type-Options: nosniff` is **byte-identical** to the
    already-approved Clutha 36 / Hastings 6 `downloadwiz` masters (renders in `<img>`; direct navigation
    downloads the `.jpg`). The `nosniff` is standard Recollect, not anomalous.
- **rotorua.recollect.co.nz (Pakiaka Rotorua Heritage Online, order 42, 2026-06-16): TWO-ASSET +
  VANITY REDIRECT, ADD by REUSING `recollectOgImageMaster`.** 9th boutique-mislabel-actually-Recollect,
  5th two-asset case, **2nd with a Clutha/Tasman-style vanity redirect**
  `rotorua.recollect.co.nz` → **`pakiaka.rotorualibrary.govt.nz`** (Rotorua Library — Te Aka Mauri). The
  harvested `large_thumbnail_url` is the **small `-280` thumbnail** (≈500 px, 0.17 MP) — note the display
  pyramid here extends **past 1000 px** (`-280` 499×333, `-600` 999×667, `-max` 1845×1232), unlike Far
  North where `-600`==`-max`. The node `og:image` points to the master-bearing primary asset **on the
  vanity host** (og id differs from thumb id for **50/64 ~78%**); `downloadwiz/<ogId>` 200 = **64/64 (100%)**,
  and is **≥ `-max` for every record** (a true larger master for ~40%, up to 6000×4000 = 24 MP; == `-max`
  for ~60%). Pixel (vs the `-280` baseline): **63/64 win, median 11.7×, max 144×**, 1 equal (tiny 380×300
  native), 0 honest-smaller, **0 stale/dead, 0 login-walls**. Registry entry + weight only — **no new code,
  no domain-map entry, no deploy.**
  - **★ Why `recollectOgImageMaster` (not `recollectLargest`):** the harvested thumb id is master-less
    for the two-asset ~78% (`downloadwiz/<thumbId>` 404; verified thumb 11610→404 vs og 12166→200), **and**
    the assets are UA-gated (403 without a browser UA) behind a **cross-host** vanity redirect.
    `recollectOgImageMaster` builds the master URL from the og:image's **own (vanity) host**, so the
    `downloadwiz` HEAD probe is a **direct** request (no cross-host redirect) and the session UA applies.
    `recollectLargest` would both rip the wrong id and have to follow the redirect through the UA-gate.
  - **★ live count drift:** `result_count` is **1,571** vs the progress.json snapshot's 1,374 (the
    collection grew) — `rawItemCount` updated to 1,571. The `?u=<32-hex>` on the og:image is a cache-buster
    (cf. Far North 41), not a signed token.

---

## recollectIIIF (Recollect new-generation signed-IIIF) — same vendor as the `downloadwiz` sites

> **One vendor, two product generations** — NOT two vendors, and **NOT Axiell.** Recollect is made
> by **Recollect Ltd** (spun out of **NZMS — New Zealand Micrographic Services** — in 2019). The
> `recollect` section above is the **older** `*.recollect.co.nz` generation (`/assets/downloadwiz/<id>`
> masters). **This** is the **newer** generation (`recollectcms.com`; cache identifier `curtis-*-cache`,
> e.g. `curtis-production2-cache`): **CloudFront-signed IIIF derivatives + presigned-S3 TIFF originals**.
> The `recollectLargest` / `recollectDisplayMax` family does **NOT** apply here (no `/assets/` paths).

- **Detect:** landing `https://<site>/item/<uuid>`; harvested `large_thumbnail_url` is a **CloudFront IIIF
  derivative**: `https://<dist>.cloudfront.net/iiif/2/<cache-id>%2F…%2Fresize_master_<hash>.jpg/full/!880,1024/0/default.jpg?sig=…&ver=…`.
  OpenSeadragon viewer with a `data-dzi` descriptor on the item page.

### Verified findings (recollectIIIF)
- **www.feildingheritage.nz (Feilding Library, order 35, 2026-06-12):** harvested derivative is confined to
  the site's **`!880,1024` box (≈880×886, 0.78 MP)**. **The CloudFront signature is bound to the EXACT
  derivative path** — mutating `/full/!880,1024/` → `/full/max/` returns **HTTP 403 `SignatureDoesNotMatch`**;
  larger IIIF sizes **cannot be forged**. The site only pre-signs **`{!440,512, !880,1024, !1170,1170}`**;
  `!1170,1170` (≈1163×1170, **1.36 MP**) is the largest displayable JPEG it exposes publicly. ⇒ The IIIF route
  is a hard ceiling at ~1.36 MP.
- **The true original is via the item-page download link, NOT a forgeable URL.** The page HTML contains
  `…/item/<uuid>/files/<fileId>/download?variant=original` (the **`<fileId>` exists ONLY in the page HTML** —
  not derivable from the harvested URL), which **302-redirects to a short-lived (~1 h) presigned S3 URL**
  serving the **original TIFF** (e.g. **4969×5000, ~25 MP, ~75 MB**, RGB uncompressed; the `data-dzi`
  confirms native size). Anonymous for **public-rights** records; restricted/login-walled records have no
  public original.
- **TIFF is undisplayable AND too big for weserv.** Browsers can't render TIFF, and the **~75 MB file 504s
  weserv** → neither a raw URL nor a free proxy works.
- **Recipe that works — reuse the self-hosted Pillow converter (the same Lambda TAPUHI order 25 built for
  JP2), extended to TIFF + a multi-host allowlist.** The Swift Lambda stays a URL-builder; a Feilding-specific
  **`feildingConverter`** strategy does **one bounded HTML GET** of `result.landingUrl`, regexes
  `/item/[0-9a-f-]+/files/[0-9a-f-]+/download\?variant=original`, rebuilds the absolute endpoint from the
  landing scheme+host, and returns `<JP2_CONVERTER_URL>/?url=<endpoint, .alphanumerics-encoded>` (mirrors
  `tapuhiConverter`). The converter **follows the 302 to S3 itself** (only the entry host is allowlisted, which
  is sufficient — the trusted entry host chooses its own asset store), downloads the TIFF, and the **generic
  `convert_to_jpeg` decodes it with NO new code** (the JP2 `image.reduce` branch is skipped for TIFF; RGB
  passes through; `convert("RGB")` covers CMYK/16-bit; the LANCZOS thumbnail ≤4000 px + the <6 MB budget loop
  are shared). **Graceful fallback to the signed `!880,1024` JPEG** on any failure (no landing URL, host
  mismatch, `JP2_CONVERTER_URL` unset, fetch throws, or **no `download?variant=original` link** =
  login-walled). Never weserv, never a raw TIFF.
- **Converter generalization (`app.py` / `template.yaml` / `Dockerfile`):** `ALLOWED_HOST` → multi-host
  **`ALLOWED_HOSTS`** (comma-separated `frozenset`; singular still honoured); `DOWNLOAD_TIMEOUT` env-configurable
  (default 20→**35** s, set to 45 for Feilding); a hard build-time assert **`features.check('libtiff')`** next
  to the `jpg_2000` one; `MAX_DIM` stays 4000. No rename of `Jp2ConverterFunction` / `JP2_CONVERTER_URL`.
- **Verified live** (stack `nzimageapi`, ap-southeast-2, in-place SAM update — 3 `Modify`/0 replace; Function
  URL + API endpoint unchanged): Stanway 1898 **4000×3358 (13.4 MP)** 5.45 s cold (byte-identical to local),
  Macarthur St **4000×3000 (12 MP)**, panorama **4000×1682 (6.7 MP)**, Power Board **3397×1845 (6.3 MP, honest
  native)**; 6/6 local + 4/4 live picks HTTP 200 `image/jpeg`, never upscaled. TAPUHI regression unchanged
  (FL73782300 → 3737×2148, 8.0 MP).
- **Likely reuse — Manawatū Heritage (order 52)** is run by the **same Manawatu District Libraries** and is
  very likely the identical Recollect Ltd signed-IIIF pipeline; **Kete Horowhenua (51)** and other "Heritage"
  todo sites may be too. Reuse = add the landing domain to `ALLOWED_HOSTS` + one registry entry on a shared
  helper (generalize `feildingConverter`). **Confirm per-collection; do not assume.**

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
- **Victoria and Albert Museum (order 43, 2026-06-16): ADD via NEW `vamIIIFLargest` (framemark IIIF).**
  The harvested `large_thumbnail_url` is the V&A's **legacy image host**
  `media.vam.ac.uk/media/thira/collection_images/<batch>/<id>.jpg` — ~640–768 px where present, **404 for
  ~⅓ of records** (host being retired). The V&A's IIIF Image API at `framemark.vam.ac.uk/collections/<id>/`
  serves the same asset, keyed by the **SAME `<id>` == the harvested filename stem** (confirmed via the V&A
  object API `api.vam.ac.uk/v2/object/O<n>` → `meta.images._iiif_image` = `framemark…/collections/<id>/`).
  So the IIIF URL is derivable **purely from the harvested filename** — `vamIIIFLargest` emits
  `framemark.vam.ac.uk/collections/<id>/full/max/0/default.jpg` (pure URL construction, no request-time
  fetch; defensively strips a `_jpg_w` suffix; falls back to the harvested URL if the shape is unexpected).
  - **★ Strict Pareto improvement (head-to-head, 30 recs):** IIIF `/full/max/` vs the harvested media image
    = **win 12 / equal 8 / lose 0** (ratio median 10.6×, max 17.2×), AND it **fixes the ~⅓ dead-media 404s**
    (framemark resolves 100%). Bimodal: ~half the collection has a high-res master → **2500 px** (4.2–4.9 MP);
    ~half are genuinely low-res masters → IIIF returns native ~640–768 px (== the old media, no regression).
  - **★ 2500 px is the hard public ceiling; use `/full/max/` not a fixed width:** info.json profile is IIIF 2
    level1 with `maxWidth`/`maxHeight` = **2500** and `supports: sizeAboveFull` — so a fixed width would
    fake-upscale the small-native records (Kura lesson). Verified: 768-native records return 768 via
    `/full/max/` (not upscaled), and `/full/4000,` on a high-res id **clamps to 2500** (byte-identical to
    `/full/max/`). The presentation manifest (`iiif.vam.ac.uk/collections/O<n>/manifest.json`) exposes
    **nothing larger** than framemark; rights are "© V&A", public delivery capped at 2500. framemark needs
    **no browser UA**. `collectionWeights` 0.001 (564 records). Pure code change (no deploy).

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
- **Te Hikoi Museum (2026-06-12, order 31): MOVE passthrough→`ehiveIIIFLargest`.** account 3278; ~8,690
  records. Was mis-placed in the legacy switch passthrough group (serving `_l` 800 px) — the
  `ehiveIIIFLargest` transform already covers its URL shape (single 32-hex hash, no upscale anomalies).
  **Te Hikoi's IIIF masters are CAPPED at exactly 1000 px** — a 70-record spread is bimodal exact-800 /
  exact-1000 (min 800, max 1000, median 1000), i.e. a **server-side public cap**, not natural original
  sizes. **56/70 (80%) gain 800→1000 (×1.56 area); 14/70 (20%) already ≤800 → native; 0/70 worse or
  failed** (`_l` 200 70/70, IIIF default.jpg 200 70/70). ⇒ a much **smaller** eHive account than
  Mataura/Howick/Portrait Gallery (1000 px cap vs up to ~12–21 MP) — still a strict-safe win. Weight 0.006.
  Committed (see log 031 / progress.json). ⇒ **LESSON: a "boutique"-classified collection can actually be
  live eHive — always check `images.ehive.com` → route via `ehiveIIIFLargest`, never passthrough.** And
  per-account IIIF ceilings vary wildly (some accounts cap public IIIF at 1000 px; the true ≤20 MB original
  stays sign-in-only).
- **Te Toi Uku, Crown Lynn and Clayworks Museum (2026-06-12, order 32): MOVE passthrough→`ehiveIIIFLargest`.**
  account 3384; 8,106 records. **2nd `boutique`-mislabel-actually-eHive in a row** (cf. Te Hikoi 31). Public
  master **capped at 1200 px** (higher than Te Hikoi's 1000): 70-record spread min 793 / max 1200 / median
  1200; **66/70 → 1200 (×2.25 area), 2 → 1000, 2 → ≤800; 68/70 (97%) gain**. Parity: `_l` 200 70/70, IIIF
  200 70/70, **bigger 68 / equal 1 / honest-smaller 1 / failures 0**. The one honest-smaller (`2bfc22a5`,
  793 vs fake-800 `_l`) is the **upscaled-`_l` anomaly** — IIIF serves the real 793 px native
  (honest-native-always). Weight 0.006. Committed (see log 032 / progress.json). ⇒ **eHive accounts each
  set their own public IIIF cap (800 / 1000 / 1200 / full native up to ~21 MP) — always sample the actual
  distribution per account; the transform is identical.**
- **Te Ūaka The Lyttelton Museum (2026-06-12, order 33): Group B ADD via `ehiveIIIFLargest`.** account 5362;
  18,588 records. **3rd `boutique`-mislabel-actually-eHive in a row.** Was **NOT in `collectionWeights`** (a
  recent rebrand of Lyttelton Museum, post-dating the 2024 weights snapshot) → never served; **added** the
  registry entry + a provisional weight **0.009**. **MIXED master distribution** (unlike Te Hikoi's 1000-cap
  / Te Toi Uku's 1200-cap): 120-record full-collection sample = min 800 / max 4000 / median 1000;
  **≤800: 48 (40%, parity), 1000: 54 (45%, ×1.56), 4000/12 MP: 18 (15%, ×25 area)** → 72/120 (60%) gain, 0
  worse, 0 failures. The 4000 px batch (`cpa*` ids) is a **real native master** (info.json pyramid 125→4000,
  `full/full`==`full/max`, `full/6000,` upscales-fake). ⇒ **★ SAMPLING TRAP: a hex-only id regex BIASED the
  sample to the 1000 px newer uploads and MISSED the older non-hex ids (`ji3o28_cpap`, `13jcqnp_97mc`) that
  carry the 4000 px masters.** Always classify eHive ids by the **actual `ehiveIIIFLargest` rule (drop only
  the last `_<size>`)**, never assume a 32-hex id. Committed (see log 033 / progress.json).
- **Wyndham & Districts Historical Museum (2026-06-12, order 34): Group B ADD via `ehiveIIIFLargest`.** account
  3102; 3,937 records. **4th `boutique`-mislabel-actually-eHive in a row** (cf. 31/32/33). Was **NOT in
  `collectionWeights`** → never served; **added** the registry entry + a provisional weight **0.002**.
  Master distribution = **near-uniform 1000 px** (120-record full-collection sample via info.json: min 1000 /
  max 4581 / median 1000): **801–1000: 118 (98%, ×1.56 over the 800 px `_l`), >3000: 2 (~2%)** — plus a
  spread check found a **4242×7065 (~30 MP)** master. Because master **min 1000 > `_l` cap 800**, every IIIF
  `full/full` ≥ `_l`: **0 worse / 0 failures** (no honest-smaller anomaly possible, unlike Te Toi Uku 32). All
  ids are **32-hex** (no non-hex `cpa*` tokens → the order-33 sampling trap didn't recur; still classified by
  the drop-last-`_<size>` rule). **~1.5% (60/3,937) of records are null-image at source** (hard-fail the pick,
  no retry — left as-is, well below South Canterbury 29's ~9%). Committed (see log 034 / progress.json).
- **The University of Waikato Art Collection (2026-06-17, order 44): Group B ADD via `ehiveIIIFLargest`.**
  account 8668; 540 records. **5th `boutique`-mislabel-actually-eHive** (cf. 31/32/33/34). Was **NOT in
  `collectionWeights`** → never served; **added** the registry entry + a provisional weight **0.001** (floor).
  Landing pages `ehive.com/collections/8668/objects/<id>` wire up OpenSeadragon over `iiif.ehive.com`.
  **★ IIIF `/full/full` is NOT rights-gated despite uniform `rights: "All rights reserved"` (license null)** —
  35/35 image-bearing survey records served 200 `image/jpeg` (the rights gate only kills the `_xl`/`_o`
  suffixes; the IIIF master is always public, same as Howick). Uniform 78-record survey (35 image-bearing):
  native vs the 800 px `_l` = **28 win / 0 equal / 7 honest-smaller (~20%)** — eHive **fake-upscaled the `_l`**
  from a smaller real master, IIIF returns the **honest** smaller native (honest-native-always, cf. Te Toi Uku
  32 / Howick 17), area ratio **min 0.200 / median 2.25× / max 95.2×**, biggest native **7803×5202 ≈ 40.6 MP**.
  Ids are 32-hex (drop-last-`_<size>` rule). Committed (see log 044 / progress.json).
  - **★★★ CENSUS TRAP — `category=Images` does NOT guarantee a published image.** **61.5% (332/540) of this
    collection is null-image at source** (`large_thumbnail_url`/`thumbnail_url`/`object_url` all null —
    art-catalogue records with no published image; the per-page empty rate climbs 16% p1 → 86% p3/p5). Those
    picks throw `nullImageOrTitle` in `NZRecordsResult.checkHasTitleAndLargeImage()` → `NZImageApi.image()`
    returns nil → the handler returns **HTTP 400 with no retry loop** (`NZImageApiLambda.handle`). So a high
    null-image rate becomes a **proportional 400 hard-fail rate** (CollectionTester: 5 successes / 11 400s of
    16). This is **pre-existing Lambda behaviour, identical for the baseline** — and the global DigitalNZ
    `category=Images` query must **not** be changed by a one-collection additive step (out of scope). **Always
    census the null-`large_thumbnail_url` rate (all pages, not just p1) for any art/catalogue collection** and
    set a floor weight when it is high. (cf. Wyndham 34 ~1.5%, South Canterbury 29 ~9% — Waikato 44 at 61.5% is
    the worst seen.)

---

## pastPerfect (`*.pastperfectonline.com`)
- **Detect:** host `*.pastperfectonline.com`.
- **Extract:** full-size at `/Media/<UUID>`; record page at `/Webobject/<UUID>`;
  plain GET.
- **Collection:** Waimate Museum and Archives PastPerfect.

### Verified findings (pastPerfect)
- **PastPerfect Online (Waimate 20 = `museum_1110`; South Canterbury Museum 29 = `museum_58`):** the
  harvested `large_thumbnail_url` (`s3.amazonaws.com/pastperfectonline/images/museum_<n>/<dir>/<file>.jpg`)
  **is** the display image, hard-capped at **950 px long side** — the public ceiling. ⇒ **no-improvement /
  passthrough.** No larger anonymous variant: `original/`/`large/`/`<f>_large`/`<f>.tif`/`full/` all 404;
  `<file>-2.jpg` is the same 950 px (alternate view); `/Media/<GUID>` is an **HTML viewer page**, not an
  image; no public IIIF/DZI/zoom. The page's "Original / Original/Copy" strings are **catalog field
  labels**, not a download (the only `…/original/…` URLs are the museum logo under `museumlogos/`).
- **Originals exist but are 403-locked.** The S3 bucket is publicly **listable**: the museum's batch upload
  archives sit at `imageuploads2/<10-digit-zero-padded museum id>/…_Images###.zip` (+ `…Thumbs.zip`) —
  e.g. `imageuploads2/0000000058/` for museum 58 — but GET = **403 AccessDenied** (bucket grants
  `ListBucket`, not `GetObject` on the upload prefix) and they're zip archives (not per-image /
  browser-displayable). Repro copies are the paid museum service, not a Lambda route.
- **Harvest can rot (South Canterbury 29):** ~9 % of `museum_58` records are **dead at source** — the S3
  display + thumb 404 (`NoSuchKey`) and the landing/`Media` viewer reference no image (image removed from
  PastPerfect). Unfixable anonymously; passthrough serves a broken image for those. Worth a quick
  broken-rate sample on any PastPerfect collection (the Lambda has no HEAD-check / retry loop).

---

## vernon (Vernon CMS browser)
- **Detect:** Vernon viewer markup; derivative path token ∈
  nano/tiny/small/medium/large/xlarge/display/thumbnail/original.
- **Extract:** swap the token toward `xlarge`/`original`. Docs:
  vcms-help.vernonsystems.com. Verify at investigation time (ignore stale tags).

### Verified findings (vernon)
- **Canterbury Museum (order 26, 2026-06-10): `collection.canterburymuseum.com` is Vernon CMS**
  (Vernon Systems — the NZ vendor behind eHive; NOT eMuseum, despite the `/objects/<id>` +
  `/records/images/<size>/...` shape resembling it). **Detection trick:** the object landing pages are
  behind an **AWS WAF JavaScript challenge** (HTTP **202**, header `x-amzn-waf-action: challenge`,
  empty body) so the HTML is uncrawlable by curl / the Lambda / the Wayback crawler — but the site's
  **404 page** (any unknown path; not challenged) loads `vernon-common.min.js` + `vernon-shortlist.min.js`
  ⇒ Vernon. Image host is S3+CloudFront: `/records/images/<size>/<numericdir>/<sha1>.jpg`.
- **Token ladder (decoded px on one record):** nano 35 · tiny 75 · small 150 · medium 400 · large 800 ·
  **xlarge ~1000–1200** (200); `display`/`thumbnail`/`original`/`master`/`full`/`zoom`/`xxlarge` →
  **S3 `403 AccessDenied`** (the 403 body is S3 error XML, NOT a real `.dzi`). Uniform across records ⇒
  the cap is **not rights-dependent**. `large` = an 800 px bounding box; `xlarge` = ~1000–1200 px box.
  `xlarge` is **honest** (no upscaling): == `large` when the original ≤ 800 px (~60% of the sample),
  1.5–2.25× area when the original is bigger (~40%).
- **No anonymous route beats `xlarge`:** no public IIIF (`/apis/iiif/*` + `/iiif/*` → uniform Vernon
  404; `/apis/` root 404 — it's Vernon, not eMuseum, so no `/apis/iiif` services), no reachable
  OpenSeadragon/zoom, `object_url` null, Wayback CDX empty (WAF blocks it). The object page's
  "download from Collections Online" control **serves `xlarge`** (user-confirmed in-browser). Originals
  are handled by the museum **Image Service** on request (no price published — an earlier "paid-only"
  inference was withdrawn after checking the page). ⇒ **no-improvement**: the shipped `large→xlarge`
  swap already serves the ceiling.
- **Lesson:** for Vernon CMS instances, `xlarge` is the public ceiling and everything above it 403s;
  detect via the **404 page** Vernon JS bundles when the object pages are WAF-challenged. The naive
  `replacingOccurrences(of:"large",to:"xlarge")` is safe only because the harvested token is always
  `large` (exactly one occurrence; hex SHA-1 path; fixed host) — a token already containing `large`
  (e.g. an input `…/xlarge/…`) would corrupt to `xxlarge`; a segment-scoped `vernonLargest` would be
  more robust if/when these are migrated to the registry (e.g. with Culture Waitaki, order 28).
- **Auckland Art Gallery Toi o Tāmaki (order 27, 2026-06-11): also Vernon CMS**
  (`artgallery-collection.cdn.aucklandunlimited.com/records/images/<size>/<dir>/<sha1>.jpg`), harvested at
  the **`medium`** (400px) token. Shipped `medium→xlarge` already serves **`xlarge` = 1600 px box** (200 for
  18/18; above `xlarge` → 403 uniformly) = the ceiling the gallery's own page displays (its artwork-page
  `zoom_image` is `xlarge`). ⇒ **no-improvement.** Two Vernon-specific lessons here that Canterbury didn't
  show: (1) **AAG runs a *second* CDN host** `artgallery-collection-**api**.cdn…` (the live website's host)
  that exposes an extra **`original` = 3000 px** token — but it is a **disjoint** record set (the SHA-1
  hash is **stable** across hosts, yet the `<dir>` bucket remaps **non-linearly** — 12457→13856 = +1399 but
  646→7620 = +6974 — and the harvested dir+hash 403s on `-api`), `original` is an **unreliable ~4%
  edge-cache lottery** (cold = 403; the gallery never requests it), and it's **not derivable** from the
  harvested URL (would need a per-request artwork-page remap). Not worth it. (2) **eHive ≠ the high-res
  source here:** AAG is on eHive (account 3236, `iiif.ehive.com` live) but its eHive masters are only
  **800×608** — *worse* than the Vernon `xlarge`. So a museum can keep high-res in Vernon CMS while pushing
  only thumbnails to eHive — always measure both. The artwork **id is stable** across the site restructure
  (`/artwork/4166` ↔ `/artwork/4166/<title-slug>`; slug = slugified title, required).
- **Culture Waitaki (order 28, 2026-06-11): also Vernon CMS, a clean clone of Canterbury (26)** —
  `collection.culturewaitaki.org.nz/records/images/<size>/<dir>/<sha1>.jpg` (image host == landing host),
  harvested at **`large`**, object pages `/objects/<id>` **WAF-walled** (202 empty / 403 CloudFront). Ladder
  caps at **`xlarge` = 1200 px box** (above → 403, 14/14); shipped `large→xlarge` already serves it = a real
  **2.25× area** win, honest (masters ≥1200 px). ⇒ **no-improvement.** Unlike AAG (27) there is **no `-api`
  host** (`collection-api…`/`collection.cdn…`/`collection-api.cdn…` all fail to resolve) so no `original`
  route; no public IIIF (`/apis/iiif`+`/iiif` 403 WAF-blocked). **eHive 3011 is dead/migrated:** the Kōtuia
  aggregator org-page-3011 carries only the account *profile* image and links back to this Vernon site — the
  museum moved its collection off eHive onto Vernon, so `ehiveaccountid:3011` is a stale harvest id. Shares
  the legacy `switch` `case` with Canterbury — **both occupants now verified no-improvement**.

---

## Proxy / format toolbox

### weservProxy (images.weserv.nl)
- No resize param = native resolution. **71 MP cap.** ~700 req/3 min.
  `output=webp|jpg`. **Cannot do JP2.** Hotlink bypass + format convert.
- `https://images.weserv.nl/?url=<urlenc-without-scheme-ok>`; add
  `&output=webp` to force WebP.
- **Collections:** Te Papa. ~~Hawke's Bay~~ — moved off weserv (see below; weserv 404s on its CDN).

### Verified findings (Hawke's Bay Knowledge Bank, order 24, 2026-06-07) — `knowledgeBankMaster`
- **The shipped `strip-suffix + weserv` strategy was BROKEN:** **weserv 404s on
  `cdn.knowledgebank.org.nz`** (both the derivative and the original) → HTTP 404 for every record. The
  CDN has **no hotlink protection** (direct GET, no referer → 200) ⇒ serve **direct**, not via weserv.
- **Three CDN tiers** under `cdn.knowledgebank.org.nz/node/<id>/`: `images/<base>-WxH.jpg` (fixed
  derivatives; harvest = ~800 px); `images/<base>.jpg` (a **fixed 1400/1800 px rendition that UPSCALES
  small originals → fake pixels**, e.g. 1800×1689 from a 648×608 master); `master/<OrigCaseName>.jpg`
  (the **true honest native** original, variable size — 648 px up to 10575×7232 = 76.5 MP; published for
  ~half the records, batch-dependent).
- **The master URL must be SCRAPED** from the landing page: its filename keeps the original upload
  casing/name, while the `/images/` name is lowercased OR named after the **node id**
  (`46746-800x538.jpg`) — neither lets you build the master by string-munging. Fetch the landing on the
  **`www`** host (the bare host can return a page without the CDN links). Match: **exactly one
  `/node/<id>/master/…` link → use it** (single-image record, handles the node-id-named case);
  **several → stem-match** the harvested base (case-insensitive; the `/images/` base may carry a trailing
  `-<n>` the master omits).
- **User chose "master-first, 800 px fallback"** (purest honest-native): serve `/master/` when present,
  else the harvested URL — **never** the upscaled `/images/<base>.jpg` rendition. Consistent with the
  Kura 16 / eHive 17 honest-native decisions.

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

### Verified findings (boutique)
- **V.C. Browne & Son (order 30, 2026-06-11): commercial sales site — the public image is WATERMARKED.**
  Own ASP.NET WebForms site (`www.vcbrowne.com`, `Detailprom.aspx?RID=<roll>&PID=<photo>`); harvested
  `large_thumbnail_url` = `…/Images/<album>/<file>.jpg` is the only free image, uniformly **~700–756 px**
  and **watermarked** ("Copyright V.C. Browne & Son", baked into the JPEG — *view the image to check*).
  No-improvement: larger suffixes/dirs/handlers/resize-params all 404 or ignored; `/Images/` not listable;
  `Detail.aspx` (non-`prom`) is an error page; detail page CAPTCHA-gated; Wayback has only `-TH` thumbs;
  clean high-res is the **paid product**. **Lesson:** for a commercial-sales source, *visually inspect* the
  display for a watermark, and don't be fooled by ASP.NET `TextBoxWatermarkBehavior` form-hint strings in
  the HTML (a "watermark" that is *not* an image watermark).

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

#### Resolution (TAPUHI order 25, COMMITTED 2026-06-09) — self-hosted JP2→JPEG converter Lambda
- **The master is JP2 and nothing free converts it.** The TAPUHI 5-step resolves to a multi-MP
  JPEG-2000 FL stream (`DeliveryManagerServlet?dps_pid=FL<n>&dps_func=stream`, `image/jp2`). **weserv
  cannot decode JP2** (404), JP2 is unsupported by ~98% of browsers, and every free/keyless proxy was
  exhausted (thumbnailer DEAD/NXDOMAIN, cloudimg account-locked, Cloudinary demo 401, Photon/imagecdn/
  statically fail; no natlib IIIF; Rosetta ignores scaling). **G's hotlink toolbox does not cover JP2.**
- **Recipe that works:** run a **self-hosted Python + Pillow converter Lambda** (Pillow's manylinux wheel
  bundles OpenJPEG; assert `features.check('jpg_2000')` at image-build time). Container image, arm64,
  behind a **Lambda Function URL**; the Swift Lambda stays a URL-builder and emits
  `<JP2_CONVERTER_URL>/?url=<FL stream percent-encoded with .alphanumerics>`. The converter
  host-allowlists `ndhadeliver.natlib.govt.nz` (SSRF guard; GET only), downloads the JP2, decodes with
  Pillow, **keeps grayscale mode L**, downscales the long side ≤4000px (q85, guard loop q75→≤3000) to
  stay under the **6 MB Function URL base64 cap**, returns `image/jpeg` + `Cache-Control: 1y`.
- **Deploy both functions under one AWS SAM stack** (`template.yaml`): inject the converter URL into the
  Swift function via `!GetAtt Jp2ConverterFunctionUrl.FunctionUrl` (SAM auto-names the URL resource
  `<FunctionLogicalId>Url`). `.alphanumerics` percent-encoding round-trips cleanly through the Function
  URL's URL-decoded `queryStringParameters`.
- **Verified live** (ap-southeast-2): canonical FL73782300 → JPEG 3737×2148 (8.0 MP), random FL73383211 →
  4000×3066 (downscale-capped); renders in **Chrome**; guards 400/403. Graceful fallback to the 700 px
  `NLNZStreamGate` access copy when the resolve throws or `JP2_CONVERTER_URL` is unset.
- **Resolve the FL via the Rosetta METS, NOT the ieViewer HTML (2026-06-09 fix).** The ieViewer page is a
  stateful JS viewer whose HTML omits the FL PIDs for most records → the original DVS+ieViewer scrape only
  produced a converter URL for ~37% of records (rest fell back to 700 px). `…&dps_func=mets` is a
  **stateless GET** listing every file in its own `<mets:amdSec ID="FL<n>-amd">` block with
  `<key id="fileMIMEType">` + `<key id="fileSizeBytes">`. Pick the **largest `image/jp2`** (the `HIGH`
  access rep in `access_storage`); **skip the TIFF preservation masters** in `permanent_storage` (100s of
  MB — blow the converter budget). Over 15 IEs: ieViewer found FL for 1/15, METS had a jp2 for 15/15 →
  deployed hit rate ~37% → **~93%**.
- **Decode a REDUCED JP2 level for big masters.** A 23–60 MB JP2 (48–69 MP) decoded full → **~30 s →
  Lambda timeout/502**. JP2 is wavelet-coded: set Pillow's `image.reduce = n` (a Jpeg2K property; verified
  in Pillow 11.3.0 source) before `load()` to discard `n` resolution levels (each halves dims), sized so
  the long side is still ≥ `MAX_DIM`. Result: same masters decode in **2–5 s**, ~274 MB peak. Pair with a
  raised download cap (110 MB) and a roomier Lambda (2048 MB / 60 s). Memory is NOT the constraint; decode
  is single-threaded so extra CPU is marginal — `reduce` is the real lever.
- **On-demand latency (no caching):** instrumented split ≈ NDHA download + Pillow decode/encode; ~4 s for a
  ~6 MB master, up to ~19 s for a ~64 MB master (download from NDHA's non-CDN Rosetta servlet is ~half of
  it and not under our control). Acceptable for a random-image API (rarely re-serves the same record, so a
  cache would seldom hit).

#### Resolution (War Art Online order 40, COMMITTED 2026-06-14) — NLNZStreamGate-shaped, but a TIFF master DOES exist via METS
- **NLNZStreamGate-shaped ≠ "no master" (refines the National Publicity Studios 03 finding).** War Art
  Online (Archives NZ war paintings) has the **same** `NLNZStreamGate/get?dps_pid=IE<n>` harvest shape as
  National Publicity Studios — but here the Rosetta METS (`…&dps_func=mets`) lists a
  **`PRESERVATION_MASTER` `image/tiff`** FL (`NCWA_*.tif`, 8-bit RGB, ~5000 px, 40–65 MB) in
  `permanent_storage`, and its `…&dps_func=stream` serves the TIFF **anonymously** (HTTP 200 `image/tiff`,
  a direct 200 — no S3 redirect). **Always parse the METS before concluding no-master**, even for the
  NLNZStreamGate shape; National Publicity Studios genuinely had only an access rep, War Art has a real
  master. (National Publicity is still no-improvement; War Art is a ~20× win for ~80 % of records.)
- **Reuse the deployed converter for TIFF — no redeploy.** The converter became a generic JP2 **+ TIFF**
  proxy at Feilding 35 (Pillow + libtiff), and `ndhadeliver.natlib.govt.nz` was already in `ALLOWED_HOSTS`
  (from TAPUHI 25). So War Art is a **pure Swift change**: `warArtConverter` → `resolveWarArtFLStreamURL`
  (IE → METS) → `warArtMasterFLPID` → `<JP2_CONVERTER_URL>/?url=<encoded FL stream>`. TIFF needs **no
  reduced-level trick** (it isn't wavelet-coded like JP2); Pillow decodes + LANCZOS-downscales the
  ~5000 px master to ≤ 4000 px in 5–7 s live (well under the 60 s Lambda timeout).
- **★ The harvested baseline is BIMODAL and you can't pixel-measure it in-Lambda.** `NLNZStreamGate/get`
  returns either a **900 px** access derivative (~80 %, older IE1204… batch) **or an already ~5000 px**
  full-res JPEG (~20 %, newer IE257…/IE807… batches) **or a multi-page `combinedPDF.pdf`** (~1–2 %,
  compilations — not `<img>`-displayable). The Swift Lambda has **no image decoder** (that's the
  converter's job), and there is **no robust METS signal**: `preservationType` is `DERIVATIVE_COPY` for
  **both** the 900 px and 5000 px access tiers, and `techMD tiff:ImageWidth` exists only on the master
  (and is unreliable — 5287/4346 where the file decodes to 5000). **Decide from the access JPEG's
  `fileSizeBytes`** (which exactly equals the served byte length): PDF present → convert the largest TIFF
  page; access JPEG ≥ ~700 KB → passthrough the native ~5000 px baseline (the converter's 4000 px ceiling
  would only shrink it); else → convert the master. The thumbnail-tier (≤ ~660 KB) vs full-tier (≥ ~590 KB)
  byte clusters overlap slightly (the **pixel** gap 1452 ↔ 4347 px is clean, the **byte** gap is not), so a
  few-percent of boundary records render at 4000 px instead of native ~5000 px (or vice-versa) — **always
  graceful, never broken**. (Lesson: an NDHA collection can serve full-res access JPEGs for some
  digitisation batches and 900 px for others — measure the baseline distribution, don't assume 900 px.)
- **Cap the METS picker's byte limit at the converter's download cap (110 MB).** ~1/30 records is a
  **908 MB** TIFF master (an oversized scan); rejecting it in `warArtMasterFLPID` (`size <= maxBytes`)
  makes it fall back to its already-full-res baseline instead of handing the converter a download it would
  502 on. Verified: CollectionTester ×8 = 7 converter + 1 passthrough, all HTTP 200; live converter up to
  12.7 MP (4000×3173) in 5.7–7.3 s; passthrough record native 5000×4745 (23.7 MP).

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
