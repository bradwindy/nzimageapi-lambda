# Order 38 — Tasman Heritage

- **Group:** B (ADD — was NOT in `collectionWeights`, so never served)
- **Platform (progress.json):** `boutique` → **RECLASSIFIED to `recollect`** (Recollect — by Recollect Ltd / NZMS, **not** Axiell; classic `downloadwiz` generation)
- **rawItemCount (list):** 2,668 · **live (primary_collection/display_collection, category=Images):** 2,879
- **content_partner:** Tasman District Libraries
- **Status:** committed (user-approved 2026-06-14)
- **Strategy:** Group B ADD via the **EXISTING `recollectOgImageMaster`** (introduced for John Kinder 37) —
  two-asset og:image → downloadwiz master, no new strategy code

## Identity

"Tasman Heritage" is the DigitalNZ **`primary_collection`** and **`display_collection`** (both 2,879
Images); the `collection` field is 0 (`and[collection][]=Tasman Heritage` → 0). Same as Clutha (36):
the Lambda queries `and[primary_collection][]` + `and[category][]=Images` and dispatches on
`result.collection` (= `display_collection` = "Tasman Heritage"), so the single key works.

## Platform detection

Harvested `large_thumbnail_url` = `http://tasman.recollect.co.nz/assets/display/<id>-600`, thumbnail
`…/<id>-280`, landing `https://tasman.recollect.co.nz/nodes/view/<node>` — the classic **Recollect**
`downloadwiz` shape. Footer: **"Recollect Limited"** (Recollect Ltd / NZMS — NOT Axiell). 6th
`boutique`-mislabel of the sweep.

## ★ Two-asset (cf. John Kinder 37 / NAM 02) + Clutha-style vanity redirect

Identical two-asset structure to John Kinder:
- `/assets/downloadwiz/<thumbId>` → **404** ("goDownload failed") — the harvested id is master-less.
- `/assets/display/<thumbId>-600` == `-max` == `-4000` — all byte-identical ≈1000 px (capped).
- The **node `og:image`** references a **DIFFERENT primary asset id** (thumb 14892 → og 14893; thumb
  53 → og 54) whose **`downloadwiz` master IS present**.

**Plus a vanity-domain redirect (cf. Clutha 36):** `tasman.recollect.co.nz` 301/302-redirects to the
council domain **`heritage.tasmanlibraries.govt.nz`**; the node page's `og:image` and the master both
live on the vanity host. Because `recollectOgImageMaster` builds the master URL from the **og:image's
own host**, it targets the vanity domain automatically — so Tasman needed **no new strategy code, just a
registry entry reusing the Kinder helper** + a weight.

## ★ The fix that was required — fetchHTML must carry the browser UA across the cross-host redirect

The vanity host **403s any request lacking a browser User-Agent** (verified: no-UA and `curl/x.y` UA
both 403; the harvested `*.recollect.co.nz` host too). `NetworkRequestManager.fetchHTML` set the UA via
the session's `httpAdditionalHeaders`, which Alamofire/URLSession does **not** reliably reapply to the
**redirected** request on a cross-host 301/302. So fetchHTML received the vanity host's **403 error
page** (which has no `og:image`), and `recollectOgImageMaster` silently fell back to the harvested
`-600`. (John Kinder 37 was unaffected — `kinderlibrary.recollect.co.nz` does not cross-host redirect,
so the single request carried the session UA fine.)

**Fix:** also send the User-Agent as a **per-request header** (`session.request(endpoint,
headers:)`), which URLSession **does** copy onto the redirected `URLRequest`. Additive/strictly-improving
— for non-redirecting hosts it is identical to the existing `httpAdditionalHeaders` UA, so it cannot
regress NAM / Kinder / Feilding / Flickr-landing / knowledgeBank callers. (Regression-checked: Kinder
×2 → `downloadwiz` masters; Feilding falls back to its `!880,1024` JPEG **only** because the **local**
CollectionTester env has no `JP2_CONVERTER_URL` — `feildingConverter` guards on that env var **before**
`fetchHTML`, so it is pre-existing local behavior, not from this change.)

> ⚠️ Re-discovered the **stale `:7000`** trap mid-investigation: a leftover Kinder-era lambda stayed
> bound to port 7000 (`bind … Address already in use, errno 48` in `/tmp/lambda-server.log`), so
> CollectionTester silently tested the OLD binary (no Tasman entry → passthrough) and masked the fix.
> The built-in `killProcessOnPort` calls `/usr/bin/lsof`, which does not exist here (`lsof` is at
> **`/usr/sbin/lsof`**) → the kill silently no-ops. Free `:7000` with `/usr/sbin/lsof -ti :7000 | xargs
> kill -9` between runs.

