# 027 — Auckland Art Gallery Toi o Tāmaki

- **Order:** 27
- **Group:** A (re-check an existing Lambda collection)
- **Platform:** Vernon CMS (Vernon Systems) — same derivative ladder as Canterbury Museum (order 26)
- **DigitalNZ result_count (Images):** ~18,214 (rawItemCount in progress.json 18,192)
- **Status:** no-improvement (current `medium→xlarge` swap already serves the public ceiling)
- **Date:** 2026-06-11

## Baseline (what ships today)

Legacy `switch` case in `URLProcessor.swift`:

```swift
case "Auckland Art Gallery Toi o Tāmaki":
    url.absoluteString.replacingOccurrences(of: "medium", with: "xlarge")
```

The harvested `large_thumbnail_url` is the Vernon **`medium`** derivative
(`https://artgallery-collection.cdn.aucklandunlimited.com/records/images/medium/<dir>/<sha1>.jpg`, a
400 px bounding box). The shipped strategy rewrites the size token to **`xlarge`** (a 1600 px box) — so
the Lambda already emits `xlarge`, the largest *reliable public* derivative. **Verified healthy** (NOT
broken): 18/18 uniform-sample records return HTTP 200 at `xlarge`, honest native for the few sub-1600
originals.

## Source site

- Image CDN (harvested host): `https://artgallery-collection.cdn.aucklandunlimited.com/records/images/<size>/<numericdir>/<sha1>.jpg`.
- Live website CDN host: `https://artgallery-collection-api.cdn.aucklandunlimited.com/...` (note the **`-api`**
  infix — a *different* host serving a *different, disjoint* record set; see below).
- Artwork landing pages: `https://www.aucklandartgallery.com/explore/art-and-artists/artwork/<id>/<slug>`
  (Next.js RSC SPA). `object_url` is **null** for all records; `source_url` is the DigitalNZ
  `/records/<id>/source` redirect (now **404** — see Stale-harvest note).
- Also carries `dc_identifier` = the accession number (e.g. `1974/43`) **plus `ehiveaccountid:3236`**.

### Stale-harvest note
The harvested `landing_url` (`/explore-art-and-ideas/artwork/<id>`) and the DigitalNZ `source` redirect
target (`/explore/art-and-artists/artwork/<id>`) **both 404** — AAG restructured its site. The artwork
**id is stable** (harvested `/artwork/4166` ↔ current `/artwork/4166/totaranui-i`); only the path prefix
changed and a **title-slug** was appended (slug required — bare `/artwork/4166` 404s). The image CDN
(`artgallery-collection.cdn`, no `-api`) still serves the harvested `medium`/`large`/`xlarge` (HTTP 200),
so the shipped strategy is unaffected.

## Discovery Playbook (all avenues)

**A. Web research.** `aucklandunlimited.com` CDN with `/records/images/<token>/<dir>/<sha1>.jpg` ⇒ same
**Vernon CMS** derivative ladder as Canterbury (26). AAG also has an **eHive** presence (account 3236) and
a Google-Cultural-Institute presence (noted, not a Lambda route).

**B. Page-source.** The current artwork page (`/artwork/11774/view-at-anamooka`, HTTP 200) is a Next.js
RSC app on the **`-api`** CDN host. It references only `medium` (37×) and `xlarge` (4×); its
**`zoom_image` field is `xlarge`** (1600 px) — i.e. the gallery's own page **never serves `original`**.
No `download` control, no `iiif`, no OpenSeadragon on the AAG page.

**C. Viewers.** No public IIIF/DeepZoom on the AAG site or the `-api` CDN: `iiif/2/records:<dir>/info.json`,
`iiif/<dir>/info.json`, `<original>.jpg/info.json`, `<...>.dzi` → all **403**. The eHive route has
OpenSeadragon + `iiif.ehive.com`, but see E.

**D. URL / token mutation (decisive).** Full Vernon ladder on the **harvested host**
(`artgallery-collection.cdn`, record `12457/e8d58…`):

| token | HTTP | decoded |
|---|---|---|
| nano | 200 | 35×27 |
| tiny | 200 | 75×59 |
| small | 200 | 150×117 |
| medium | 200 | 400×313 |
| large | 200 | 800×625 |
| **xlarge** | **200** | **1600×1251** |
| xxlarge / display / thumbnail / original / master / full / zoom / raw | 403 | S3 AccessDenied |

`xlarge` (1600 px box) is the largest token that returns 200 on the harvested host; everything above is
**403, uniform across 18 records** (not rights-dependent). So the shipped `medium→xlarge` already serves
the harvested host's ceiling.

