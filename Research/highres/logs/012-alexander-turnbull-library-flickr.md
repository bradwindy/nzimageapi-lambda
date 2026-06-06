# 012 — Alexander Turnbull Library Flickr

- **Group:** A (re-check, already in Lambda; `collectionWeights` 0.005)
- **Platform:** flickr (`live.staticflickr.com`; **National Library NZ Commons** account
  `nationallibrarynz_commons` — Flickr Commons, "no known copyright restrictions")
- **DigitalNZ result_count:** 4,307 (live, 2026-06-06)
- **Timestamp:** 2026-06-06
- **Outcome (awaiting approval):** **No resolution improvement** — the current `objectUrlDirect`
  already serves the `_o` **original** (the Flickr ceiling). Committed a low-risk migration +
  fallback upgrade only (registry + `_b` null fallback); served images are unchanged.

## Raw record sample (key redacted)

| field | value |
|-------|-------|
| large_thumbnail_url | `https://live.staticflickr.com/5252/5531166314_5eded852bc_z.jpg` (Medium 640) |
| object_url | `https://live.staticflickr.com/5252/5531166314_33d2542584_o.jpg` (**Original**, originalsecret) |
| landing_url | `http://www.flickr.com/photos/nationallibrarynz_commons/<photoId>/` |

`object_url` carries the `_o` original (different secret from `_z` — the `originalsecret`). This is a
Flickr Commons account where the institution has enabled original downloads.

## Current production strategy (baseline)

Legacy `switch` case: `objectUrlDirect` — return `result.objectUrl` if present, else
`url.absoluteString` (the raw `_z` 640 thumbnail). So production **already serves the `_o` original**
for every record that has an `object_url`.

## Live site investigation (Discovery Playbook)

- **`object_url` present for 50/50** uniformly-sampled records (pages 1–281, per_page 5): **0 null,
  0 non-jpg, all `_o`.** So `objectUrlDirect` serves the original for ~100% of records.
- **`_o` is a browser-displayable JPEG** (`Content-Type: image/jpeg`, HTTP 200) and far larger than
  the harvested `_z`:
  | record | `_z` baseline | `_o` original (served) |
  |--------|---------------|------------------------|
  | 21654582642 | 448×640 (0.3 MP) | **4255×6081 (25.9 MP)** |
  | 21679159282 | 500×640 (0.3 MP) | **2135×2733 (5.8 MP)** |
  | 21420726080 | 640×462 (0.3 MP) | **5142×3708 (19.1 MP)** |
  | 5531166314 | 465×640 (0.3 MP) | 744×1024 (0.8 MP — a small scan; `_o` is still the true original) |
- **`_o` is the ceiling.** Flickr exposes nothing larger than the original; `_b` (1024) only ever
  equals or undercuts `_o`. So `objectUrlDirect` is already optimal — **no higher-res source exists**
  on Flickr. (Cross-aggregator matching to NLNZ TAPUHI/natlib preservation masters was considered and
  rejected: unreliable item-matching across 4,307 records for uncertain gain; the Commons `_o` is the
  published original.)

## Decision

**No resolution improvement** (current strategy already serves the `_o` original = max). Committed a
**strictly-≥, zero-risk** change only:
1. **Migrated** the legacy `switch` case to the `strategies` registry (advances the switch→registry
   migration; removes one more legacy case).
2. **Upgraded the fallback:** when `object_url` is null (unobserved in 50/50, but possible at request
   time), the strategy now returns `flickrLargest` (`_b` 1024) instead of the raw `_z` (640).

Behavior is **identical on ~100% of records** (object_url present → `_o`). Served-image resolution is
unchanged; this is architecture + robustness, not a resolution win.

## Implementation

- `URLProcessor.strategies`: added `"Alexander Turnbull Library Flickr" → result.objectUrl?.absoluteString ?? flickrLargest(result, url)`.
- `URLProcessor` legacy `switch`: removed the `case "Alexander Turnbull Library Flickr":` block.
- No `collectionWeights` change (Group A re-check; already at 0.005).
- (`objectUrlDirect` reusable helper left in place — unused, consistent with the other pre-built
  platform functions; the inline closure needs the `flickrLargest` fallback, not `objectUrlDirect`'s
  `url.absoluteString` fallback.)

## Verification

`swift build` exit 0. `CollectionTester "Alexander Turnbull Library Flickr"` ×3 (fresh server, :7000
freed between): **3/3 HTTP 200, `Content-Type: image/jpeg`, JPEG**, all `_o` originals — 21654582642
**25.9 MP**, 21679159282 **5.8 MP**, 21420726080 **19.1 MP** (vs `_z` 0.3 MP). Identical to the prior
production output.

## Commit

(pending user approval)
