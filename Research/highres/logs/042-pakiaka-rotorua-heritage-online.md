# Order 42 — Pakiaka Rotorua Heritage Online

- **Group:** B (ADD — was NOT in `collectionWeights`, so never served)
- **Platform (progress.json):** `boutique` → **RECLASSIFIED to `recollect`** (Recollect Ltd / NZMS, the classic `*.recollect.co.nz` `downloadwiz` generation — NOT signed-IIIF, NOT Axiell)
- **Host:** `rotorua.recollect.co.nz` → **vanity redirect** `pakiaka.rotorualibrary.govt.nz` · **content_partner:** Rotorua Library — Te Aka Mauri
- **rights:** "users of our heritage resources uphold the mana and dignity of the people, communities and places depicted within… No cultural/ethical restrictions apply. However, copyright may apply." (no license code; served publicly, no login-wall)
- **rawItemCount (progress.json snapshot):** 1,374 · **live (primary_collection, category=Images):** **1,571** (the collection grew since the snapshot — rawItemCount updated to 1,571)
- **Status:** committed (user-approved 2026-06-16)
- **Strategy:** **REUSED `recollectOgImageMaster`** (no new strategy code) — the 9th `boutique`-mislabel-actually-Recollect, the 5th TWO-ASSET case, and the 2nd with a Clutha/Tasman-style vanity redirect. Registry entry + `collectionWeights` 0.002 only. **Pure code change, no AWS deploy.**

## Identity

"Pakiaka Rotorua Heritage Online" is the DigitalNZ `primary_collection` **and** `display_collection`
(`collection` field == same). The Lambda queries `and[primary_collection][]` + `and[category][]=Images`
and dispatches on `result.collection` (= `display_collection`), so the single key works. `object_url`
null; `landing_url` = `http://rotorua.recollect.co.nz/nodes/view/<n>`.

## Platform detection

Harvested `large_thumbnail_url` == `thumbnail_url` = `https://rotorua.recollect.co.nz/assets/display/<thumbId>-280`
(**the small `-280` thumbnail**, not `-600`). Landing `…/nodes/view/<n>`. Classic Recollect `downloadwiz`
shape (cf. Hastings 6 / Clutha 36 / Kinder 37 / Tasman 38 / Western Bay 39 / Far North 41).

## ★ Vanity redirect + UA-gate (why recollectOgImageMaster, not recollectLargest)

- **Vanity redirect:** `rotorua.recollect.co.nz/assets/…` 301/302s to **`pakiaka.rotorualibrary.govt.nz`**
  (Clutha 36 / Tasman 38 style). The node `og:image` already points to the **vanity host**
  (`https://pakiaka.rotorualibrary.govt.nz/assets/display/<id>-max?u=<32-hex>`) — 64/64 sampled.
- **UA-gate:** every `assets/…` URL **403s without a browser User-Agent** (same as Tasman 38 / Far North 41);
  the `?u=<32-hex>` query on the og:image is a **cache-buster**, not a signed token.
- **Consequence:** `recollectLargest` would (a) rip the harvested **thumb** id (404 on `downloadwiz` for the
  ~78% two-asset records → regression) and (b) build on the recollect host, so the `downloadwiz` HEAD probe
  would have to follow a **cross-host** redirect to the vanity host, where the session-level UA may not be
  reapplied (cf. the Tasman `fetchHTML` finding) → 403 → fall back to `-max`. **`recollectOgImageMaster`
  builds the master URL from the `og:image`'s OWN host** (the vanity domain), so the probe is a **direct**
  request (no redirect) and the session UA applies — verified 64/64 `downloadwiz` 200.

## ★ TWO-ASSET + display pyramid goes past 1000px

- Display tiers (record 1153): `-280` 499×333 (0.17 MP), `-600` 999×667 (0.67 MP), **`-max` 1845×1232
  (2.27 MP)** — unlike Far North (where `-600`==`-max`), the Pakiaka display pyramid extends past 1000px.
