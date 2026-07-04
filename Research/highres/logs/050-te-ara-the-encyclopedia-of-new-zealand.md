# 050 — Te Ara - The Encyclopedia of New Zealand

- **Group:** B (add, not currently in the Lambda)
- **Platform:** Te Ara's own self-hosted Drupal CMS (`teara.govt.nz`); images served directly from
  `sites/default/files/` (or, for some newer/differently-migrated records, `sites/default/files/
  large_images/`) — no CDN/DAMS abstraction visible
- **DigitalNZ result_count:** 27,090 image-bearing (live, 2026-07-04; `rawItemCount` snapshot 25,634)
- **Timestamp:** 2026-07-04
- **Outcome:** **no-improvement, NOT added (user decision).** Baseline quality is decent on its own
  (~500–830 px long side across a sample) and the harvested URL is already Te Ara's own ceiling — no
  Drupal image-style derivative or larger sibling exists for any filename tested. A separate,
  much bigger finding (some photos are cross-referenceable to higher-res originals in *other*
  institutions' collections, e.g. TAPUHI/NDHA) was investigated and explicitly **declined** as a
  production strategy — too heterogeneous/fragile/risky to build responsibly. User chose to skip
  Te Ara entirely rather than add it at its native (unimproved) baseline.

## Raw record sample (key redacted)

| field | value |
|-------|-------|
| large_thumbnail_url (example) | `https://teara.govt.nz/sites/default/files/p18900atl.jpg` (500×295) |
| thumbnail_url | identical to `large_thumbnail_url` in every sampled record |
| landing_url | `https://teara.govt.nz/en/photograph/<id>/<slug>` |
| content_partner | always `["Manatū Taonga, the Ministry for Culture and Heritage"]` (Te Ara's
  own publisher) |
| contributing_partner | **highly heterogeneous** — Alexander Turnbull Library, Te Papa, regional
  art galleries (Dunedin Public, Christchurch, Auckland), Getty Images, Otago Daily Times, private
  photographers, publishers, university archives, or Te Ara itself — 40-record sample had ~15
  distinct contributing partners, no single one dominant (ATL ≈17.5%) |

Filenames encode the source institution as a suffix: `-enz` (Te Ara/Encyclopedia NZ itself),
`-atl` (Alexander Turnbull Library), `-dpa` (Dunedin Public Art Gallery), `-cag` (Christchurch Art
Gallery), `-aag` (Auckland Art Gallery), `-gi` (Getty Images), `-wmu`/`-pc` (other partners), etc.

## Current production strategy (baseline)

Not currently served — Te Ara is not in `NZImageApi.collectionWeights`.

## Live site investigation (Discovery Playbook)

- **Landing pages are Cloudflare-challenge-walled.** Every `teara.govt.nz/en/...` page (and Drupal
  JSON:API paths `/jsonapi`, `/jsonapi/node/photograph`, `?_format=json`, `/node/<id>`) returns
  **HTTP 403** with `cf-mitigated: challenge` and a Cloudflare Turnstile CSP — cannot be scraped by
  a plain HTTP client (no browser JS engine available). This ruled out `og:image`/srcset/embedded-
  state scraping entirely.
- **Static image assets under `sites/default/files/` are NOT behind the challenge** (200 directly) —
  only the HTML pages are gated. This is why the harvested `large_thumbnail_url` itself always
  works, even though the article page can't be fetched.
- **No Drupal image-style derivative exists.** Tried `sites/default/files/styles/{large,wide,full,
  original,hero,hires,high,extra_large,photo_full,media_full,1200,1000}/public/<filename>` on
  several sampled filenames — **all 404**. Tried filename-suffix variants (`_large`, `_hi`, `_full`,
  `-large`, `-hires`) — **all 404**. The harvested file is the only file that exists at that path.
- **`large_images/` is a real but non-universal upload folder**, not a bigger-sibling derivative.
  One later-page record (id 50595511) harvested `sites/default/files/large_images/47774-ps.jpg`
  (830×553) directly — DigitalNZ had already harvested the correct/best URL for that record.
  Testing `large_images/<filename>` for several *plain*-path filenames from earlier records (e.g.
  `45535-enz.jpg`, `45530-atl.jpg`, `45818-enz.jpg`, `p18900atl.jpg`) → **all 404** — i.e.
  `large_images/` is just where Te Ara happened to upload that particular era/batch of images, not
  a hidden bigger version of every file. **Conclusion: whatever URL DigitalNZ harvested per record
  IS the correct, best, and only URL for that record** — no rewrite trick applies.
- **Baseline dimension sample (14 records, pages 1 and 5):** long side ranged **462–660 px**
  (portrait) and **496–830 px** (landscape/portrait mixed), median around 650–700 px — comparable
  to several already-accepted lower-resolution collections in this sweep (Waimate 20 / South
  Canterbury 29 ~950 px, V.C. Browne 30 ~700 px). One outlier record (id 31911399, `p18900atl.jpg`)
  was notably smaller at 500×295 (≈0.15 MP) — an older/wide-crop upload.
- **★ Cross-reference finding (investigated, NOT pursued as a strategy):** Te Ara's `rights` field
  often embeds the contributing institution's own reference number for institutionally-sourced
  photos, e.g. `"...Hubert Girdlestone Collection Reference: PA1-q-913-08-4..."`. A DigitalNZ
  full-text search for that exact reference number (`text=PA1-q-913-08-4`) returned, as its first
  hit, the **same photograph** already in **TAPUHI** (`"Swagging up to Mount Matthew's trig"`,
  `landing_url=natlib.govt.nz/records/22886037`, served via `NLNZStreamGate` — the exact platform
  this sweep already has a working converter for, order 25). This means at least some Te Ara photos
  have a genuinely higher-res original reachable via a completely different collection's pipeline.
  **However**, this was NOT built as a production strategy because: (1) `contributing_partner` is
  **extremely heterogeneous** (≈15 distinct institutions in a 40-record sample, no single one
  dominant) — even restricting to the ATL subset (≈17.5%) leaves the rest (Te Papa, art galleries,
  Getty, newspapers, private photographers, publishers) each needing their own separate, unverified
  lookup path, most of which likely have NO public/anonymous route at all; (2) the reference-number
  regex is fragile and institution-specific — no evidence it's uniformly formatted across the other
  ~14 institutions seen; (3) a DigitalNZ full-text search is not a guaranteed-correct lookup — a
  false-positive text match could silently substitute the **wrong photograph**, which would be a
  much worse defect than serving a smaller-but-correct image; (4) implementing this would require
  adding a new `rights` field to the `NZRecordsResult` model, an additional authenticated DigitalNZ
  API round-trip at request time, and dispatch logic to route to whichever *other* collection's
  platform-specific strategy matched — a materially bigger architectural change than any other
  strategy in this sweep, whose registry is built around one self-contained platform per collection.
  ⇒ **Recorded as a follow-up idea, not built.** If revisited: would need a much larger sample to
  measure real hit-rate/reliability per institution before writing any code, and a way to verify a
  text-search hit is genuinely the same photograph (e.g. dimension/EXIF/visual comparison), not just
  a textual coincidence.

## Decision

**no-improvement; NOT added (user decision, 2026-07-04).** Exhausted every anonymous route this
sweep normally checks on Te Ara's own hosting (Cloudflare-walled pages, Drupal style-path guesses,
filename-suffix guesses) — the harvested URL is confirmed to be Te Ara's own ceiling. The
adjacent cross-institution lookup idea is real but out of scope for this collection's strategy
given its heterogeneity and correctness risk. User decided to skip Te Ara entirely rather than add
it at a merely-decent, unimproved baseline. `platform` corrected `boutique` → a descriptive
`teara` (Drupal, self-hosted); no Swift change.

## Implementation

None (no code change; not added to the Lambda).

## Verification

N/A — no code change to verify. Confirmed via curl that the harvested URLs are 200 JPEG (occasional
GIF for diagram-type "images") and that every larger-derivative guess 404s.

## Commit

(recorded after this bookkeeping commit — no code change, no separate strategy commit needed)
