# 029 — South Canterbury Museum

- **Order:** 29
- **Group:** A (re-check an existing Lambda collection)
- **Platform:** PastPerfect Online (hosted SaaS) — `museum_58`; same platform as Waimate (order 20).
  (progress.json `platform` reclassified `boutique` → `pastPerfect`.)
- **DigitalNZ result_count (Images):** ~22,805 (rawItemCount in progress.json 22,269)
- **Status:** no-improvement (passthrough already serves the 950 px PPO display ceiling)
- **Date:** 2026-06-11

## Baseline (what ships today)

Legacy `switch` **passthrough** group in `URLProcessor.swift` (returns `large_thumbnail_url` unchanged):

```swift
case "Antarctica NZ Digital Asset Manager",
     "National Publicity Studios black and white file prints",
     "South Canterbury Museum",
     "Waimate Museum and Archives PastPerfect",
     ...:
    return ... { url in url.absoluteString }
```

The harvested `large_thumbnail_url` is the PastPerfect Online **display image**
(`https://s3.amazonaws.com/pastperfectonline/images/museum_58/<dir>/<file>.jpg`), hard-capped at
**950 px long side**. That is the public ceiling, so passthrough is already optimal (no larger anonymous
variant exists).

## Source site

- Images: Amazon **S3**, `https://s3.amazonaws.com/pastperfectonline/images/museum_58/<dir>/<file>.jpg`
  (display) + `…/<dir>/thumbs/<file>.jpg` (thumbnail). The S3 bucket is publicly **listable**.
- Object landing pages: `https://timdc.pastperfectonline.com/{Photo|Archive|Object}/<GUID>` (Timaru
  District Council PastPerfect Online site). `object_url` null; `dc_identifier` = accession +
  `ehiveaccountid:3359` (legacy).
- Museum site: `museum.timaru.govt.nz` (Timaru District Council). Contact: museum@timdc.govt.nz,
  (03) 687 7212.

## Discovery Playbook (all avenues)

**A. Web research.** `s3.amazonaws.com/pastperfectonline/images/museum_<n>/…` ⇒ **PastPerfect Online**,
identical to Waimate (order 20, `museum_1110`). South Canterbury Museum = `museum_58`.

**B. Page-source.** Landing HTML references images via `data-image-src="…/Media/<GUID>"`; working records
also embed the S3 thumb URL. `image_processor.js` toggles thumb↔display. No `download`/`og:image` larger
image; the "Original / Original/Copy" strings on the page are PastPerfect **catalog field labels**, not a
download link (and the only `…/original/…` URLs are the museum's logo/background under `museumlogos/`).

**C. Viewers.** `/Media/<GUID>` returns an **HTML viewer page** (`text/html`, ~32 KB), NOT an image — it's
a shell that JS-loads the same S3 display image. No public IIIF/DeepZoom/zoom.

**D. URL / variant mutation.** Display = 950 px long side (uniform). Larger guesses all **404**:
`original/<f>.jpg`, `large/<f>.jpg`, `<f>_large.jpg`, `<f>.tif`, `originals/<f>.jpg`, `full/<f>.jpg`. The
`<file>-2.jpg` sibling that appears in the bucket listing is the **same 950 px size** (a second display
copy / alternate view), not larger.

**E. Alternate host/source.**
- **S3 originals exist but are 403-locked.** The bucket lists the museum's batch upload archives at
  `imageuploads2/0000000058/…_31151_Images###.zip` (+ `…Thumbs.zip`) — but GET on a zip = **403
  AccessDenied** (the bucket grants `ListBucket`, not `GetObject` on the upload prefix), and they're zip
  archives anyway (not per-image addressable / not browser-displayable). Same as Waimate 20.
- **eHive (account 3359)** is anti-bot-403 at the collection root; the museum's catalogue now lives on
  PastPerfect Online (the `ehiveaccountid:3359` is a legacy harvest id). Even if live, an eHive master
  would be ≤ 800 px (cf. AAG 27 = 800 px) — worse than the 950 px PPO display, and unmappable.

**F. Dead/Wayback.** Not pursued for resolution (the live display is the ceiling).

**G. Toolbox.** N/A — `xlarge`-equivalent display is already a browser-displayable JPEG.

## Measurements

- **Resolution:** display capped at **950 px long side**, uniform across the sample (768×950, 714×950,
  656×950, 950×710, 950×893, …). No record exceeds 950 px; no larger variant is served anonymously.
- **Harvest health (NEW vs Waimate):** **~9 % of records are dead at source.** A well-spread 250-record
  sample = **22 broken (8.8 %)**; an older "T-numbered" photo batch sampled higher (**8/50 = 16 %**). For
  the broken records the harvested S3 URL 404s (S3 `NoSuchKey`), **and** the display thumb 404s, **and**
  the landing page + `/Media/<GUID>` viewer reference **no working image** (0/8 recoverable) — the image
  was **removed from PastPerfect entirely** (zombie records: metadata present, image gone). No anonymous
  alternate exists.

## Conclusion

**No-improvement** (user-approved 2026-06-11). The passthrough already serves the PastPerfect Online
display ceiling (**950 px long side**) for the working ~91 %; no larger anonymous route exists (larger S3
variants 404; true originals are 403-locked upload zips; `/Media` is an HTML viewer; no IIIF; eHive 3359
migrated/legacy). Identical resolution outcome to Waimate (order 20). **No code change**; stays in the
legacy `switch` passthrough group.

**Data-quality caveat:** ~9 % of records are **dead at source** and unfixable anonymously (image gone from
PastPerfect; no S3/landing/Media/eHive alternate). The Lambda's selection validates only that
`large_thumbnail_url` is non-null (no HEAD-check, no retry loop — see
`DigitalNZAPIDataSource.swift:108-117`), so a picked dead record returns a broken image ~9 % of the time.
This was **left as-is** (user decision): adding a HEAD-probe would only convert a broken image into a hard
error (no retry loop, no alternate image to serve), adding latency to all records for no real gain —
consistent with how other collections' unfixable dead subsets were handled (Tauranga 01 CAT3 ~6 %, He
Purapura 10 ~10 % restricted).

## Follow-up
- The museum holds preservation masters above the 950 px PPO display cap; copies can be ordered (with
  fees) from `museum.timaru.govt.nz` / museum@timdc.govt.nz — **not a Lambda-constructable route** (user
  will not pursue contact). Re-check only if PastPerfect/the museum exposes originals publicly, or if
  DigitalNZ re-harvests with higher-res or with the dead images restored.
- The ~9 % dead-at-source records will silently fix themselves if the museum restores those images or
  DigitalNZ drops the zombies.