- `downloadwiz/<ogId>` is **≥ `-max` for every record**: a **true larger master for ~40%** (26/64, up to
  6000×4000 = 24 MP), **== `-max` for ~60%** (38/64; small originals where the master equals the display
  derivative). Either way the chosen output beats the small `-280` baseline.
- **og id == thumb id for 14/64; differs (two-asset) for 50/64 (~78%)** — confirmed: for two-asset records
  `downloadwiz/<thumbId>` 404s while `downloadwiz/<ogId>` 200s (e.g. thumb 11610→404, og 12166→200).

## Measurements (Discovery Playbook)

**Uniform survey (64 records across all 16 pages, og-path = the `recollectOgImageMaster` route):**
- `og:image` present: **64/64 (100%)**; og host == vanity: **64/64**; og id == thumb id: 14; **differs: 50 (~78%)**.
- **og-`downloadwiz` 200: 64/64 (100%)** — zero stale/dead, zero login-walls.
- `downloadwiz` vs `-max`: **> `-max` 26 / == `-max` 38 / < `-max` 0**.
- Pixel (chosen vs harvested `-280`): **63 win / 1 equal / 0 honest-smaller / 0 fails**; area ratio
  **min 1.0, median 11.66×, max 144.14×** (up to 6000×4000 = 24 MP from a 500×333 baseline).
- The 1 equal (id 56569297): a genuinely tiny **380×300** native where `-280` already had the full image.

## Decision

**Group B ADD via the existing `recollectOgImageMaster`** — the same reusable two-asset strategy as Far
North 41 / Western Bay 39 / Tasman 38 / Kinder 37, no new strategy code, no `recollectDomainMap` entry
(the helper uses the og:image's own vanity host), no AWS deploy.

## Implementation

- `URLProcessor.swift` — registry entry `strategies["Pakiaka Rotorua Heritage Online"] =
  { await recollectOgImageMaster(...) }`. No change to any strategy function (zero regression risk).
- `NZImageApi.swift` — `collectionWeights["Pakiaka Rotorua Heritage Online"] = 0.002` (provisional).
- `progress.json` — platform `boutique` → `recollect`; rawItemCount 1374 → 1571; status; baseline / chosen / notes.

## Verification

- `swift build` exit 0.
- CollectionTester ×6 → **6/6 HTTP 200** `downloadwiz` masters on the vanity host (`display_collection`
  confirms dispatch): ids 13016 / 16320 / 17831 / 18000 / 12035 / 17072 → decoded **0.6 / 2.2 / 9.1 / 1.1 /
  10.8 / 24.0 MP**. 0 fallbacks observed.
- Master headers = `application/octet-stream` + `Content-Disposition: attachment` +
  `X-Content-Type-Options: nosniff` — byte-identical to the approved Clutha 36 / Hastings 6 / Far North 41
  masters (renders in `<img>`; direct navigation downloads the `.jpg`).
- Regression: additive only (new registry entry + new weight); every strategy function untouched.

## Example live URLs (for the approval gate)

- *"Postcard showing Whakarewarewa, Rotorua"* (node 4): baseline `…/assets/display/1153-280` (499×333,
  0.17 MP) → master `https://pakiaka.rotorualibrary.govt.nz/assets/downloadwiz/1153` (**1845×1232, 2.27 MP, 13.7×**).
- *"Reconstruction of the forge and anvil … Te Wairoa Village"* (node 3386): baseline `…/display/16853-280`
  (500×333) → master `…/assets/downloadwiz/16884` (**6000×4000, 24 MP, 144×**).

## Commit

- Change commit: "Pakiaka Rotorua Heritage Online (42): committed Group B ADD …" (registry entry reusing
  `recollectOgImageMaster` + weight + `Research/highres/` bookkeeping). The SHA is recorded by the
  follow-up "Record SHA … for collection 42" commit.
