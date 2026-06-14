# 002 — Antarctica NZ Digital Asset Manager

- **Group:** A (re-check, already in Lambda)
- **Platform:** recollect (Recollect — Recollect Ltd / NZMS, NOT Axiell) — asset host `antarctica.recollect.co.nz`,
  canonical host `adam.antarcticanz.govt.nz` (ADAM = Antarctica Digital Asset Manager)
- **DigitalNZ result_count:** 59,372 (live)
- **Timestamp:** 2026-06-02
- **Outcome:** **no-improvement** — baseline already serves the maximum
  anonymously-available resolution; no code change.

## Raw record sample (key redacted)

```
GET https://api.digitalnz.org/records.json?and[category][]=Images
    &and[primary_collection][]=Antarctica NZ Digital Asset Manager
    &per_page=20  (Header: Authentication-Token: $DIGITALNZ_API_KEY)
```

| field | value |
|-------|-------|
| large_thumbnail_url | `http://antarctica.recollect.co.nz/assets/display/108293-600` |
| thumbnail_url | `http://antarctica.recollect.co.nz/assets/display/108293-280` |
| landing_url | `https://adam.antarcticanz.govt.nz/nodes/view/4066` |
| object_url | `null` |
| source_url | `http://api.digitalnz.org/records/38627818/source` (→ redirects to landing page, not an image) |

All sampled records: asset host `antarctica.recollect.co.nz` (301/302-redirects to canonical
`adam.antarcticanz.govt.nz`), `large_thumbnail_url` always `/assets/display/<assetId>-600`.
Note: `landing_url` carries a **node id** (`/nodes/view/<node>`) distinct from the **asset id**
in the image URL.

## Live site investigation (Discovery Playbook)

- **Platform detection:** landing HTML contains `recollect` ×15; asset paths
  `/assets/display/<id>-<token>`, `/nodes/view/<node>`. Confirmed Recollect (Recollect Ltd / NZMS, NOT Axiell).
- **No zoom viewer:** no OpenSeadragon / Mirador / IIIF / DeepZoom / Zoomify signals → no
  tiled source larger than the display derivative.
- **og:image:** landing exposes `og:image = /assets/display/<id>-max?u=<sig>` advertising the
  TRUE original dims (`og:image:width=3196`, `og:image:height=2152` for asset 108293) — but the
  served `-max` derivative is capped at ~1000 px width.
- **Master endpoint disabled:** `/assets/downloadwiz/<assetId>` 302-redirects to a Recollect
  error page (`/pages/error404/…/m:676f446f776e6c6f6164206661696c6564` = base64 "goDownload
  failed"), final HTTP **404**. Tested **184 random records across 23 pages spanning the whole
  59k collection → 184/184 returned 404.** Adding the `?u=<sig>` token did not change this.
- **Download dialog:** landing page "Download" button → `/nodes/download/<node>` (class
  `download downloadwiz`). That URL returns a 13 KB JS-driven HTML dialog (no static links / no
  size options); its download action calls `downloadwiz`, which fails as above. No anonymous
  master route.
- **Display pyramid is hard-capped at width ~1000:** for asset 108293, tokens
  `-1000/-1200/-1600/-2000/-2400/-3000/-3196/-4000` (with or without `?u=` signature) ALL return
  the byte-identical 999×673 image. `-original/-full/-orig/-master` → 404. Alternate endpoints
  `/assets/{download,original,file,fullsize,master,downloadoriginal}/<id>` → all 404.
- **DigitalNZ `source_url`** (`/records/<id>/source`) just 302-redirects to the landing page —
  not a direct image.
- **Web research:** "goDownload failed" is a Recollect-internal message meaning the download
  could not be generated (no retained/served original); no documented anonymous workaround.

### Size ladder (decoded pixels)
| token | example dims | notes |
|-------|--------------|-------|
| `-280` (thumbnail) | 499×336 | small derivative |
| `-600` (large_thumbnail_url = **baseline**) | 999×673 | display tier |
| `-max` | 999×673 | **byte-identical to `-600`** (same file) |
| `-1000`…`-4000` | 999×673 | identical to `-max` (clamped) |
| `downloadwiz` master | — | **404 for 184/184 records** |

## Candidate measurements (decoded pixels)

`-max` across records (representative): 108293 999×673, 108295 1000×665, 108312 1000×665,
108322 999×664, 108393 999×662, 108413 999×672, 104132 999×666, 195894 1000×1071,
75372 999×677, 86348 999×665, 90644 999×700, 88851 1000×672, 112305 1000×1482.
Width is uniformly capped at ~1000 px; portrait images may exceed 1000 px tall (the cap is on
width). `-600` was byte-identical to `-max` in every record measured.

## Decision

**no-improvement.** The baseline (passthrough of `large_thumbnail_url` = `…/display/<id>-600`)
already delivers the maximum resolution Antarctica's Recollect serves anonymously (~1000 px-wide
display derivative). `-max` is the same file (no gain). The full ~3196 px original exists
server-side (per og metadata) but is not served by any anonymous route: `downloadwiz` is disabled
(404 for 184/184), all larger display tokens clamp to the same ~1000 px file, and no
alternate/original endpoint exists. No higher-res route found after exhausting the Discovery
Playbook (token ladder, `?u=` signature, alternate endpoints, download dialog, source_url, web
research). → No Swift change; Antarctica stays in the existing passthrough path.

## Implementation

None (no code change). Antarctica remains in the legacy `switch` passthrough group in
`URLProcessor.getLargerImage`. It will move to a registry `passthrough` entry only in the final
cleanup commit (behavior-preserving), if at all.

## Verification

No code change to verify. Baseline behaviour confirmed live: `…/display/<id>-600` returns HTTP
200 `image/jpeg`, decoded ~1000 px wide — identical to `-max`. (Existing production output is
unchanged.)

## Addendum (2026-06-02) — og:image two-asset re-check (prompted by NAM, order 4)

National Army Museum (order 4) revealed a Recollect pattern where the DigitalNZ `large_thumbnail`
id is a master-less thumbnail while the landing `og:image` points to a *different* primary asset
that DOES have a `downloadwiz` master. Re-checked Antarctica for the same escape hatch: sampled 36
records across 9 pages, comparing the large_thumbnail asset id vs the landing `og:image` asset id
and probing `downloadwiz` on both.

**Result: 36/36 had og:image id == large_thumbnail id (no second asset), and `downloadwiz` 404 on
BOTH ids.** So the NAM trick does not apply — Antarctica genuinely serves no master under any id.
no-improvement stands; the `downloadwiz` re-enable email remains the only path to higher res.

## Follow-up (re-check trigger)

The user (collection rights-holder) has **emailed Antarctica NZ to ask them to re-enable
downloads** for ADAM. If they re-enable `downloadwiz` masters, this collection becomes a
Tauranga-style win (apply `recollectLargest` with domain `adam.antarcticanz.govt.nz`, mapping the
**asset id** from `large_thumbnail_url`). Re-run this investigation then: re-sample
`/assets/downloadwiz/<assetId>` — if masters return 200, switch from passthrough to
`recollectLargest` and re-present for approval.

## Commit

`aa03e2d` — Investigate Antarctica NZ Digital Asset Manager: no higher-res source (no code
change). User-approved no-improvement 2026-06-02 (Research/highres bookkeeping only; no Swift
change).
