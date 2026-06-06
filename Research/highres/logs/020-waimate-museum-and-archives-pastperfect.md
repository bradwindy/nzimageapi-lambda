# 020 — Waimate Museum and Archives PastPerfect

- **Group:** A (re-check, already in Lambda; legacy `switch` passthrough)
- **Platform:** PastPerfect **Online** (hosted SaaS) — images on `s3.amazonaws.com/pastperfectonline/`;
  front-end `waimate.pastperfectonline.com`
- **DigitalNZ result_count:** 8,667 (live, 2026-06-07)
- **Timestamp:** 2026-06-07
- **Outcome:** **no-improvement** — the harvested `large_thumbnail_url` is already PastPerfect Online's
  full display image (hard-capped at **950 px** on the long side). No larger original / IIIF / download
  route exists publicly.

## Raw record sample (key redacted)

| field | value |
|-------|-------|
| large_thumbnail_url | `https://s3.amazonaws.com/pastperfectonline/images/museum_1110/007/gp89.jpg` |
| thumbnail_url | `https://s3.amazonaws.com/pastperfectonline/images/museum_1110/007/thumbs/gp89.jpg` |
| object_url | `null` |
| landing_url | `https://waimate.pastperfectonline.com/photo/<UUID>` (or `/webobject/<UUID>`) |

URL shape: full display = `…/images/museum_1110/<dir>/<file>.jpg`; thumbnail = same dir + `thumbs/`.
Rights: CC BY-NC-ND 3.0. (museum id `museum_1110`.)

## Current production strategy (baseline)

Legacy `switch` passthrough — serves `large_thumbnail_url` (the S3 `images/…/<file>.jpg`) unchanged.

## Live site investigation (Discovery Playbook)

- **Display image is hard-capped at 950 px long side.** Uniform sample (18 records across pages
  1/43/86): **all 950 px on the long side** (e.g. 736×950, 950×625, 950×884), bar one genuinely small
  original (759×553). So PPO downsizes the public display copy to ≤950 px.
- **No larger S3 variant.** `…/<dir>/original/<file>.jpg`, `…/<dir>/large/<file>.jpg`,
  `<file>_large.jpg`, and `<file>.tif` all **404**. (The `original/` segment exists only for museum
  logos, not item images.)
- **No higher-res route in the viewer.** The landing page renders the item image via
  `/Scripts/pastperfect_image_processor.js`; that script only toggles `thumbs/` ↔ the full S3 image
  (no "large"/"original"/"zoom"/IIIF references). No `og:image`, no download link in the page.
- **No PPO download/media endpoint.** `/(m|M)edia/<UUID>` → HTTP 500, `/download/<UUID>` → 404.
- **No public IIIF / DeepZoom / tile source.**
- **Wayback** has the same S3 image archived (same 950 px) — no larger historical copy.

## Decision

**no-improvement.** The current passthrough already serves the 950 px S3 display image, which is
PastPerfect Online's public ceiling for this museum. No higher-resolution original is served anonymously
(PPO caps the public web copy; the museum's master would require a direct request under their BY-NC-ND
terms). No Swift change; Waimate stays in the legacy `switch` passthrough group.

## Implementation

None (no code change).

## Verification

Confirmed `large_thumbnail_url` is HTTP 200 `image/jpeg` at ~950 px and that no larger public variant
exists (size-suffix/`original`/`.tif` probes 404; `/media`/`/download` 500/404; no IIIF; Wayback same).
Production output unchanged.

## Deep dig (2026-06-07, user asked to "try more options, scrape their site for more")

- **Viewer JS proves there is no larger display image.** `/Scripts/pastperfect_image_processor.js`
  builds the big image as `containedImage.src.replace("/thumbs", "")` — literally the thumbnail URL with
  `/thumbs` removed = the exact `images/…/<file>.jpg` we already serve. The only other affordance is the
  **"Order Photo"** button (`#cmdOrderPhoto2`) — a paid reproduction request, not a public URL.
- **The S3 bucket `pastperfectonline` is publicly LISTABLE** (`?list-type=2`). Enumerated it:
  - `images/museum_1110/` has dirs `001`–`034` + `people/`; each dir holds only `<file>.jpg` (the 950px
    display copy) and `thumbs/<file>.jpg`. The **only** subdir segment is `thumbs` — no `original/`,
    `large/`, masters. Largest "full" files ~250 KB (consistent with 950px JPEG).
  - Bucket root prefixes: `dataloads/ datauploads2/ imageloads/ imageloads2/ images/ imageuploads2/
    museumlogos/ sitecontent/ xmlfiles/`. No `originals/`/`masters/`/`media/` (probed → KeyCount 0).
- **★ The true full-resolution originals DO exist** — as museum upload ZIPs at
  `imageuploads2/0000001110/` (museum 1110 → padded id `0000001110`): `…_Images001.zip` (31.8 MB),
  `…_Images006.zip` (22.5 MB), `…_Images017.zip` (69.5 MB), `…_Images023.zip` (5.0 MB), each with a
  matching small `…ImagesNNNThumbs.zip`. The `ImagesNNN` batches map to the display dirs
  `images/museum_1110/NNN/`. Raw originals (pre-downsize) almost certainly live inside these.
- **But the upload objects are `403 AccessDenied` on GET** (anonymous). The bucket grants `ListBucket`
  (metadata) but **not** `GetObject` on `imageuploads2/`/`datauploads2/` — confirmed on 3 different zips;
  the body is `<Error><Code>AccessDenied</Code>`. The public `images/museum_1110/.../<file>.jpg` stays
  200. So there is **no anonymous route** to the originals; they are only retrievable inside locked
  upload archives (or via the museum's paid "Order Photo" reproduction service).

⇒ **no-improvement stands for the Lambda**: 950px is the largest per-record image reachable by a
constructable URL. The originals exist but are access-denied and only bundled in multi-MB upload zips
(not per-image addressable, not browser-displayable, not unzippable at request time).

**Follow-up for the user (holds rights):** the full-res originals are in the S3 upload zips under
`imageuploads2/0000001110/` (and data CSVs under `datauploads2/0000001110/`). They are 403 anonymously,
but PastPerfect/the museum could grant access, or the museum's "Order Photo" service supplies repro
copies. Re-check if access is obtained.

## Commit

`54478da` — Investigate Waimate (PastPerfect): 950px is the public ceiling (no code change).
User-confirmed no-improvement 2026-06-07 (after the deep S3 dig).