## Measurements (Discovery Playbook)

**Uniform survey — 80 records** across pages 1/4/7/10/13/16/19/22/25/28 (asset ids 53–30 601):

| metric | value |
|---|---|
| thumb `downloadwiz` 200 | **0/80** |
| og id present / differs from thumb | 80/80 / **80/80 (100%)** |
| og `downloadwiz` 200 | **80/80 (100%)** |
| og host | **all `heritage.tasmanlibraries.govt.nz`** (uniform vanity) |
| node not-200 / login-wall / missing og | **0 / 0 / 0** |
| master magic-byte JPEG | 7/7 (real displayable JPEGs) |
| og:image width | min 318 · median **1855** · max **9803** (>1000 px: 70/80 = 87.5%) |

**Pixel sample — 32 uniform records** (baseline `display/<thumbId>-600` vs master `downloadwiz/<ogId>`):

| metric | value |
|---|---|
| wins (>1.02×) | **26/32 (81%)** |
| ~equal (0.98–1.02×) | 3/32 (small ≤1000 px native) |
| honest-smaller (<0.98×) | 3/32 |
| failures | 0 |
| ratio (area) | min 0.44× · **median 3.14×** · max **15.44×** · mean 5.25× |
| master MP | min 0.40 · median 2.33 · **max 10.02** |

**Master format:** JPEG (`application/octet-stream` + `Content-Disposition: attachment`, e.g.
`KH20221051.jpg`) — renders in `<img>` (Tauranga/Hastings/Lower Hutt/Clutha behavior).

**Honest-smaller (3/32):** thumb 27490 (`-600` upscaled-fake 999×588) → master 27491 (honest 827×487);
thumb 27568 (1000×1640) → 27569 (665×1091); thumb 27582 (999×1565) → 27583 (684×1071). The `-600`
upscales small originals to a fake ~1000 px; `downloadwiz` returns the honest native (honest-native-
always, cf. Kinder 37 / Clutha 36 / Hocken 8 / Kura 16).

## Decision

**Group B ADD via the existing `recollectOgImageMaster`** — master present for 80/80 (100%, up to
~9803 px wide / 10 MP), median 3.14× the ~1000 px display tier, graceful HEAD-probe fallback to the og
asset's `-max` for any pending-master record, harvested-`url` fallback on parse/fetch failure. The only
code beyond the registry entry + weight is the shared `fetchHTML` redirect-UA fix.

## Implementation

- `URLProcessor.swift` — registry entry `strategies["Tasman Heritage"] = { await
  recollectOgImageMaster(...) }` (reuses the Kinder helper; the og:image-own-host logic handles the
  vanity redirect).
- `NetworkRequestManager.swift` — `fetchHTML` now also sends the browser User-Agent as a per-request
  header so it survives cross-host redirects (the fix above).
- `NZImageApi.swift` — `collectionWeights["Tasman Heritage"] = 0.002` (provisional).
- `progress.json` — platform `boutique` → `recollect`; status; baseline/chosen/notes.

## Verification

- `swift build` exit 0.
- CollectionTester ×4 → 4/4 HTTP 200 (`display_collection`="Tasman Heritage" confirms dispatch):
  records → `downloadwiz/375` (1830×1422 = 2.6 MP), `downloadwiz/29240` (1990×1990 = 4.0 MP),
  `downloadwiz/10358` (1857×1313 = 2.4 MP), and `display/16384-max` (999×683 — the master-probe-else-`-max`
  fallback fired for that og asset). All on the vanity host; every picked URL targets the og asset id
  (≠ harvested thumb id).
- Regression: Kinder ×2 → `downloadwiz` masters; Feilding local fallback explained (env-gated, not this change).

## Example live URLs (for the approval gate)

- big master: `https://heritage.tasmanlibraries.govt.nz/assets/downloadwiz/27696` (~9803 px wide) vs
  baseline `…/assets/display/27695-600` (~1000 px)
- typical: `https://heritage.tasmanlibraries.govt.nz/assets/downloadwiz/29240` (1990×1990, 4 MP) vs
  `…/assets/display/29239-600`
- honest-smaller: `https://heritage.tasmanlibraries.govt.nz/assets/downloadwiz/27491` (honest 827×487) vs
  the upscaled-fake `…/assets/display/27490-600` (999×588)

(Master URLs download as an `attachment` JPEG — they render in `<img>`. `tasman.recollect.co.nz`
redirects to the vanity host transparently.)

## Commit

- Change commit: "Tasman Heritage (38): committed Group B ADD …" (Swift code incl. the shared fetchHTML
  redirect-UA fix + `Research/highres/` bookkeeping). The SHA is recorded by the follow-up "Record SHA …
  for collection 38" commit.
