# TAPUHI JP2→JPEG Converter + SAM Migration — Session Handoff

**Status as of this handoff:** All code/config written and **fully verified locally**.
**Not yet done:** AWS deploy (`sam build`/`sam deploy`), live Chrome verification, the git
commit, and the production cutover. This doc is self-contained — a fresh session (or you)
can resume from zero context using only what's below.

Repo: `/Users/bradley/Developer/nzimageapi-lambda` · branch `main` · today is 2026-06-08.

---

## 1. What this is (the problem and the fix)

The project is a Swift 6 AWS Lambda wrapping the DigitalNZ API; for a chosen collection it
rewrites a record's image URL to the highest-resolution browser-displayable variant
(`URLProcessor.getLargerImage`).

The **TAPUHI** collection (National Library NZ, NDHA / Rosetta 8.3) was **broken in
production**: its 5-step resolve correctly reaches the preservation master, but that master
is a **JPEG 2000 (.jp2)**, and the old strategy wrapped it in `images.weserv.nl`, which
**cannot decode JP2** → HTTP 404 for every TAPUHI record. JP2 is unsupported by ~98% of
browsers (Chrome/FF/Edge never; Safari removed it in v18+), and **no free/keyless JP2→JPEG
proxy exists** (exhaustively verified — see `Research/highres/logs/025-tapuhi.md`).

**The fix (built this session):** a small self-hosted **Python + Pillow JP2→JPEG converter
Lambda** behind a **Function URL**, deployed alongside the existing Swift Lambda under **one
AWS SAM stack**. The Swift Lambda stays a pure URL builder; for TAPUHI it now emits
`<ConverterFnUrl>/?url=<encoded NDHA FL JP2 stream URL>`. The browser loads that; the
converter downloads the JP2, decodes it with Pillow, and returns a displayable JPEG. AWS
Lambda is free for this account; this avoids weserv/cloudimg/Vercel entirely.

### Request flow
```
Browser → API Gateway (HTTP API) → Swift NZImageApiFunction  (picks a random TAPUHI record)
                                       │  getLargerImage → "TAPUHI" registry → tapuhiConverter
                                       │  • 5-step NDHA resolve → FL JP2 stream URL   (existing Swift)
                                       │  • returns:  <ConverterFnUrl>/?url=<encoded FL stream URL>
                                       ▼
Browser loads that URL → Jp2ConverterFunction (Python+Pillow, Function URL)
                                       • allowlist host == ndhadeliver.natlib.govt.nz
                                       • download JP2 → Image.open → keep L / convert RGB → ≤4000px
                                       • return image/jpeg (base64), Cache-Control: 1y
```

---

## 2. What is DONE (this session)

### Files created
| Path | Purpose |
|------|---------|
| `converter/app.py` | Function-URL handler: read `url` param (400 if missing), allowlist host `== ndhadeliver.natlib.govt.nz` (403 else), download JP2 (20s timeout, 60 MB guard), Pillow-decode, keep grayscale `L`/`RGB` else convert RGB, downscale long side ≤ `MAX_DIM` (4000) via `thumbnail`, JPEG q85 `optimize` with a size guard loop (q75 → ≤3000px) to stay under the 6 MB Function URL base64 cap, return `image/jpeg` base64 + `Cache-Control: public, max-age=31536000, immutable`. Pillow imported lazily. |
| `converter/Dockerfile` | `public.ecr.aws/lambda/python:3.13`; `pip install Pillow==11.*`; **build-time HARD-ASSERT** `features.check('jpg_2000')` (build fails if JP2 decode unavailable); copies `app.py`; `CMD ["app.lambda_handler"]`. Built for **arm64**. |
| `converter/requirements.txt` | `Pillow==11.*` |
| `converter/test_local.py` | No-AWS smoke test: downloads the real FL73782300 JP2, runs the same decode path, asserts a multi-MP JPEG. |
| `converter/local_server.py` | **Dev-only** (NOT in the image): a plain HTTP server that faithfully simulates the Function URL so the whole pipeline can be tested locally without AWS. |
| `template.yaml` | SAM stack: `Jp2ConverterFunction` (container image, arm64, 1024 MB, Function URL, CORS GET) + `NZImageApiFunction` (provided.al2, arm64, makefile build, HTTP API `GET /image`). `JP2_CONVERTER_URL` injected via `!GetAtt Jp2ConverterFunctionUrl.FunctionUrl`. Secrets are `NoEcho` params (`DigitalNzApiKey`, `ApiSecret`). Outputs: `ImageApiEndpoint`, `Jp2ConverterUrl`. |
| `Makefile` | `build-NZImageApiFunction` target SAM invokes: runs `./scripts/build.sh`, copies `.build/release/NZImageApiLambda` → `$(ARTIFACTS_DIR)/bootstrap`. |
| `TAPUHI-CONVERTER-HANDOFF.md` | This doc. |

