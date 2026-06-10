# 026 — Canterbury Museum

- **Order:** 26
- **Group:** A (re-check an existing Lambda collection)
- **Platform:** Vernon CMS (Vernon Systems) — *not* eMuseum (initial hypothesis corrected)
- **DigitalNZ result_count (Images):** ~295,981 (rawItemCount in progress.json 229,481 — DigitalNZ harvest has grown)
- **Status:** no-improvement (current `large→xlarge` swap already serves the public ceiling)
- **Date:** 2026-06-10

## Baseline (what ships today)

Legacy `switch` case in `URLProcessor.swift` (shared with Culture Waitaki):

```swift
case "Canterbury Museum", "Culture Waitaki":
    url.absoluteString.replacingOccurrences(of: "large", with: "xlarge")
```

The harvested `large_thumbnail_url` is the Vernon **`large`** derivative
(`https://collection.canterburymuseum.com/records/images/large/<dir>/<sha1>.jpg`, an 800 px
bounding box). The shipped strategy rewrites the size token to **`xlarge`** (a ~1000–1200 px
box) — so the Lambda already emits `xlarge`, the largest public derivative.

## Source site

- Object landing pages: `https://collection.canterburymuseum.com/objects/<id>`.
- Images: Amazon **S3 + CloudFront**, `https://collection.canterburymuseum.com/records/images/<size>/<numericdir>/<sha1hash>.jpg`.
- `object_url` is **null** for all records; `source_url` is the DigitalNZ `/records/<id>/source` redirect.

### Platform detection
The object pages are behind an **AWS WAF JavaScript challenge** (HTTP **202**, header
`x-amzn-waf-action: challenge`, empty body) — uncrawlable by curl, by the Lambda, and (below)
by the Wayback crawler. The site's **404 page** (served for unknown paths, *not* challenged)
carries `<title>404 - Page Not Found Error - Canterbury Museum</title>` and loads
`…/vernon-common.min.js` + `…/vernon-shortlist.min.js` ⇒ **Vernon CMS / Vernon Systems**
"Collections Online" (the same NZ vendor that runs eHive, but a different product). The earlier
web-research guess of Gallery Systems eMuseum was **wrong**.

## Discovery Playbook (all avenues)

