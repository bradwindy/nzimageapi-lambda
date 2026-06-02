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
- _(append per-domain measured facts here as collections are processed)_

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
- _(append here)_

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
- _(append here)_

---

## ehiveIIIF (NZMuseums / eHive)
- **Detect:** `nzmuseums.co.nz` / `ehive.com` hosts.
- **Extract:** public derivatives often capped ~800×800 unless public-domain. Look
  for IIIF `info.json` / pan-zoom for full res; eHive also has a public REST API
  (developers.ehive.com) and rights-gated full-size. Explore all routes.
- **Collections:** Howick Historical Village, Mataura Museum, NZ Portrait Gallery.

### Verified findings (ehiveIIIF)
- _(append here)_

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

### cloudimgFullRes (cloudimg.io v7)
- Native-res hotlink/format proxy. Use `org_if_sml=1`, **drop fixed `height=`**.
  `force_format=jpeg` to normalize. Good for JP2 (unlike weserv).

### thumbnailerProxy (thumbnailer.digitalnz.org)
- `https://thumbnailer.digitalnz.org/?format=jpeg&src=<urlenc>`.
- **Collection:** Auckland Libraries Heritage.

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

### Verified findings (aklMuseumCloudimg)
- _(append here)_

---

## tapuhi (NDHA natlib)
- 5-step: IE PID → DVS session → FL PIDs → HEAD each for largest → output via proxy.
- **Risk:** weserv cannot do JP2 — if the FL stream is JP2, verify weserv actually
  returns an image; if not, switch to cloudimg `force_format=jpeg` or a natlib
  JPEG derivative.

### Verified findings (tapuhi)
- _(append here)_

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