### Files modified
| Path | Change |
|------|--------|
| `Sources/NZImageApiLambda/Helpers/URLProcessor.swift` | Renamed `fetchTapuhiHighResUrl` → `resolveTapuhiFLStreamURL` (returns the FL JP2 stream URL; the weserv tail is deleted). Added non-throwing `tapuhiConverter` strategy + a `"TAPUHI"` entry in the `strategies` registry. Deleted the legacy `case "TAPUHI"` switch block and the unused `tapuhi()` wrapper. |
| `scripts/build.sh` | Added `--platform linux/arm64` to the `docker run` (pins the Swift binary arch to match `Architectures: [arm64]`). |
| `.gitignore` | Added `samconfig.toml`, `.aws-sam/`, and Python artifacts (`__pycache__/`, `*.pyc`, `.venv/`, `venv/`). |

### Swift behavior detail (`tapuhiConverter`)
- Resolves the FL stream via the existing 5-step (`resolveTapuhiFLStreamURL`).
- If that throws → returns `url.absoluteString` = the harvested **700 px `NLNZStreamGate` access
  copy** (a normal JPEG that renders everywhere). **Graceful fallback — never weserv, never raw JP2.**
- Reads `JP2_CONVERTER_URL` from the env; if unset/empty → same 700 px fallback.
- Otherwise returns `<trimmed base>/?url=<FL stream percent-encoded with .alphanumerics>`.

### Local verification — ALL PASSED (no AWS)
| Check | Result |
|------|--------|
| Pillow 11.3.0 JP2 decode (`features.check('jpg_2000')`) | `True` |
| `converter/test_local.py` on real FL73782300 | JP2 **5,965,198 B** → JPEG **3737×2148 (8.0 MP), 2,448,852 B** ✓ |
| `swift build --product NZImageApiLambda` | clean (exit 0) ✓ |
| `CollectionTester "TAPUHI"` (converter **unset**) | graceful fallback → 700 px access copy, **HTTP 200 image/jpeg** ✓ |
| Converter direct: missing `url` / bad host / real JP2 | **400 / 403 / 200 image/jpeg 3737×2148** ✓ |
| `CollectionTester "TAPUHI"` (`JP2_CONVERTER_URL`→local server) | Swift built `…/?url=<enc FL…>`, **HTTP 200 image/jpeg, "JPEG image"** ✓ |

**Canonical test record:** DigitalNZ `22479626` → `IE334493` → `FL73782300`. Title: *"Harris,
Emily Cumming, 1837-1925: Chapter III. The mysterious disappearance of Fayette. [1909]"*.
Landing: http://natlib.govt.nz/records/22479626 . Baseline access copy (700×402):
`https://ndhadeliver.natlib.govt.nz/NLNZStreamGate/get?dps_pid=IE334493`. Converter output =
3737×2148 (8.0 MP), ~28× the pixel area. A saved copy is at
`~/Downloads/tapuhi-FL73782300-converted-8MP.jpg`.

**What local tests do NOT cover (only real AWS can):** the Docker container build + its
build-time JP2 assert; the SAM/CloudFormation `!GetAtt` wiring; the arm64 Swift cross-compile
in Docker; AWS's own base64 binary-response handling on the live Function URL.

---

## 3. What is NOT done yet
1. **Deploy** the SAM stack to AWS (`sam build` + `sam deploy`).
2. **Live-verify** the converter Function URL renders in **Chrome**, and run `CollectionTester`
   against the deployed converter URL (expect ~8 MP).
3. **Commit** the code + research updates (nothing is committed yet — see §6).
4. **Cutover**: SAM creates a NEW HTTP API endpoint; point clients/DNS at it, then
   decommission the old hand-made function/API. Keep `scripts/*.sh` + the old function as the
   rollback path until verified.

---

## 4. Prerequisites to install (none are present in the dev sandbox)