**A. Web research.** Vernon CMS confirmed. The museum's own **Image Service** page
(https://www.canterburymuseum.com/image-service, verified directly 2026-06-10) says digital copies
"can usually be **ordered** from our Image Service" (emailed form) and that "Many photos … **can be
downloaded from Collections Online**." The page publishes **no fee/charge/cost/price wording** —
grepped the full page, none present — so it is NOT stated that originals are paid (an earlier
"paid-only" claim from a web-research subagent was an unverified inference; **withdrawn**). ⚠️ The
"can be downloaded from Collections Online" line implies a **download control on the object page** I
could NOT test (object pages are WAF-walled): it may serve the same `xlarge` or something larger —
an open gap, not a closed door. (The museum *is* on DigitalNZ — the subagent's "not aggregated"
claim was also false; we harvest ~296k records.)

**B. Page-source.** Landing HTML is WAF-challenged (202) → cannot read `og:image`, viewer config,
`data-*`, embedded state. Not scrapeable at request time even if we wanted to.

**C. Viewers.** No public IIIF: `/apis/iiif/image/v2/...`, `/apis/iiif/presentation/v2/...`,
`/iiif/2/...` (tried object-id, media-id `41183`, composite `objects-<id>-media-<id>` identifiers,
v2 + v3) **all return a uniform Vernon 404** (15,364-byte HTML, no WAF). `/apis/` and `/apis/iiif/`
roots also 404 ⇒ eMuseum-style API services are not present (it's Vernon, not eMuseum). No
OpenSeadragon/DeepZoom reachable (the `display`/`zoom` derivatives 403; the object page that would
wire a viewer is WAF-walled).

**D. URL / token mutation (the decisive probe).** Full Vernon size ladder on
`/records/images/<size>/41183/5161db47…f26b85f.jpg`:

| token | HTTP | decoded |
|---|---|---|
| nano | 200 | 35×22 |
| tiny | 200 | 75×48 |
| small | 200 | 150×96 |
| medium | 200 | 400×256 |
| large | 200 | 800×512 |
| **xlarge** | **200** | **1000×640** |
| display | 403 | S3 AccessDenied |
| thumbnail | 403 | S3 AccessDenied |
| original | 403 | S3 AccessDenied |
| master | 403 | S3 AccessDenied |
| full | 403 | S3 AccessDenied |
| zoom | 403 | S3 AccessDenied |
| xxlarge | 403 | S3 AccessDenied |

`xlarge` is the largest token that returns 200; **everything above is S3 `403 AccessDenied`**
(`Content-Type` of the 403 is the S3 error XML — *not* a real DeepZoom `.dzi`). Verified
**uniform across 5 records** (xlarge 200, display/original/xxlarge 403 for every one) ⇒ the cap is
**not rights-dependent**; no record exposes anything larger.

**E. Alternate host/source.** `object_url` null; no alternate hi-res DAMS/CDN; the eHive sibling
sites are *other* Canterbury museums (South Canterbury, Canterbury Photography), not this one.

**F. Dead/Wayback.** Wayback **CDX has zero snapshots** of `collection.canterburymuseum.com/objects*`
(the WAF challenge defeats the archive crawler too) — no archived HTML to mine.

**G. Toolbox.** Not needed: the best source (`xlarge`) is already a browser-displayable JPEG.

## Measurements — `large` vs `xlarge` (uniform sample across pages 1/700/1500/2200/2900)

| record | large | xlarge | area gain |
|---|---|---|---|
| 37794188 | 800×512 | 1000×640 | 1.56× |
| 40344074 | 533×800 | 800×1200 | 2.25× |
| 40941818 | 533×800 | 800×1200 | 2.25× |
| 40943540 | 757×800 | 1067×1127 | 1.99× |
| 40934388 | 427×562 | 427×562 | 1.00× |
| 40934396 | 383×486 | 383×486 | 1.00× |
| 40934870 | 387×504 | 387×504 | 1.00× |
| 40934908 | 354×491 | 354×491 | 1.00× |
| 40941828 | 197×233 | 197×233 | 1.00× |
| 40943550 | 686×515 | 686×515 | 1.00× |

- `large` = 800 px bounding box; `xlarge` = ~1000–1200 px bounding box.
- For originals **bigger than 800 px** (~40% of the sample) `xlarge` is a real **1.5–2.25×** area win.
- For originals **≤ 800 px** (~60%) `xlarge` == `large` (honest native, **no upscaling, no regression**).
- All 10 harvested URLs were the `/records/images/large/…` form ⇒ the `large→xlarge` rewrite applies
  uniformly.

## Conclusion

**No-improvement.** The current shipped `large→xlarge` swap already serves the largest derivative the
public site offers. **User confirmed in-browser (2026-06-10): the object page's "download from
Collections Online" control serves `xlarge` as the highest** — so the one route I couldn't test
(WAF-walled) yields nothing larger; `xlarge` (~1000–1200 px box) is the genuine public ceiling. No
larger URL can be built or reached at request time either: `display`/`original`/`master`/`full`/
`xxlarge` are all S3 403, there is no public IIIF/zoom, and the object landing is AWS-WAF-walled. The
Image Service fulfils manual requests (no price published) but that is not a Lambda-constructable
route. The strategy is correct and optimal **as shipped**; no code change.

### Note on the implementation (optional hardening, not required)
`replacingOccurrences(of: "large", with: "xlarge")` is a global substring replace. For Canterbury it
is safe (the host has no "large"; the SHA-1 path segment is hex; the harvested token is always
`large`, occurring exactly once). It would mis-fire only if the input were *already* `…/xlarge/…`
(→ `xxlarge`), which never occurs for the harvested `large` URL. Left as-is (consistent with leaving
other no-improvement Group-A collections in the legacy `switch`); could later migrate to a registry
`vernonLargest` that rewrites only the `/records/images/<size>/` segment when Culture Waitaki (order
28, same case) is processed.

## Follow-up
- The object page's "download from Collections Online" control was **confirmed (user, in-browser
  2026-06-10) to serve `xlarge`** — no larger file there. The Image Service fulfils manual requests
  (no price published); not a Lambda route.
- Re-check only if Canterbury Museum exposes a public IIIF endpoint or removes the > `xlarge` 403 cap.
- `xlarge` is not an upscale (Vernon serves honest native for small originals), so no quality concern.
</content>
</invoke>
