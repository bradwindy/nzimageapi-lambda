# 001 — Tauranga City Libraries Other Collection

- **Group:** A (re-check, already in Lambda)
- **Platform:** recollect (Axiell Recollect) — `paekoroki.tauranga.govt.nz`
- **DigitalNZ result_count:** 65,285 (live)
- **Timestamp:** 2026-06-02

## Raw record sample (key redacted)

```
GET https://api.digitalnz.org/records.json?and[category][]=Images
    &and[primary_collection][]=Tauranga City Libraries Other Collection
    &per_page=...  (Header: Authentication-Token: $DIGITALNZ_API_KEY)
```

| field | value |
|-------|-------|
| large_thumbnail_url | `https://paekoroki.tauranga.govt.nz/assets/display/106647-600` |
| thumbnail_url | `https://paekoroki.tauranga.govt.nz/assets/display/106647-280` |
| landing_url | `https://paekoroki.tauranga.govt.nz/nodes/view/46242` |
| object_url | `null` |

All sampled records: host `paekoroki.tauranga.govt.nz`, `large_thumbnail_url` always
`/assets/display/<assetId>-600` (20/20 consistent).

## Live site investigation (Discovery Playbook)

- **Platform detection:** landing HTML contains `recollect` ×10, footer "RECOLLECT ©
  Recollect Limited"; asset paths `/assets/display/<id>-<token>`, `/nodes/view/<node>`.
  Confirmed Axiell Recollect.
- **og:image:** landing page exposes `og:image = /assets/display/<id>-max?u=<sig>` with
  `og:image:width=5000`, `og:image:height=4982` — i.e. the metadata advertises the
  TRUE original dimensions, but the served `-max` derivative is capped (~1000 px).
- **No zoom viewer:** no OpenSeadragon / Mirador / IIIF / DeepZoom / Zoomify signals →
  no tiled source larger than the master.
- **Master endpoint:** `/assets/downloadwiz/<id>` serves the original master
  (`Content-Disposition: attachment; filename="...tif.jpg"`, `application/octet-stream`,
  `X-Content-Type-Options: nosniff`). The bytes are JPEG (`file` → "JPEG image data").
- **Display tokens are capped:** for a record with no master, `-600`, `-max`, `-1200`,
  `-1600`, `-2000`, `-3000`, `-4000` all return the SAME image (e.g. 999×1491). So
  `-max` is the true ceiling of the display pyramid; bigger tokens do not help.

### Three record categories (representative random sample, n=16+)
| category | signal | best available | ~share |
|----------|--------|----------------|--------|
| CAT1 master | `downloadwiz` HEAD(follow) = **200** | `downloadwiz` master ~4600–5200 px | ~63% |
| CAT2 no master | `downloadwiz` 302 → "goDownload failed" | `-max` ~1000–1500 px | ~31% |
| CAT3 dead | `-600`/`-max` 302 → "Requested Asset does not exist" | nothing (source deleted) | ~6% |

## Candidate measurements (decoded pixels)

Asset 106647 (CAT1):

| label | URL pattern | decoded WxH | bytes | content-type | notes |
|-------|-------------|-------------|-------|--------------|-------|
| baseline downloadwiz | `…/assets/downloadwiz/106647` | **5000×4982** | 7,995,664 | application/octet-stream | JPEG master; attachment |
| display -max | `…/assets/display/106647-max` | 1000×996 | 135,975 | image/jpeg | capped |
| display -600 | `…/assets/display/106647-600` | 1000×996 | 135,975 | image/jpeg | identical to -max |

Other CAT1 masters measured: 5000×4997, 5000×4991, 4771×4737, 5000×3305, 4622×4500,
5194×3208, 4991×5000, 4737×7142 (15–36 MP). CAT2 `-max`: 999×1491, 1000×998, 999×672, etc.

weserv / cloudimg / thumbnailer proxies of the master all **fail** (paekoroki returns
403 to their server-side fetch; hotlink-protected). A `Range` header makes the master
302-redirect, so range-probing is unusable. ⇒ the master can only be delivered as the
raw `downloadwiz` URL (octet-stream, downloadable). User confirmed: download is fine for
their uses, no inline proxy needed.

## Decision

**Winner: per-record max** = `downloadwiz` master when it exists (HEAD-following-redirects
== 200), else `-max`.

- vs baseline (always `downloadwiz`): **strict improvement.** Baseline serves the master
  for CAT1 but a broken 404 HTML error page for CAT2+CAT3 (~37% of records). New strategy
  keeps the full master on CAT1 and serves a working ~1 MP `-max` on CAT2 (fixes ~31%).
  CAT3 (~6%) is genuinely deleted at source and unfixable (both old and new break).
- The CAT1↔CAT2 split is decided per-request with one light HEAD on `downloadwiz`
  (follows redirects; 200 ⟺ master present). No full-image download at request time.

## Implementation

- `URLProcessor.recollectLargest(_:_:)` — new shared Recollect platform function:
  rip `<id>` from `…/display/<id>-…`, build `downloadwiz` + `-max`, HEAD-probe the
  master, return the master on 200 else `-max`. Guards all optionals → falls back to the
  original URL.
- `NetworkRequestManager.headStatusFollowingRedirects(_:)` — new helper (Alamofire HEAD,
  follows redirects, returns final status; HEAD = no body, cheap).
- Registry: added `"Tauranga City Libraries Other Collection" → recollectLargest`; removed
  it from the legacy `switch` case (Tāmiro / He Purapura still there for now).

## Verification

`swift build` exit 0. `CollectionTester "Tauranga City Libraries Other Collection"` run 8×
(fresh server each run): **8/8 HTTP 200**, every URL a valid JPEG. Masters 4737×7142,
5194×3208, 5000×4991, 4991×5000, 5000×3305 …; `-max` fallbacks 1000×1007, 999×678,
999×1003. Debug-logged probe confirmed downloadwiz status 200⟺master, 404⟺fallback.

> Gotcha (cost hours): a stale lambda left listening on :7000 made `CollectionTester`
> silently test an OLD binary ("Address already in use" on the new server). Always
> `lsof -ti :7000 | xargs kill -9` between runs.

## Commit

Pending user approval (loop Step 7).