| Tool | Install (macOS) | Verify |
|------|-----------------|--------|
| **AWS SAM CLI** | `brew install aws-sam-cli` | `sam --version` |
| **Docker** (must be running) | Docker Desktop, or `brew install colima docker && colima start` | `docker info` |
| **AWS CLI + credentials** | `brew install awscli` then `aws configure` (or SSO) | `aws sts get-caller-identity` |
| **Python 3 + Pillow** (only for local re-tests, optional) | system `python3`; `python -m venv .venv && .venv/bin/pip install 'Pillow==11.*'` | `.venv/bin/python -c "import PIL.features as f;print(f.check('jpg_2000'))"` → `True` |

Notes: build on **Apple Silicon** so the converter image and the Swift binary are both
**arm64** (matches `Architectures: [arm64]`). `sam` manages the S3 artifact bucket and the
ECR image repo itself — no manual ECR/docker login needed.

---

## 5. Deploy + verify (exact commands)

Run from the repo root. Secrets come from the gitignored `.env` (keys: `DIGITALNZ_API_KEY`,
`SECRET`) — never typed literally, never committed.

### 5a. Preflight
```bash
sam --version            # else: brew install aws-sam-cli
docker info              # Docker must be running
aws sts get-caller-identity   # confirms AWS creds
```

### 5b. Build + deploy (first run is guided; it writes the gitignored samconfig.toml)
```bash
cd /Users/bradley/Developer/nzimageapi-lambda
export DIGITALNZ_API_KEY=$(grep '^DIGITALNZ_API_KEY=' .env | cut -d= -f2)
export API_SECRET=$(grep '^SECRET=' .env | cut -d= -f2)

sam build      # builds the converter Docker image (fails here if Pillow JP2 decode is off)
               # and the Swift makefile target (Docker arm64 cross-compile via scripts/build.sh)

sam deploy --guided \
  --parameter-overrides DigitalNzApiKey="$DIGITALNZ_API_KEY" ApiSecret="$API_SECRET"
# Accept defaults; allow IAM role creation; allow it to create the ECR image repo.
# Capture the Outputs: Jp2ConverterUrl and ImageApiEndpoint.
```
Subsequent deploys: just `sam build && sam deploy` (choices are stored in `samconfig.toml`).

### 5c. Verify the converter Function URL
```bash
FL='https://ndhadeliver.natlib.govt.nz/delivery/DeliveryManagerServlet?dps_pid=FL73782300&dps_func=stream'
ENC=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1],safe=''))" "$FL")

curl -sL "<Jp2ConverterUrl>/?url=$ENC" -o /tmp/t.jpg
sips -g pixelWidth -g pixelHeight /tmp/t.jpg && file /tmp/t.jpg   # → JPEG ~3737×2148

# Open <Jp2ConverterUrl>/?url=$ENC in CHROME — confirm it renders (the whole point).

# Guards:
curl -s -o /dev/null -w '%{http_code}\n' "<Jp2ConverterUrl>/"                                   # 400 (missing url)
curl -s -o /dev/null -w '%{http_code}\n' "<Jp2ConverterUrl>/?url=https%3A%2F%2Fexample.com%2Fx.jp2"  # 403 (bad host)
```

### 5d. Verify the Swift pipeline against the deployed converter
```bash
export JP2_CONVERTER_URL="<Jp2ConverterUrl>"
export DIGITALNZ_API_KEY=$(grep '^DIGITALNZ_API_KEY=' .env | cut -d= -f2)
lsof -ti :7000 | xargs -r kill -9   # free the stale CollectionTester port
swift run CollectionTester "TAPUHI"  # run 2–3×; expect HTTP 200 image/jpeg, URL = <converter>/?url=…
```
A **cold** converter may make CollectionTester's 10 s HEAD report "HTTP 0" — that's a known
tester artifact for slow large-master strategies; confirm with a GET (`curl|sips`).

### 5e. Cutover
SAM made a **new** HTTP API endpoint (it does **not** adopt the existing manually-created
function/API). Point any client/DNS at the new `ImageApiEndpoint` (path `/image`, send the
`secret` header), confirm, then **separately** delete the old hand-made function/API. Keep
`scripts/*.sh` and the old function until the new endpoint is verified (rollback path).

---

## 6. The commit (do AFTER you're happy — nothing is committed yet)

