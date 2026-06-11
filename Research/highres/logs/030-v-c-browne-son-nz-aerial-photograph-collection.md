# 030 — V.C. Browne & Son NZ Aerial Photograph Collection

- **Order:** 30
- **Group:** A (re-check an existing Lambda collection)
- **Platform:** the company's **own commercial ASP.NET site** (`www.vcbrowne.com`, WebForms
  `Detailprom.aspx`) — a NZ aerial-photography firm that sells prints/digital copies. (`boutique`.)
- **DigitalNZ result_count (Images):** ~31,506 (rawItemCount in progress.json 31,506)
- **Status:** no-improvement (passthrough already serves the only freely-available image — a ~700 px
  **watermarked** display)
- **Date:** 2026-06-11

## Baseline (what ships today)

Legacy `switch` **passthrough** group (returns `large_thumbnail_url` unchanged). The harvested
`large_thumbnail_url` is the on-site display image
(`http://www.vcbrowne.com/Images/<album>/<file>.jpg`), uniformly **~700–756 px long side** (~0.5 MP) and
**watermarked** with tiled "Copyright V.C. Browne & Son" text. The `-TH.jpg` sibling is the smaller
thumbnail.

## Source site

- Images: `http://www.vcbrowne.com/Images/<album folder>/<file>.jpg` (display, **HTTP not HTTPS**) +
  `…/<file>-TH.jpg` (thumb). Album folder = the roll id + date + place (e.g.
  `13259 15-1-71 Burnside - Riccarton - Wigram`).
- Landing: `http://vcbrowne.com/Detailprom.aspx?RID=<roll>&PID=<photo>` ("prom" = promotional/public).
  `object_url` null; `dc_identifier` empty.
- Commercial sales site: Search / Order / Basket pages; clean full-resolution scans are the **paid
  product** (delivered on purchase, not on the public site).

## Discovery Playbook (all avenues — user explicitly asked for a thorough scrape)

**A. Web research / image inspection.** The display JPEG (viewed) is **watermarked** ("Copyright V.C.
Browne & Son", tiled ~6×). EXIF: Adobe Photoshop Elements export, 800 DPI — i.e. the watermark is **baked
into** the web display; the clean original is a separate (sold) file.

**B. Page-source.** `Detailprom.aspx` references **only** the watermarked display `<file>.jpg`. The page's
"watermark" strings are an **ASP.NET `TextBoxWatermarkBehavior`** (form-field hint text), NOT an image
watermark — red herring. The detail page is **CAPTCHA-gated** (`MyCaptcha1`, `.ashx?CaptchaText=…`).

**C. Viewers.** No zoom/IIIF/OpenSeadragon; no "view larger" / enlarge link.

**D. URL / variant mutation.** Display = ~700–756 px (uniform across the result set). **All larger forms
404:** suffixes `-HR/-L/-XL/-FULL/-LG/-BIG/-ORIG/_large/-1200/-2000`; query resize `?w=2000`/`?width=2000`/
`?size=full` are **ignored** (stays 739×700). No dynamic resizing.

**E. Alternate host/source / structure scrape.**
- `/Images/` and the album folders are **not directory-listable** (403, IIS directory-browsing off).
- **No parallel hi-res directory:** `/HiRes/`, `/Hires/`, `/Originals/`, `/Original/`, `/Large/`, `/Full/`,
  `/Print(s)/`, `/Master(s)/` — all 404.
- **No non-promotional detail page:** `Detail.aspx` → an **error page** ("A page could not be found");
  `Order.aspx` / `Basket.aspx` → stubs (no anonymous larger image).
- **No image handler:** no `.ashx`/resizer image handler on the homepage.
- `robots.txt` / `sitemap.xml` → 404.

**F. Dead/Wayback.** Wayback CDX for `vcbrowne.com/Images/*` has captured **only the `-TH` thumbnails**
(5–9 KB) — nothing larger, and not a live Lambda route anyway.

**G. Toolbox.** N/A — the display is already a browser-displayable JPEG; nothing larger to convert.

## Measurements

- **Resolution:** display uniformly **700–756 px long side** (756×605, 663×700, 705×700, 739×700,
  756×566). No record exceeds ~756 px; no larger anonymous variant exists.
- **Watermark:** present on the served display image (baked-in copyright text).
- **Harvest health:** **~5 % dead** (38/40 OK; 2 records 404) — minor dead-at-source, cf. South
  Canterbury 29.

## Conclusion

**No-improvement** (user-approved 2026-06-11, after an explicit full-site scrape). The passthrough already
serves the **only freely-available image** — the ~700 px watermarked display. There is **no anonymous route
to anything larger or un-watermarked**: no larger suffix/dir/handler, no resize params, no non-prom page,
CAPTCHA-gated, Wayback has only thumbnails. The clean, full-resolution scans are the company's **paid
product**. Resolution can't be improved and the watermark can't be removed anonymously. **No code change;**
stays in the legacy `switch` passthrough group. (User considered but declined removal — the images are
genuine, if watermarked.)

## Follow-up
- Re-check only if V.C. Browne ever serves un-watermarked or higher-res images on the public site (it's a
  commercial sales model, so unlikely), or if DigitalNZ re-harvests from a higher-res source.
- ~5 % of records are dead at source (404), unfixable anonymously — self-heals if the source restores them
  or DigitalNZ drops the zombies.
