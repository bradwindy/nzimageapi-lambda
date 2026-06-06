# 017 — Howick Historical Village NZMuseums

- **Group:** A (re-check, already in Lambda; `collectionWeights` 0.015)
- **Platform:** eHive (Vernon Systems) — `images.ehive.com` (account 3000); NZMuseums front-end
- **DigitalNZ result_count:** 13,461 (live, 2026-06-06)
- **Timestamp:** 2026-06-06
- **Outcome:** **no-improvement** — `_l` (800px) is the largest anonymous public size, which the current
  passthrough already serves. The original is sign-in-gated; no public IIIF/zoom for this account.

## Raw record sample (key redacted)

| field | value |
|-------|-------|
| large_thumbnail_url | `https://images.ehive.com/accounts/3000/objects/images/11gb623_v5u_l.jpg` |
| object_url | `null` |
| landing_url | `https://ehive.com/collections/3000/objects/46578` |

URL shape: `images.ehive.com/accounts/<acct>/objects/images/<imageId>_<token>_<size>.jpg`; `_l` = large.

## Current production strategy (baseline)

Legacy `switch` passthrough — serves `large_thumbnail_url` (`_l`, 800px) unchanged.

## Live site investigation (Discovery Playbook)

- **eHive public size suffixes:** `_t` 75×53, `_s` 150×106, `_m` 400×283, **`_l` 800×565 (0.5 MP)** —
  `_l` is the maximum. `_xl`, `_o`, `_full`, `_master`, no-suffix `.jpg`, and base-id-only all return
  **HTTP 500** (don't exist); `?size=original` is ignored (returns the same `_l`). Confirmed on a
  second object (1k66244: `_l` 200, `_xl`/`_o` 500).
- **No public IIIF / DeepZoom / OpenSeadragon tile source.** `.dzi`, `/info.json`,
  `/iiif/.../info.json` all 404/500. The object page references only `_l` (object image) and `_m`
  (social share); the `data-image` is the `_m` share thumbnail. (A generic `openseadragon` token
  appears in the page bundle, but no tile source is wired for this account's images.)
- **Original is sign-in-gated.** eHive docs (info.ehive.com / help.ehive.com): public viewers get
  *either* the full original *or* an 800×800 derivative, set per account/image; **signed-in users get
  the original**. Howick (account 3000) is set to the **800px** cap. There is no anonymous route to a
  larger image (would require Howick's own eHive login — per-institution, not Lambda-feasible).
- **DigitalNZ `source_url`** redirects to the eHive object page (no larger image).

Sources: <https://info.ehive.com/pan-and-zoom-ehive/>, <https://help.ehive.com/images.htm>,
<https://developers.ehive.com/> (image access / sizes).

## Decision

**no-improvement.** The current passthrough already serves `_l` (800px) — the largest publicly
available size. The preservation original exists but is anonymous-inaccessible (sign-in only), and
there is no public IIIF/zoom tile source to reconstruct it. No Swift change.

> Note for the eHive cluster (orders 18 Mataura, 19 NZ Portrait Gallery): the public ceiling is a
> **per-account setting** — some eHive accounts publish the full original anonymously. Check each:
> measure `_l` and probe whether a larger/original is publicly served before concluding.

## Deeper dig (2026-06-06, user asked to try a login hack + web research subagent)

- **Web research (subagent):** No anonymous route to eHive originals for copyright-restricted records
  (the 800px cap is server-side by rights type, not URL-level; REST API is OAuth-gated; no public
  tools/tricks; dezoomify etc. respect the server cap). The one lead — eHive serves the **full
  original anonymously for "Public Domain" records** (a per-account setting) — was tested and **does
  NOT hold for the Howick account.**
- **Rights facet (DigitalNZ):** Howick = **13,460 "Attribution - Non-commercial (cc)" + exactly 1
  "Public Domain"**. So the public-domain exception is moot here regardless (1 record).
- **Empirical PD test (record 855529, image `21faf96e…`):** even this Public Domain record is `_l`
  **533×800** anonymously; `_xl`/`_o`/no-suffix all **HTTP 500**, `info.json` **404**. ⇒ Howick's eHive
  account caps **every** record at 800px anonymously, irrespective of rights type.
- **Conclusion unchanged:** the original is reachable only via an authenticated eHive session. Whether
  that is usable by the Lambda depends on the user's login test (is the authenticated original at a
  stable anonymously-servable URL, or cookie/OAuth/signed-token gated? — the latter is expected, since
  `_xl`/`_o` return 500 to anonymous requests regardless).

## Implementation

None (no code change). Howick stays passthrough in the legacy `switch`.

## Verification

No code change. Confirmed `large_thumbnail_url` (`_l`) is HTTP 200 `image/jpeg` 800×565 and that no
larger public variant exists (suffix probes + IIIF/DZI probes all 404/500). Production output unchanged.

**User login test (2026-06-06):** the user signed in to eHive and confirmed **no higher-resolution
image is available even when authenticated** for the Howick account — eHive caps at 800px for everyone
here. ⇒ no-improvement is final.

**Follow-up:** user to email **Howick Historical Village** collections team for higher-resolution
copies. Best contact (verified on their own pages): **`collections@fencible.org.nz`** (the address their
Research Facilities / reproductions page directs requests to; they supply "Digital image – emailed" as a
paid reproduction service) — alt `collections@historicalvillage.org.nz` (staff directory; museum uses
both domains); general `village@historicalvillage.org.nz`; phone (09) 576 9506. (Could NOT verify the
research-subagent's claimed staff name "Lee Lowden" — not asserted.) Re-check/re-do this collection if
higher-res access is granted.

## Commit

`41bbcce` — Investigate Howick Historical Village (eHive): 800px is the ceiling for all users
(no code change). User-confirmed no-improvement 2026-06-06.