**Stage only the relevant paths.** Do NOT commit the pre-existing unrelated working-tree
changes: `Research/.collection-reviewer-progress` (deleted), `Research/details-of-collections.txt`
(modified), `collection-reviewer-web/` (untracked).

```bash
cd /Users/bradley/Developer/nzimageapi-lambda

# 6a. Persist the sweep state first (see §7), then stage explicitly:
git add converter/ template.yaml Makefile \
        Sources/NZImageApiLambda/Helpers/URLProcessor.swift \
        scripts/build.sh .gitignore \
        Research/highres/progress.json Research/highres/worklist.md \
        Research/highres/README.md Research/highres/recipes.md \
        Research/highres/logs/025-tapuhi.md
# (Optionally also: git add TAPUHI-CONVERTER-HANDOFF.md  — keep or delete as you prefer.)

# 6b. GUARD: the DigitalNZ key must never be staged. This must print nothing:
git diff --cached | grep -nF "$(grep '^DIGITALNZ_API_KEY=' .env | cut -d= -f2-)" && echo "!!! KEY STAGED — ABORT" || echo "clean"

# 6c. Commit (1Password SSH signing can fail transiently with
#     "failed to fill whole buffer" — just re-run the same command):
git commit -m "TAPUHI (25): self-hosted Pillow JP2→JPEG converter + SAM migration" \
           -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"

# 6d. Record the SHA into progress.json in a SEPARATE follow-up commit (do NOT amend):
SHA=$(git rev-parse --short HEAD)
#   → edit Research/highres/progress.json: set the TAPUHI entry "commit" to "$SHA"
git add Research/highres/progress.json
git commit -m "Record SHA $SHA for collection 25 (TAPUHI)" \
           -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```
Do **not** push unless explicitly asked.

---

## 7. Research / sweep persistence (Part 5 — do at commit time)

The high-res sweep tracks 52 collections; TAPUHI is **order 25** and is currently parked
`status: "held-for-converter"` in `Research/highres/progress.json`. On approval:

1. **`Research/highres/progress.json`** — the order-25 TAPUHI entry:
   - `status`: `"held-for-converter"` → `"committed"`
   - remove `"heldForConverter": true`
   - `chosen.method`: describe `tapuhiConverter` + the SAM converter Lambda
   - `chosen.px`: `"8 MP JP2 master → JPEG via converter (e.g. 3737×2148); 700px NLNZStreamGate fallback"`
   - `chosen.urlPattern`: `"<Jp2ConverterFnUrl>/?url=<encoded …DeliveryManagerServlet?dps_pid=FL<n>&dps_func=stream>"`
   - `commit`: the work SHA (filled in by the §6d follow-up commit)
   - update `notes` (converter built + wired + verified dims); bump top-level `lastUpdated`.
2. **`Research/highres/logs/025-tapuhi.md`** — append a "Converter built + wired + verified"
   section (Pillow 11.3 decode of FL73782300 → 3737×2148; SAM stack; Swift `tapuhiConverter`;
   live Chrome render). Flip the header **Status** from HELD to committed.
3. **`Research/highres/README.md`** — "Current resume state": unpause the sweep; mark order 25
   done; **next is order 26 (Canterbury Museum)**. Remove the "⛔ Order 25 HELD — sweep PAUSED"
   block.
4. **`Research/highres/worklist.md`** — regenerate: `python3 Research/highres/gen_worklist.py`.
5. **`Research/highres/recipes.md`** — add a "Verified findings (tapuhi)" entry: weserv can't
   do JP2; the self-hosted Pillow converter Lambda is the route; allowlist + base64 6 MB cap +
   downscale ≤4000; `.alphanumerics` encoding round-trips through Function-URL decode.

**Resuming the broader sweep after this:** the next collection is the first entry (by `order`)
whose `status` ∉ {committed, no-improvement, blocked} — that becomes **order 26, Canterbury
Museum**. The per-collection loop is in `Research/highres/README.md`.

---

