# 021 — Te Papa Collections Online

- **Group:** A (re-check, already in Lambda; legacy `switch` → weserv proxy of `/preview`)
- **Platform:** Te Papa media server — `media.tepapa.govt.nz/collection/<id>/<size>`; front-end
  `collections.tepapa.govt.nz`
- **DigitalNZ result_count:** 388,503 (live, 2026-06-07)
- **Timestamp:** 2026-06-07
- **Outcome:** **improvement — serve `/full` for open-access records** (up to ~97 MP) via a new
  `tePapaLargest` strategy; keep weserv-`/preview` for in-copyright records. Migrated legacy switch →
  registry.

## Raw record sample (key redacted)

| field | value |
|-------|-------|
| large_thumbnail_url | `https://media.tepapa.govt.nz/collection/363872/preview` |
| thumbnail_url | `https://media.tepapa.govt.nz/collection/363872/thumb` |
| object_url | `null` |
| landing_url | `https://collections.tepapa.govt.nz/object/136194` |

Size path: `/collection/<id>/{thumb|preview|full}`. The id is Te Papa's media IRN (in the harvested
`/preview` URL). The media endpoint 303-redirects to S3 (`co3-api-mediastorage.s3.ap-southeast-2`).

## Rights facet (DigitalNZ) — determines `/full` availability

| count | rights | `/full`? |
|------:|--------|----------|
| 149,194 | All Rights Reserved | no (HTTP 500) |
| 147,350 | CC BY 4.0 | yes |
| 68,727 | No Known Copyright Restrictions | yes |
| 23,144 | CC BY-NC-ND 4.0 | yes |
| 35 | CC BY-NC-SA 4.0 | yes |
| 24 | CC 0 | yes |
| 15 | CC BY-SA 4.0 | yes |
| 11 | CC BY-NC 4.0 | yes |
| 3 | Copyright Te Papa | no |

≈ **62% open-access** (have `/full`); ≈ 38% in-copyright (only `/preview`).

## Live site investigation (Discovery Playbook)

- **Baseline `/preview` ≤ 1000 px** long side (the harvested URL; current production weserv-proxies it).
- **`/full` is the big one** — but only for open-access records. In-copyright `/full` → **HTTP 500
  "UnknownError"**. Valid sizes are `thumb`/`preview`/`full`; `large`/`original`/`raw`/`download`/`max`
  → 400; `?width=` ignored.
- **`/full` can't be HEAD-probed** (HEAD → 403 from the media/S3 layer) and **weserv can't proxy it**
  (weserv → 404). But it **embeds directly** (foreign-Referer GET → 200, so no hotlink protection) and a
  **1-byte ranged GET cleanly distinguishes availability**: open-access → **206 (1 byte)**, in-copyright
  → **500**. So the strategy probes `/full` with a ranged GET (never downloads the image) and serves it
  directly when present.
- Direct S3 (`co3-api-mediastorage…`) is **403** for arbitrary GET and bucket listing is denied — the
  only route is the media endpoint.
- `/full` images can exceed **weserv's 71 MP cap** (one tester record was 97 MP) → another reason to
  serve `/full` **directly**, not proxied.

## Candidate measurements — uniform sample (21 records across pages 1/1000/3000)

`curl | sips` decoded px; `/preview` (baseline) vs `/full`:

| rights class | `/full` available | examples (preview → full) |
|--------------|:-----------------:|----------------------------|
| open-access (CC / No Known Copyright) | **9/9** | `156911` 1000×565 → **7207×4075** (52×); `236523` → 5512×4430 (30×); `113004` → 1599×3000 (9×); `18425` 491×640 → 491×640 (1.0×, tiny original, no loss) |
| All Rights Reserved | 0/12 | `/full` → HTTP 500 (kept on weserv `/preview`) |

`/full` is always ≥ `/preview` for records that have it (Te Papa never upscales; the smallest case is
equal). **No regression** for in-copyright records (output identical to current production).

## Decision

**Serve `/full` directly for open-access records, weserv-`/preview` otherwise.** Strict improvement:
~62% of the collection jumps from ≤1000 px to multi-megapixel originals (21–97 MP observed); the rest is
unchanged. Decided per request by a 1-byte ranged-GET probe of `/full` (robust ground truth — never
serves a 500, no reliance on the rights field, never downloads the image).

## Implementation

- `NetworkRequestManager.swift`: new `rangeStatusFollowingRedirects(endpoint:)` — 1-byte `Range:
  bytes=0-0` GET following redirects, returns the status (works where HEAD is 403).
- `URLProcessor.swift`: new `tePapaLargest(_:_:)` — probe `/full`; serve directly on 206/200, else
  `weservProxy(/preview)`. Registry entry added; legacy `case "Te Papa Collections Online"` removed
  (switch → registry migration).
- Weight unchanged (Group A).

## Verification

- `swift build` → exit 0.
- `swift run CollectionTester "Te Papa Collections Online"` ×4:
  - `268741` (in-copyright) → `weserv/?url=…/preview` → **HEAD 200, image/jpeg** ✅.
  - `779249`, `730370`, `605976` (open-access) → `…/full`. The tester reports **HTTP 403** because it
    validates with **HEAD** (Te Papa blocks HEAD on `/full`); this is a tester artifact only. Verified
    via **GET** (what a browser does): all **HTTP 200 image/jpeg JPEG**, decoded:
    - `730370` → **11478×8478 (97.3 MP)** vs preview 1000×739 (**131.7×**)
    - `779249` → 3744×5616 (21 MP) vs 667×1000 (31.5×)
    - `605976` → 3744×5616 (21 MP) (31.5×)
- Per-request cost: one bounded ranged-GET probe (1 byte) — same class as the Recollect HEAD probe.

## Commit

(pending user approval)
