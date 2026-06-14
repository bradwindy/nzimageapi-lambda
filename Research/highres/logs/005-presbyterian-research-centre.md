# 005 — Presbyterian Research Centre

- **Group:** A (re-check, already in Lambda)
- **Platform:** recollect (Recollect — Recollect Ltd / NZMS, NOT Axiell) — harvested host `prc.recollect.co.nz`, **migrated to
  `pcanzarchives.recollect.co.nz`** (Presbyterian Church of Aotearoa NZ Archives).
- **DigitalNZ result_count:** 16,200 (live)
- **Timestamp:** 2026-06-02
- **Outcome:** **blocked** — source migrated + went login-walled; DigitalNZ's harvested URLs are
  stale (404); no anonymous, mappable route to the images. Baseline passthrough currently serves
  broken 404 pages.

## Raw record sample (key redacted)

| field | value |
|-------|-------|
| large_thumbnail_url | `http://prc.recollect.co.nz/assets/display/28133-600` |
| landing_url | `http://prc.recollect.co.nz/nodes/view/113591` |
| object_url | `null` |

All sampled records: harvested host `prc.recollect.co.nz`, `/assets/display/<id>-600`.

## Live site investigation (Discovery Playbook)

- **Domain migration:** `http://prc.recollect.co.nz/...` 301→`https://prc.recollect.co.nz:443/...`
  302→**`https://pcanzarchives.recollect.co.nz/...`**. The Presbyterian archive rebuilt its
  Recollect site under a new domain.
- **Old asset ids are dead:** `display/<id>-600/-280/-max` and `downloadwiz/<id>` all resolve to a
  Recollect **404 "Page not found"** (8 KB HTML) on the new domain. Tested asset ids 28133, 28229,
  21903, 19925, 24724 → **5/5 = HTTP 404**; `downloadwiz` on 32 thumb ids → **32/32 = 404**. The
  new site re-IDs assets; there is no derivable old-id → new-id mapping.
- **Records are login-walled:** `…/nodes/view/<node>` 302→`https://pcanzarchives.recollect.co.nz/users/login`
  ("Login | Presbyterian Research Centre"). The stale landing has no `og:image` (it's the login
  page). So the NAM og:image trick is inapplicable (no public node page to scrape).
- **No DigitalNZ cached fallback:** `thumbnailer.digitalnz.org/?src=<stale url>` → no response
  (000); it re-fetches the dead source. The pcanzarchives public homepage embeds no
  `/assets/display/` images to harvest.
- **Web research:** PRC announced a "new website [that] makes church archival records and
  photographs more accessible" and "urges you to create a login … to allow access to further
  archival treasures." ⇒ digitised images now sit behind the new domain, with login required for
  the harvested records. (Sources: presbyterian.org.nz/new-website-makes-church-archival-records-more-accessible;
  pcanzarchives.recollect.co.nz/.)

## Candidate measurements (decoded pixels)

| candidate | result |
|-----------|--------|
| baseline passthrough `prc…/display/<id>-600` | **HTTP 404** (redirects to pcanzarchives, asset gone) |
| `pcanzarchives…/display/<id>-max` (5 ids) | **HTTP 404** |
| `downloadwiz/<thumbId>` (32 ids) | **HTTP 404** |
| `nodes/view/<node>` | **302 → /users/login** |
| `thumbnailer.digitalnz.org` proxy of stale src | no response (source dead) |

No browser-displayable image obtainable from any anonymous route.

## Decision

**blocked.** The harvested source is dead and the live collection migrated behind a login wall with
re-IDed assets; there is no anonymous, mappable URL to any image. The Lambda's current passthrough
therefore emits broken 404 HTML for every Presbyterian record. Recovery would require either PRC
making the collection public again (or providing access), or DigitalNZ re-harvesting the new
domain. **Decision on Lambda handling (remove vs keep-as-blocked) deferred to the user** (see
below).

## Implementation

User chose **"Remove + note to email PRC"**. Removed from the Lambda:
- `NZImageApi.collectionWeights`: deleted `"Presbyterian Research Centre": 0.014,` (weights now
  sum < 1.0; final renormalization pass at the end of the sweep — picker tolerates intermediate
  shortfall, local tests pass an explicit collection).
- `URLProcessor.getLargerImage`: removed `"Presbyterian Research Centre"` from the passthrough
  `switch` case (the V.C. Browne line now carries the trailing `:`).

**Follow-up (user action):** the user will email PRC (pcanzarchives@prcknox.org.nz) to request
public/anonymous access. If granted (or DigitalNZ re-harvests the new domain), re-check and re-add:
the new host is `pcanzarchives.recollect.co.nz`; if assets become public, apply `recollectLargest`
(downloadwiz vs -max) once a record→asset mapping exists.

## Verification

`swift build` exit 0. Smoke-tested the pipeline post-removal with `CollectionTester "Tauranga City
Libraries Other Collection"`: 3 runs — pipeline intact, 2 returned working masters
(`downloadwiz/…` HTTP 200), 1 hit a known Tauranga CAT3 dead record (404, pre-existing, unrelated
to this removal). No regression from the Presbyterian removal.

## Commit

`3e88ae9` — Remove Presbyterian Research Centre: source migrated behind login wall (blocked).
User-approved removal 2026-06-02 (removed from Lambda + bookkeeping).
