# 049 — Picture Wairarapa

- **Group:** B (add, not currently in the Lambda)
- **Platform:** **Spydus / Civica** (integrated library system, ILS) — new platform for this sweep,
  used by content partner "Wairarapa Archive"; front-end `masterton.spydus.co.nz`; images on Azure
  Blob Storage `stspydusproduction.blob.core.windows.net/smartlive-mp-pub/`
- **DigitalNZ result_count:** 26,313 image-bearing (live, 2026-07-04; `rawItemCount` snapshot 25,949)
- **Timestamp:** 2026-07-04
- **Outcome:** **no-improvement, NOT added.** Harvested `large_thumbnail_url` (**360×226, ≈0.08 MP**)
  is the platform's hard ceiling — no anonymous route to anything larger exists. User decision
  (after a deep-dig pass): do not add to `collectionWeights` — 0.08 MP would be a clear quality
  outlier vs. every other served collection (next-lowest ~700–950 px long side). No code change.

## Raw record sample (key redacted)

| field | value |
|-------|-------|
| large_thumbnail_url | `https://stspydusproduction.blob.core.windows.net/smartlive-mp-pub/<uuid>_lt.jpg` |
| thumbnail_url | same URL (identical to large_thumbnail_url in the harvested record) |
| landing_url | `https://masterton.spydus.co.nz/cgi-bin/spydus.exe/ENQ/OPAC/ARCENQ?SETLVL=&RNI=<id>` |
| content_partner | Wairarapa Archive |
| rights | "Some rights reserved" — no copyright restrictions per the archive, but explicitly:
  *"For higher resolution copies of these images and to discuss their further use please contact
  us."* |

Blob naming: `<uuid>_lt.jpg` = "large thumb" (360×226), `<uuid>_t.jpg` = "thumb" (120×75). Only
these two derivatives are ever referenced anywhere on the site.

## Current production strategy (baseline)

Not currently served — Picture Wairarapa is not in `NZImageApi.collectionWeights`.

## Live site investigation (Discovery Playbook)

- **Direct blob probing:** every plausible larger-derivative suffix on the same blob path
  (`_sm/_md/_lg/_full/_orig/_original/_hr/_hires/_xl/_thumb/_large/_medium/_small/_print`, and no
  suffix at all) → **404**. Only `_lt.jpg` and `_t.jpg` resolve.
- **No public container listing:** `?restype=container&comp=list` on `smartlive-mp-pub` →
  `ResourceNotFound` (anonymous listing disabled).
- **No alternate containers on the same storage account:** guessed `smartlive-mp-priv`,
  `smartlive-hr-pub`, `smartlive-archive-pub`, `smartlive-full-pub`, `smartlive-mp-hr` → all
  **404** for the same blob name.
- **No EXIF/embedded larger original:** the `_lt.jpg` has only bare JFIF metadata (no EXIF, no
  embedded thumbnail, no Photoshop/Adobe markers) — `sips -g all` shows nothing beyond
  dimensions/DPI/color profile.
- **Front-end JS confirms the ceiling client-side too.** The catalogue's own
  `docs/OPAC/js/tabContainer.js` (`loadImages()`) reads the `data-imgurls` attribute on
  `img.imgsc` — a `**`-delimited list that is **always exactly**
  `<uuid>_lt.jpg**<uuid>_t.jpg**` (large-thumb first, thumb as the image-load-error fallback).
  There is no third, larger entry anywhere in this list for any record inspected. No
  zoom/lightbox/carousel/OpenSeadragon/IIIF code exists in any of the page's loaded scripts
  (`spydus.js`, `enrich.js`, `gq.js`, `modal.js`, `searchAutoComplete.js`, `modernizr-spydus.js`,
  `cookie.js` — all fetched and grepped).
- **The `imagebrowser` REST API is a dead end.** `masterton.spydus.co.nz/api/maintenance/1.0/
  imagebrowser/image?blobName=<uuid>_lt.jpg` returns **302** to
  `.../smartlive-mp-pub/filemanager/root/<uuid>_lt.jpg` — but that `filemanager/root/` path is
  itself **404** (`The specified blob does not exist`) on the blob store. This API appears to be a
  staff/admin file-manager helper unrelated to the public picture-archive derivatives, and does
  not expose anything larger even when followed.
- **Public Spydus/Civica API docs found (a different library instance, Salford UK,
  `salfordlibraries.spydus.co.uk`)** do not document any image-size or media-derivative endpoint
  for the picture-archive module — this appears to be a per-library custom module, not a
  documented, generally-invokable API.
- **The landing page has an explicit "Place archival request" link**
  (`.../ENQ/OPAC/ARCOPT/<n>/<n>/ARQ&FRMTYP=ARQ`) — a manual enquiry form, confirming higher-res
  copies are a **human request process**, not an anonymous download route (matches the rights
  text verbatim).
- **No Wayback Machine angle needed/useful** — the blob storage is the same live host either way;
  there is no separate historical derivative to check.

## Decision

**no-improvement; NOT added.** Exhausted every anonymous route this sweep normally checks
(derivative-name guesses, container guesses, EXIF, page JS, the site's own REST API, published
vendor API docs, Wayback) and every one confirms 360×226 is the absolute ceiling — the platform's
"large thumb" is the only publicly servable image, and the site itself directs users to a manual
request process for anything bigger. Given this Lambda's next-lowest served resolution is
~700–950 px long side (Waimate 20 / South Canterbury 29 / V.C. Browne 30), adding a 360×226
source would make Picture Wairarapa a clear quality outlier. **User decision (2026-07-04): do not
add to `collectionWeights`.** `platform` corrected `boutique` → `spydus` for future reference; no
Swift change.

## Implementation

None (no code change; not added to the Lambda).

## Verification

N/A — no code change to verify. Confirmed via direct curl/HEAD probing that `_lt.jpg` is 200
JPEG 360×226 and every larger-derivative guess is 404.

## Notes for future Spydus/Civica collections

No other collection in the remaining worklist (50 Te Ara, 51 Kete Horowhenua, 52 Manawatū
Heritage) is currently believed to be on Spydus — this platform is not expected to recur in this
sweep, but if it does: the `_lt`/`_t` two-tier ladder, the disabled container listing, and the
"Place archival request" manual-process pattern are all platform-level Spydus/Civica picture-
archive facts, not Wairarapa-specific ones — check them first before re-investigating from
scratch.

## Commit

(recorded after this bookkeeping commit — no code change, no separate strategy commit needed)
