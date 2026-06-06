# 018 — Mataura Museum NZMuseums

- **Group:** B (add; not yet in the Lambda)
- **Platform:** eHive (Vernon Systems) — `images.ehive.com` (account **4033**); NZMuseums front-end
- **DigitalNZ result_count:** 3,443 (live, 2026-06-07)
- **Timestamp:** 2026-06-07
- **Outcome:** **ADD via new `ehiveIIIFLargest`** — eHive's public IIIF service serves the full native
  master (up to ~16.8 MP) for **every** record, vs the 800 px `_l` derivative. 28/28 uniform-sample win.

## Raw record sample (key redacted)

| field | value |
|-------|-------|
| large_thumbnail_url | `https://images.ehive.com/accounts/4033/objects/images/ce51j4_1i1a_l.jpg` |
| object_url | `null` |
| landing_url | `https://ehive.com/collections/4033/objects/91541` |

URL shape: `images.ehive.com/accounts/<acct>/objects/images/<imageId>_<token>_<size>.jpg`; `_l` = large.

## Rights facet (DigitalNZ)

| count | rights |
|------:|--------|
| 3379 | All rights reserved |
| 47 | Public Domain |
| 10 | Copyright status unknown - orphaned work |
| 6 | Attribution (cc) |
| 1 | Attribution - Non-commercial - No Derivatives (cc) |

The IIIF master endpoint serves full native for **all** of these (it is **not** rights-gated — see below).

## Live site investigation (Discovery Playbook)

