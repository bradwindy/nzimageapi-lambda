# 003 — National Publicity Studios black and white file prints

- **Group:** A (re-check, already in Lambda)
- **Platform:** **ndha** (National Library NDHA / Rosetta — `ndhadeliver.natlib.govt.nz`).
  NOT recollect (progress.json's tag was a pre-investigation guess; corrected here).
  Holding institution **Archives NZ**; landing pages on `collections.archives.govt.nz` (Axiell
  Arena / Liferay). Same delivery backend as TAPUHI (order 25), different URL shape.
- **DigitalNZ result_count:** 33,796 (live)
- **Timestamp:** 2026-06-02
- **Outcome:** **no-improvement** — baseline already serves the only public derivative (900 px
  access copy); the preservation master is not delivered anonymously.

## Raw record sample (key redacted)

| field | value |
|-------|-------|
| large_thumbnail_url | `https://ndhadeliver.natlib.govt.nz/NLNZStreamGate/get?dps_pid=IE25369377` |
| landing_url | `https://collections.archives.govt.nz/web/arena/search#/entity/aims-archive/R24810378` |
| object_url | `null` |

All 20 sampled records: `large_thumbnail_url` host `ndhadeliver.natlib.govt.nz`, pattern
`NLNZStreamGate/get?dps_pid=IE<digits>`; landings on `collections.archives.govt.nz` (R-numbers).

## Live site investigation (Discovery Playbook)

- **Platform detection:** image host = National Library's NDHA delivery (`ndhadeliver.natlib.govt.nz`,
  Rosetta/DPS). The IE PID (`dps_pid=IE…`) is the Rosetta Intellectual Entity. Landing site is
  Archives NZ Arena (Liferay/Axiell), which embeds the same ndhadeliver streams.
- **Baseline measurement (`NLNZStreamGate/get?dps_pid=IE…`):** JPEG capped at **width 900**.
  Samples: IE25369377 900×692, IE25112014 900×680, IE28272092 900×1185, IE25167400 900×697,
  IE24562986 900×691. (Width uniformly 900; portrait images taller.)
- **NDHA delivery path (the TAPUHI 5-step):** `DeliveryManagerServlet?dps_pid=IE…` → `dps_dvs` →
  `ieViewer.do` → FL PIDs. Where an FL stream exists it is the **access copy = the same 900 px
  JPEG** (byte-identical to baseline: FL25369415 stream = 180730 B = baseline; FL28272124 =
  302505 B = baseline). Only one representation ("access") is referenced in the viewer — no
  `master`/`preservation` rep. (For several IEs the viewer returned 0 FL ids — a fragile parse —
  but none ever exposed a larger stream.)
- **Download funcs:** viewer references `dps_func=download/downloadAll/file/thumbnail`. Measured:
  `FL …&dps_func=download` = 900×692 attachment (same access copy); `FL …&dps_func=file` = empty;
  `IE …&dps_func=download` and `downloadAll` = **404**; `IE …&dps_func=thumbnail` = 150×115.
- **No zoom/tile source:** no IIIF / Djatoka / OpenSeadragon / Mirador / Zoomify / DeepZoom /
  `info.json` signals in the viewer. So no tiled master to reconstruct.
- **Archives NZ Arena side:** Liferay SPA; images come from the same ndhadeliver streams; no public
  high-res download endpoint. Web research: Archives NZ records are "view online" only; the free
  high-res download offering belongs to the *National Library's own* collections, not these
  Archives NZ NDHA-delivered records.

## Candidate measurements (decoded pixels)

| candidate | dims | bytes | notes |
|-----------|------|-------|-------|
| baseline `NLNZStreamGate/get` (IE25369377) | 900×692 | 180730 | JPEG access copy = ceiling |
| FL access stream (`FL…&dps_func=stream`) | 900×692 | 180730 | identical to baseline |
| FL `dps_func=download` | 900×692 | 180730 | same image, as attachment |
| IE `dps_func=download` / `downloadAll` | — | — | HTTP 404 |
| IE `dps_func=thumbnail` | 150×115 | 7329 | tiny |

## Decision

**no-improvement.** The public ceiling for this collection is the **900 px access copy**, which the
baseline `large_thumbnail_url` (`NLNZStreamGate/get`) already serves directly. The Rosetta
preservation master is not delivered to anonymous users (no master representation, IE-level
download 404s), there is no zoomable/IIIF tile source, and Archives NZ Arena exposes nothing
larger. Discovery Playbook A–G exhausted. → No Swift change.

## Implementation

None (no code change). The collection stays in the legacy `switch` passthrough group in
`URLProcessor.getLargerImage`. (Platform tag corrected to `ndha` in progress.json for the durable
record; not a code change.)

## Verification

No code change to verify. Baseline behaviour confirmed live: `NLNZStreamGate/get?dps_pid=IE…`
returns HTTP 200 `image/jpeg`, ~900 px wide — equal to the FL access stream. Production output
unchanged.

## Commit

`60b7aa7` — Investigate National Publicity Studios: no higher-res source (no code change).
User-approved no-improvement 2026-06-02 (Research/highres bookkeeping only; no Swift change).
