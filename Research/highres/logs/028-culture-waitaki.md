# 028 — Culture Waitaki

- **Order:** 28
- **Group:** A (re-check an existing Lambda collection)
- **Platform:** Vernon CMS (Vernon Systems) — a structural clone of Canterbury Museum (order 26)
- **DigitalNZ result_count (Images):** ~9,184 (rawItemCount in progress.json 8,309)
- **Status:** no-improvement (current `large→xlarge` swap already serves the public ceiling)
- **Date:** 2026-06-11

## Baseline (what ships today)

Legacy `switch` case in `URLProcessor.swift`, **shared with Canterbury Museum (26)**:

```swift
case "Canterbury Museum", "Culture Waitaki":
    url.absoluteString.replacingOccurrences(of: "large", with: "xlarge")
```

The harvested `large_thumbnail_url` is the Vernon **`large`** derivative
(`https://collection.culturewaitaki.org.nz/records/images/large/<dir>/<sha1>.jpg`, an 800 px bounding
box). The shipped strategy rewrites the size token to **`xlarge`** (a 1200 px box) — a genuine **2.25×
area** win (verified 14/14), and the Vernon public ceiling.

## Source site

- Image host (== landing host): `https://collection.culturewaitaki.org.nz/records/images/<size>/<dir>/<sha1>.jpg`
  (Amazon S3 + **CloudFront**).
- Object landing pages: `https://collection.culturewaitaki.org.nz/objects/<id>` — **AWS-WAF-walled**
  (HTTP **202** empty body, or **403** `server: CloudFront` — uncrawlable by curl/Lambda).
- `object_url` null; `dc_identifier` carries `ehiveaccountid:3011` + the accession (e.g. `70P`).

## Discovery Playbook (all avenues)

**A. Web research.** `aucklandunlimited`-style Vernon CDN path (`/records/images/<token>/<dir>/<sha1>.jpg`)
⇒ **Vernon CMS**, same as Canterbury (26). eHive account = **3011** = *Te Whare Taoka o Waitaki / Waitaki
Museum & Archive* (small district museum, Oamaru/North Otago).

**B. Page-source.** Object pages are **WAF-walled** (202 empty / 403 CloudFront) — no `og:image`, viewer
config, or embedded image URLs readable at request time (same as Canterbury).

**C. Viewers.** No public IIIF/zoom reachable: `/apis/iiif/...`, `/iiif/2/...`, `/apis/iiif` all **403**
(CloudFront WAF blocks the HTML/API paths; the `/records/images/` derivative paths are NOT WAF-blocked and
serve 200). No OpenSeadragon/DeepZoom obtainable (the object page that would wire it is WAF-walled).

**D. URL / token mutation (decisive).** Full Vernon ladder on record `49/6dfc24b3…`:

| token | HTTP | decoded |
|---|---|---|
| nano | 200 | 35×25 |
| tiny | 200 | 75×54 |
| small | 200 | 150×107 |
| medium | 200 | 400×286 |
| large | 200 | 800×572 |
| **xlarge** | **200** | **1200×857** |
| xxlarge / display / thumbnail / original / master / full / zoom / raw | 403 | — |

`xlarge` (1200 px box) is the largest token that returns 200; everything above is **403, uniform across
14 records**. So the shipped `large→xlarge` already serves the ceiling.

**E. Alternate host/source.**
- **No second `-api` CDN host** (unlike AAG order 27): `collection-api.culturewaitaki.org.nz`,
  `collection.cdn.culturewaitaki.org.nz`, `collection-api.cdn.culturewaitaki.org.nz` all **fail to
  resolve (000)**. So there is no `original`-exposing parallel host here.
- **eHive (account 3011) is dead/migrated.** The Kōtuia aggregator org-page-3011 carries only the account
  **profile/logo** image (`images.ehive.com/accounts/3011/profiles/images/…_l.jpg`) and links to the
  Vernon site (`collection.culturewaitaki.org.nz/explore`) — **no eHive object pages / object masters**.
  Culture Waitaki migrated its collection from eHive to Vernon CMS; `ehiveaccountid:3011` is a legacy
  harvest identifier. (Even live, a district-museum eHive master ≤ 800 px would be *worse* than the 1200 px
  `xlarge`, and unmappable from the WAF-walled Vernon records — cf. AAG 27, where eHive 3236 masters were
  only 800 px.)

**F. Dead/Wayback.** Not pursued — the live derivative ladder serves `xlarge` fine; the only question is
*bigger*, which Wayback can't beat (and the WAF defeats its crawler anyway).

**G. Toolbox.** Not needed: `xlarge` is already a browser-displayable JPEG.

## Measurements — `large` vs `xlarge` (uniform sample, pages 1/80/160/240/320/400/460)

All 14 sampled records: harvested host `collection.culturewaitaki.org.nz`, harvested token `large`
(uniform). `large` = 800 px box → `xlarge` = **1200 px box** (exactly 1.5× both dims ⇒ **2.25× area**),
`original` = **403** for every record. The consistent 1.5× (no honest-smaller cases in this sample) means
the masters are ≥ 1200 px, so `xlarge` is honest native-or-downscale (Vernon never upscales — cf. AAG/
Canterbury where sub-ceiling originals returned honest-smaller `xlarge`).

## Conclusion

**No-improvement** (user-approved 2026-06-11). The shipped `large→xlarge` swap already serves the Vernon
public ceiling (`xlarge`, 1200 px box) — a real 2.25× area win over the harvested `large`. Nothing beats
it: `original`/everything above `xlarge` is 403 (14/14), there is **no `-api` host**, **no public IIIF/
zoom** (WAF-blocked), the object pages are AWS-WAF-walled, and **eHive 3011 has migrated to this very
Vernon site** (only a profile image remains). The strategy is correct and optimal **as shipped**; no code
change. Left in the legacy `switch` (precedent: Canterbury 26 / Tāmiro / Antarctica no-improvement
collections stay in the switch).

### Note on the shared `case` (Canterbury 26 + Culture Waitaki 28)
Both occupants of `case "Canterbury Museum", "Culture Waitaki":` are now **verified no-improvement**. The
global `replacingOccurrences(of: "large", with: "xlarge")` is safe for both (the token `large` occurs
exactly once — the host has no "large", the dir is numeric, the SHA-1 path is hex which cannot contain
`l`/`r`/`g`). A segment-scoped `vernonLargest` (rewrite only the `/records/images/<size>/` token) would be
marginally more robust and would advance the sweep's switch→registry migration, but it is **zero behavior
change**; left in the switch per the no-improvement precedent (user chose this 2026-06-11).

## Follow-up
- Re-open only if Culture Waitaki exposes a public IIIF/zoom endpoint, adds an `-api` host serving
  `original`, or removes the >`xlarge` 403 cap.
- `xlarge` is honest (Vernon serves native for small originals), so no quality concern.