- **eHive public size suffixes (same as Howick):** `_t` 75, `_s` 150, `_m` 400, **`_l` 800 (max)**.
  `_xl`, `_o`, `_full`, `_master`, no-suffix `.jpg` all return **HTTP 500** (don't exist) — for both an
  "All rights reserved" record and the Public Domain record `esjlc0_1ht4`. So the suffix route caps at
  800 px, exactly like Howick.
- **Public-Domain → original exception does NOT hold here.** Tested 6 PD records (`esjlc0_1ht4`,
  `i4l52d_1ef7`, `1des7j1_1bdn`, `1l28m9_1e47`, `q24keu_1ebc`, `998acl_1i2k`): every one is `_l` 800 px
  anonymously and `_xl`/`_o` → 500. (The account-level "publish original" setting is off, as at Howick.)
- **★ But the object page wires OpenSeadragon 6.0.2 to a PUBLIC IIIF Image API 2.0 service** — the
  decisive difference from Howick's investigation. The landing page contains:
  `info: "https://iiif.ehive.com/iiif/2/accounts%2f4033%2fobjects%2fimages%2fesjlc0_1ht4.tif/info.json"`
  (note the identifier is the **master TIFF**, size suffix dropped, `/` → `%2f`).
- **`info.json` (PD record `esjlc0_1ht4`):** `@context` image/2, `width:4325 height:2738`, `sizes[]` up
  to the full native, `tiles` 512 px, profile **level2** (`formats: tif/jpg/gif/png`; supports
  `sizeByW`, `regionByPx`, `max`, …). No `maxWidth`/`maxHeight`/`maxArea` declared ⇒ `/full/full/`
  returns true native.
- **`/full/full/` == `/full/max/`** (byte-identical, both 200, native dims) — honest native, **no
  upscaling** (passes the Kura `sizeAboveFull` lesson). Chose `/full/full/` (canonical IIIF 2.0,
  guaranteed on this 2.0 service).
- **IIIF endpoint is NOT rights-gated:** "All rights reserved" records return full native too
  (`l3lp9l_1geg` 2962×1787, `ce51j4_1i1a` 1000×702). Verified across the whole uniform sample below.
- IIIF probes on the *images.ehive.com* host (not iiif.ehive.com) 404/500 — the service lives only at
  `iiif.ehive.com/iiif/2/`.

## Candidate measurements

Representative records (`curl | sips`, decoded px). `_l` is the baseline (raw `large_thumbnail_url`):

| record | rights | baseline `_l` | IIIF `/full/full/` native | area ratio |
|--------|--------|---------------|---------------------------|-----------:|
| esjlc0_1ht4 | Public Domain | 800×507 | **4325×2738** (11.8 MP) | 29.1× |
| ie7o18_1p2d | All rights | 800×583 | **4800×3502** (16.8 MP) | 36.0× |
| 1rd22op_1dml | All rights | 800×508 | 4313×2738 | 29.1× |
| 10c270d_1hsr | All rights | 800×520 | 4075×2650 | 26.0× |
| l3lp9l_1geg | All rights | 800×? | 2962×1787 | ~8× |
| 1mjou7p_1ijh | All rights | 800×533 | 1500×1000 | 3.5× |
| ce51j4_1i1a | All rights | 800×562 | 1000×702 | 1.56× |
| c3c1be61…7d65 | All rights | 506×800 | 633×1000 | 1.56× (UUID-style id) |

**Uniform sample (28 records across pages 1/18/34):** **28/28 IIIF `/full/full/` beat `_l`**; **0 IIIF
non-200**; `/full/full/` == `/full/max/` on all. Distribution ≈ half at **1.56×** (1000 px masters)
and half **3.5×–36×** (1500–4800 px masters). Floor is 1.56× because `_l` is 800 px-capped while the
smallest masters are 1000 px; eHive never upscales, so IIIF native is always ≥ `_l`.

## Decision

**ADD** the collection using a new reusable platform function `ehiveIIIFLargest`. Strict improvement on
every record (1.56×–36×), browser-displayable `image/jpeg`, no rights gate, no request-time fetch.

## Implementation

- `URLProcessor.swift`: new `private static func ehiveIIIFLargest(_:_:)`. Transform
  `images.ehive.com/accounts/<a>/objects/images/<id>_<token>_l.jpg` → identifier
  `accounts/<a>/objects/images/<id>_<token>.tif` (drop the **last** `_<size>` segment so the
  underscore inside the id is preserved; `.jpg`→`.tif`) → `"/"`→`"%2f"` →
  `https://iiif.ehive.com/iiif/2/<encoded>/full/full/0/default.jpg`. Falls back to the original URL if
  the host/filename shape is unexpected. Handles both `<id>_<token>_l.jpg` (2 underscores) and
  `<hexid>_l.jpg` (1 underscore) ids.
- Registry entry `"Mataura Museum NZMuseums" → ehiveIIIFLargest`.
- `NZImageApi.collectionWeights`: add `"Mataura Museum NZMuseums": 0.003` (provisional; final
  renormalization at the end of the sweep).

## Verification

- `swift build` → exit 0.
- `swift run CollectionTester "Mataura Museum NZMuseums"` ×3 → all HTTP 200, `image/jpeg`, JPEG:
  - `pfsqom_3659` → IIIF 1000×670 vs `_l` 800×536 (1.56×)
  - `10rf7sh_35r2` → IIIF 1000×669 vs `_l` 800×535 (1.56×)
  - `12g9vds_1o33` → IIIF 1000×761 vs `_l` 800×609 (1.56×)
  (The three random tester records all landed on the 1.56× floor; the broad sample confirms many
  records are 3.5×–36×.)

## ★ Cross-finding — Howick (order 17) was wrongly concluded

Howick Historical Village (account **3000**, committed `41bbcce` as *no-improvement*) **also** has the
`iiif.ehive.com` service. Tested 4 records: `hmsvif_bkc` and `9b2s3b_jgo` → **2816×2112 (5.9 MP, ~12×**
the `_l` 0.48 MP); `18g6ml4_bka` and `11gb623_v5u` → genuine 800×600/800×565 masters (no gain). So for
roughly half of Howick's records the IIIF master endpoint **bypasses the eHive UI cap** the user saw
when logged in. Howick's order-17 investigation checked `_xl`/`_o` suffixes + `images.ehive.com`
IIIF/DZI (all 500/404) and the eHive UI, but **missed `iiif.ehive.com`** (the separate IIIF host).
⇒ Raised at the Mataura approval gate: whether to re-do Howick (17) with `ehiveIIIFLargest` and apply
the same to NZ Portrait Gallery (19, also eHive).

## Commit

`de21e23` — Add Mataura Museum (eHive) via IIIF master TIFF (1.56x-36x over _l). User-approved 2026-06-07.