**E. Alternate host / source.**
- **eHive (account 3236 = AAG):** live IIIF master service exists
  (`iiif.ehive.com/iiif/2/accounts%2f3236%2fobjects%2fimages%2f<id>.tif/...`, OpenSeadragon-wired) — but
  AAG's masters there are only **800×608** (info.json native == the `_l` derivative). **Worse than
  `xlarge`** ⇒ eHive is out (AAG pushed low-res to eHive, keeps high-res in its own Vernon CMS).
- **Live `-api` CDN host** (`artgallery-collection-api.cdn`): exposes an extra **`original`** token =
  **3000 px** box (e.g. Totaranui 13856 → 3000×2345, a genuine HP-Designjet-scanned JPEG; ~3.5× the
  `xlarge` area). **BUT three fatal problems:**
  1. **Disjoint from the harvested host.** The SHA-1 hash is **stable** across hosts, but the `<dir>`
     bucket remaps **non-linearly** (12457→13856 = +1399, 12436→13837 = +1401, **646→7620 = +6974**), and
     the harvested dir+hash returns **403 for every token (incl. `medium`)** on the `-api` host. So
     `original` is **not derivable** from the harvested URL — reaching it needs a **per-request
     artwork-page fetch** (id from harvested landing + slug from title → parse the `-api` `xlarge`/`medium`
     URL → swap to `original` → probe).
  2. **`original` is an unreliable cache-lottery, not a public route.** Measured availability ≈ **4%**:
     `0/21` (historical-works batch), `0/70` (10-keyword batch), `0/7` (gentle single requests **with a
     200 control held throughout** — Goldie, Hodgkins, McCahon, Frizzell, van der Velden, Lindauer all
     403). Only ~4 specific records ever returned 200 (Totaranui 13856; 17335/17716/18596) — almost
     certainly records whose `original` derivative happens to be **edge-cached** (the gallery's own site
     never requests `original`, so it's rarely warm; cold = 403). The same records flip 200↔403. Ruled
     out pure rate-limiting (the 200 control stayed 200 while fresh records stayed 403 in the same gentle
     sequence).
  3. **Not surfaced by the gallery.** Its own pages cap at `xlarge`; `original` is an unintended,
     unstable backend derivative.

**F. Dead/Wayback.** Not pursued — the live CDN serves the harvested `xlarge` fine; the question is only
about *bigger*, and Wayback can't beat a live derivative ladder.

**G. Toolbox.** Not needed: `xlarge` is already a browser-displayable JPEG.

## Measurements

- Harvested host `xlarge` (shipped): **1600 px box**, HTTP 200 for 18/18 (honest native for ~4 sub-1600
  originals, e.g. 397×480, 480×309, 270×480).
- `-api` host `original` (when warm): **3000 px box** (e.g. 3000×2345, 3000×2196) — ~3.5× `xlarge` area —
  but only ~4% of records, unreliably.
- eHive master (account 3236): **800×608** (worse).

## Conclusion

**No-improvement** (user-approved 2026-06-11). The shipped `medium→xlarge` swap already serves the
**reliable public ceiling** the gallery itself displays/zooms to (`xlarge`, 1600 px box). Nothing reliable
beats it:
- the harvested host returns 403 for every token above `xlarge` (18/18, not rights-gated);
- the `-api` host's `original` (3000 px) is a ~4% edge-cache lottery, **not derivable** from the harvested
  URL (non-linear dir remap), requires a fragile per-request artwork-page fetch, and isn't surfaced by the
  gallery's own pages;
- eHive (3236) masters are only 800 px;
- no public IIIF/DeepZoom/zoom anywhere beats `xlarge`.

The strategy is correct and optimal **as shipped**; no code change. Left in the legacy `switch` (precedent:
Canterbury 26 / Tāmiro / Antarctica no-improvement collections stay in the switch).

### Note on the implementation (optional hardening, not required)
`replacingOccurrences(of: "medium", with: "xlarge")` is a global substring replace; safe for AAG (the host
has no "medium", the dir is numeric, the SHA-1 path is hex, the harvested token is always `medium`,
occurring exactly once). A segment-scoped `vernonLargest` (rewrite only the `/records/images/<size>/`
token) would be more robust if/when the Vernon collections (Canterbury 26, Culture Waitaki 28, AAG 27) are
migrated to the registry.

## Follow-up
- If AAG/aucklandunlimited ever surfaces `original` (3000 px) as a stable public derivative (its own pages
  start serving it, or the CDN stops 403-ing cold `original` requests), re-open: a per-request
  artwork-page remap (id stable from harvested landing + slug from title → `-api` `original`, `xlarge`
  fallback) would then be worth ~3.5× area for the open subset.
- The harvested host (`artgallery-collection.cdn`, no `-api`) is the *old* CDN; the live site uses `-api`.
  If DigitalNZ re-harvests, URLs will point at `-api` (still `xlarge` ceiling) — no action needed, but the
  `medium→xlarge` swap remains correct on both hosts.
- eHive (account 3236) only re-becomes relevant if AAG uploads true masters there (currently 800 px).