## 8. Reproduce the local tests (no AWS)
```bash
cd /Users/bradley/Developer/nzimageapi-lambda
python3 -m venv .venv && .venv/bin/pip install 'Pillow==11.*'   # .venv is gitignored

# (a) decoder smoke test
.venv/bin/python converter/test_local.py        # → "3737x2148 (8.0 MP) … PASS"

# (b) full pipeline: converter behind a local Function-URL stand-in + Swift
.venv/bin/python converter/local_server.py 8787 >/tmp/conv.log 2>&1 &
export JP2_CONVERTER_URL=http://127.0.0.1:8787
export DIGITALNZ_API_KEY=$(grep '^DIGITALNZ_API_KEY=' .env | cut -d= -f2)
lsof -ti :7000 | xargs -r kill -9
swift run CollectionTester "TAPUHI"              # → HTTP 200 image/jpeg via http://127.0.0.1:8787/?url=…
```
**Sandbox note:** `swift build`/`swift run` and any network (NDHA, DigitalNZ, PyPI) need the
command sandbox **disabled** in the Claude Code environment (swift spawns its own sandbox; these
hosts aren't allowlisted). Symptom if not: `sandbox-exec: sandbox_apply: Operation not permitted`.

---

## 9. Key facts, decisions, gotchas
- **Decisions locked:** introduce SAM and move BOTH functions into it (one stack); converter
  uses **buffered base64 v1** (returns JPEG bytes directly, downscaling under the 6 MB Function
  URL cap). S3+redirect caching is a documented later upgrade, not built now.
- **`!GetAtt` logical name:** web-confirmed — SAM auto-creates `AWS::Lambda::Url` with logical id
  `<FunctionLogicalId>Url`, i.e. `Jp2ConverterFunctionUrl`; the URL is `.FunctionUrl`. No
  conditions are used, so the known SAM conditional-FunctionUrl bug does not apply. If a future
  SAM version changes this, declare an explicit `AWS::Lambda::Url` and `!GetAtt` that instead.
- **Implicit HTTP API** logical id is `ServerlessHttpApi` (used in the `template.yaml` Outputs);
  `$default` stage → no stage segment in the path → `…amazonaws.com/image`.
- **Secrets:** `DigitalNzApiKey` + `ApiSecret` are `NoEcho` template Parameters passed at deploy
  time (or via the gitignored `samconfig.toml`). The DigitalNZ key (stored in `.env` as
  `DIGITALNZ_API_KEY`) lives ONLY in the gitignored `.env`; it must never appear in any committed file — grep the staged diff
  before every commit (§6b).
- **Open-proxy / SSRF:** the converter host-allowlists `ndhadeliver.natlib.govt.nz` and accepts
  GET only.
- **Grayscale:** the canonical TAPUHI master is mode `L` (grayscale); Pillow keeps it (no forced
  RGB), so the output JPEG is 1-component — correct, displayable everywhere.
- **Cost/cold start:** container Pillow cold start ~1.3–2.3 s; arm64 1024 MB; Lambda is free for
  this account; `Cache-Control: 1y` lets browsers/any future CDN cache conversions.
- **Env gotchas:** free port 7000 between `CollectionTester` runs (`lsof -ti :7000 | xargs -r kill
  -9`) or you test a stale binary; 1Password SSH signing fails transiently ("failed to fill whole
  buffer") — just re-run.

## 10. Reference docs (verified during research)
- Pillow JP2 / `features.check`: https://pillow.readthedocs.io/en/stable/handbook/image-file-formats.html
- Lambda Python container images: https://docs.aws.amazon.com/lambda/latest/dg/python-image.html
- Lambda Function URL binary / base64 / 6 MB limit: https://docs.aws.amazon.com/lambda/latest/dg/urls-invocation.html
- SAM function resource / `FunctionUrlConfig` / makefile build: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/sam-resource-function.html
- TAPUHI investigation + proven Pillow decode: `Research/highres/logs/025-tapuhi.md`

---

## 11. One-paragraph TL;DR for a fresh agent
All converter + SAM + Swift code is written and verified locally (Pillow decodes the real NDHA
JP2 to an 8 MP JPEG; the full Swift→converter pipeline works against a local Function-URL
stand-in). Nothing is committed. The user must `brew install aws-sam-cli`, run Docker, configure
AWS creds, then `sam build && sam deploy --guided` (passing `DigitalNzApiKey`/`ApiSecret` from
`.env`), verify the converter renders in Chrome and `CollectionTester "TAPUHI"` returns ~8 MP,
then commit per §6 (stage explicit paths; grep the staged diff for the API key; work commit +
separate "Record SHA" commit) and persist the sweep state per §7 (flip order 25 → committed,
unpause to order 26). Do not commit the unrelated `collection-reviewer-web/` or
`Research/details-of-collections.txt` changes.
