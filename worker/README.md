# nzimages-api (Cloudflare Worker)

The NZ Image API. It was ported in October 2026 from the Swift Lambda, which is in git history up
to commit `c599d75`. Same endpoints, same `secret` header auth, same DigitalNZ two-request
pattern, and the same per-collection URL strategies (`src/urlProcessor.ts` mirrors the Swift
`URLProcessor.swift`, legacy `switch` included). It is still a pure URL builder: JP2/TIFF
masters go through the AWS converter Lambda via `JP2_CONVERTER_URL`, signed with
`CONVERTER_SIGNING_KEY`.

| Path | What |
| --- | --- |
| `src/index.ts` | HTTP handler (`GET /image`, `GET /collections`) and the `ImageApi` RPC entrypoint |
| `src/api.ts` | Auth, exclude/collection precedence, error logging |
| `src/collections.ts` | The `collectionImageCounts` table and the weights derived from it |
| `src/digitalnz.ts` | Count request, random page, random record |
| `src/urlProcessor.ts` | Strategy registry, legacy switch, METS parsing, converter signing |
| `src/http.ts` | All outbound fetches, user agents, timeouts, the subrequest budget |
| `src/swiftUrl.ts`, `src/html.ts` | Foundation URL/percent-encoding behaviour, and the `og:image` scrape SwiftSoup did |

## Local development

```bash
npm ci
cp .dev.vars.example .dev.vars   # fill in the three secrets
npm run dev                      # http://127.0.0.1:8787

curl -H "secret: super_secret_secret" "http://127.0.0.1:8787/image?collection=Hastings%20Recollect"
```

`JP2_CONVERTER_URL` comes from `wrangler.jsonc`, so local dev points at the production
converter. With `CONVERTER_SIGNING_KEY` empty (as in `.dev.vars.example`), converter collections
serve their harvested URL instead. Only the real key makes signed URLs that converter accepts.
To test against a local converter, run `converter/local_server.py` and override the URL with
`npx wrangler dev --var JP2_CONVERTER_URL:http://127.0.0.1:8788`.

Without `DIGITALNZ_API_KEY`, DigitalNZ still answers but caps `page` at 100, so collections with
more than 10,000 images return 400 most of the time.

## Tests

```bash
npm test            # Vitest inside workerd (@cloudflare/vitest-plugin)
npm run typecheck   # src, test and scripts
npm run cf-typegen  # regenerate worker-configuration.d.ts after editing wrangler.jsonc
```

Outbound requests are mocked with MSW through `@msw/cloudflare`, and any request without a handler
fails, so tests never reach the network. The tests port the Swift Lambda's XCTest suite (also in
git history) with its expected values, plus HTTP routing/auth, RPC, the
subrequest budget, and a few network-backed strategies the Swift suite did not cover.

## Scripts

Both run directly with Node 22.18 or later (native TypeScript).

- `npm run check-collections -- [--base-url URL] [--collection NAME]... [--compare-url URL]`
  replaces CollectionTester. With `NZIMAGE_API_SECRET` set, it requests `/image` for every
  collection (or each `--collection`), checks the JSON, checks the image URL with a HEAD (falling
  back to a 1-byte ranged GET for hosts that refuse HEAD), and prints a pass/fail table. It exits
  1 on any failure. `--compare-url` also queries a second deployment (with
  `NZIMAGE_COMPARE_SECRET` if its secret differs) and reports whether both returned the same URL
  shape (host and path pattern), since records are random.
- `DIGITALNZ_API_KEY=... npm run count-collections` replaces CollectionLister. It prints live
  `category=Images` counts for every collection in the table, in the table's own TypeScript
  format, ready to paste over `collectionImageCounts`. Keep the table as counts, never fractions
  (see `../CLAUDE.md`).

## Deploy

```bash
npx wrangler deploy --secrets-file ../path/outside/repo/prod.env   # first deploy
npx wrangler secret put API_CLIENT_SECRETS                          # later rotations
npx wrangler deploy
```

`secrets.required` makes `wrangler deploy` fail until `DIGITALNZ_API_KEY`, `API_CLIENT_SECRETS`
and `CONVERTER_SIGNING_KEY` exist on the Worker, which is why the first deploy uploads them
with `--secrets-file`. Set `JP2_CONVERTER_URL` in `wrangler.jsonc` to the converter's Function
URL, and keep `CONVERTER_SIGNING_KEY` identical to the converter's. The custom domain
`nzimages-api.iolab.nz` needs the `iolab.nz` zone on the same Cloudflare account. `workers.dev`
is off.

## RPC for the website

Bind it in the website's `wrangler.jsonc`:

```jsonc
"services": [{ "binding": "API", "service": "nzimages-api", "entrypoint": "ImageApi" }]
```

```ts
const image = await env.API.image({ collection: "Te Papa Collections Online" }); // or { exclude: [...] }
const names = await env.API.collections();
```

`image()` returns exactly the object `GET /image` serialises (snake_case keys, absent fields
omitted), or `null` where `/image` would return 400. `collection` wins over `exclude`. There is
no secret check: only Workers on the same account can hold the binding. `exclude` is an array,
so it can name "Te Toi Uku, Crown Lynn and Clayworks Museum", which the comma-separated HTTP
parameter cannot.

## Free plan limits

- **50 subrequests per request.** Each redirect hop counts, so `src/http.ts` follows redirects
  itself (at most 20 per fetch) and stops at 50 per invocation, after which a fetch fails like a
  network error and the strategy falls back to the harvested URL. A normal request makes 2
  DigitalNZ calls and at most 2 more for its strategy.
- **10 ms CPU.** No DOM parser: `og:image` is read with a regex. Time spent waiting on fetches
  does not count.
- **6 connections waiting for headers.** Requests run one at a time and unread bodies are
  cancelled.

## Differences from the Swift Lambda

- Routes other than `GET /image` and `GET /collections` return `404 {"message":"Not Found"}`
  before the secret check, which is what API Gateway returned in front of the Lambda.
- The 400 body is sent as `text/plain`. The Lambda set no content type.
- Timeouts (60 s, 15 s for probes) cover the whole request, not idle time.
- DigitalNZ and Auckland Museum API calls send `User-Agent: nzimages-api` instead of
  Alamofire's.
- Scraped pages without a charset are read as UTF-8. Alamofire read them as ISO-8859-1.
