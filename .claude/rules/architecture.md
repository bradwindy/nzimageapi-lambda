# API Worker architecture

Read this when touching request handling, adding or adjusting a collection's image-URL
strategy, or working with the DigitalNZ data models.

The API is the TypeScript Cloudflare Worker `nzimages-api` in `worker/`, served at
`https://nzimages-api.iolab.nz`. It is a pure URL builder: it returns JSON metadata pointing at
the highest-resolution image URL it can reach, never image bytes. It is a 1:1 port of the Swift
Lambda, which lives in git history up to commit `c599d75`.

## Request flow

1. `worker/src/index.ts`, the default `fetch` handler. Anything other than `GET /image` or
   `GET /collections` gets `404 {"message":"Not Found"}` before the auth check. Then it checks the
   `secret` header with `authorizedConsumer` (`api.ts`): unset or empty `API_CLIENT_SECRETS` is a
   `500` (fail closed), a missing or wrong header is a `401`. Every `name:secret` entry is
   compared with no early exit, and both sides are SHA-256 hashed first so `timingSafeEqual`
   compares equal lengths. A match logs `Authorized consumer: <name>`.
2. `GET /collections` returns `collectionNames()` (`collections.ts`). `GET /image` reads the
   `collection` and `exclude` query parameters and calls `requestImage` (`api.ts`).
3. `requestImage` and `image` (`api.ts`). An explicit `collection` wins and `exclude` is ignored.
   Otherwise `exclude` filters the weighted-random pick (`filteredCollectionWeights`). Any error is
   logged and becomes `null`, which `index.ts` returns as a `400`.
4. `newResult` (`digitalnz.ts`) runs the DigitalNZ two-request pattern (below) and hands the
   chosen record to `getLargerImage`.
5. `getLargerImage` (`urlProcessor.ts`) looks up the record's `display_collection` in the strategy
   registry, falls back to `legacyStrategy`, and returns the record with `large_thumbnail_url`
   upgraded to the highest resolution reachable.

`createContext` (`context.ts`) builds one `RequestContext` per API request: a new `Http` (so a new
subrequest budget), the env bindings, and a logger.

## RPC entrypoint

`ImageApi` (`index.ts`) is a `WorkerEntrypoint` for service bindings. The website Worker
`nzimages-web` (separate repo) binds it and calls:

- `image({ collection, exclude })`: both optional. Returns exactly the object `GET /image`
  serialises, or `null` where `/image` would return `400`. Same `requestImage` path and precedence.
- `collections()`: the same list as `GET /collections`.

There is no secret check on RPC. Only Workers on the same Cloudflare account can hold the binding.
`exclude` is an array here, so it can name a collection that contains a comma.

## Collections and weights

`collectionImageCounts` (`collections.ts`) holds each collection's DigitalNZ `category=Images`
count. `collectionWeights()` derives the pick weights from those counts, so they always sum to 1.
Keep the table as counts, never fractions. Refresh it with `npm run count-collections` (needs
`DIGITALNZ_API_KEY`) and paste the output over the table. `GET /collections` and the random pick
only see collections in this table. An explicit `collection` can name any DigitalNZ collection.

## DigitalNZ two-request pattern

DigitalNZ has no random sort, so `newResult` never asks for "a page of random results". Instead:

1. First request: `per_page=0` against `https://api.digitalnz.org/records.json`, filtered to
   `category=Images` and the chosen `primary_collection`, with the key sent as the
   `Authentication-Token` header. This only reads `result_count`.
2. `pageCount(resultCount, 100)` ceiling-divides, capped at DigitalNZ's hard `page <= 50000` limit.
   Zero pages throws `noResults`.
3. Fetch a random page in `1...pageCount`, then pick a random record within what that page
   actually returned. The last page is often short, so this samples the real page size, not 100.

## Models and parsing

`NZImage` (`models.ts`) is one DigitalNZ record in exactly the shape `GET /image` returns:
snake_case keys, absent fields omitted, fields in the Swift `CodingKeys` order. Decoding mirrors
Swift's `JSONDecoder` with all-optional properties. A missing or null key is left out, but a
present value of the wrong type throws `DecodingError` and fails the whole response. URL fields go
through `swiftURLString` (`swiftUrl.ts`), which reproduces Foundation's `URL(string:)`, so
returned URLs match what the Swift Lambda returned.

The check helpers throw `ApiError` (`errors.ts`, the Swift `RichError`s) instead of passing on
missing data:

- `checkResponseNonNull` and `checkSearchNonNull`: the response has `search`, `result_count` and
  `results`.
- `checkHasTitleAndLargeImage`: the record has `id`, `title` and `large_thumbnail_url`, the minimum
  needed to return it.

`decodeAKLMuseumResponse` decodes the Auckland Museum API response that its strategy reads.

## Strategy registry

`strategies` (`worker/src/urlProcessor.ts`) maps a DigitalNZ `display_collection` name to a
`URLStrategy`: `(record, url, context) => string | Promise<string>`, where `url` is the record's
current `large_thumbnail_url`. Keys are NFC-normalised, so names like `Manawatū Heritage` match whatever
Unicode form DigitalNZ sends. `getLargerImage` checks the registry first. Collections not in it
fall through to `legacyStrategy`, a `switch` kept from the Swift code, whose default is
`passthrough`. **Every new or touched collection gets a registry entry**, not a new `switch` case.

A strategy that can't improve on the harvested URL returns `url`. Strategies that fetch catch
their own failures and return `url`, so a slow or broken source still yields an image.

To add or change a collection's strategy:

1. Check `Research/highres/recipes.md` for the per-platform recipe (Recollect, eHive IIIF, Vernon,
   NDHA/Rosetta, CONTENTdm/V&A IIIF, Flickr and others). Most new collections fit an existing one.
2. Add or edit the entry in `strategies`, reusing the platform helpers already in
   `urlProcessor.ts` (`recollectLargest`, `recollectDisplayMax`, `recollectOgImageMaster`,
   `ehiveIIIFLargest`, `stringSwap` and so on). Fetch only through `context.http`.
3. If the master needs format conversion (JP2/TIFF), route it through `signedConverterURL`
   instead of decoding in the Worker. See [`converter.md`](converter.md).
4. For a new collection, add its count to `collectionImageCounts` so it is listed and picked.
5. Add a focused test: `worker/test/urlProcessor.test.ts` for pure URL rewrites,
   `worker/test/strategies.test.ts` for strategies that fetch (mocked with MSW).
6. Validate end to end from `worker/` with `NZIMAGE_API_SECRET` set:
   `npm run check-collections -- --collection "<name>"`. The default base URL is `wrangler dev`
   (`npm run dev`, `http://127.0.0.1:8787`). Add `--base-url https://nzimages-api.iolab.nz` to
   check the deployed Worker, which is subject to the WAF rate limit below.

## HTTP client rules

All outbound HTTP goes through the request's `Http` instance (`worker/src/http.ts`). Never call
`fetch` directly.

- **Subrequest budget.** The Free plan allows 50 subrequests per request, and every redirect hop
  counts. `Http` follows redirects itself (`redirect: "manual"`, at most 20 per fetch) and counts
  each hop against `MAX_SUBREQUESTS` (50). Past that, the next fetch throws
  `subrequestBudgetExhausted`, which strategies treat like a network error.
- **Timeouts.** `AbortSignal.timeout` covers the whole request, redirects included: 60 s for JSON
  and HTML, 15 s for probes.
- **User agents.** `getJSON` (DigitalNZ and the Auckland Museum API) sends
  `User-Agent: nzimages-api`. Scrapes and probes send `BROWSER_USER_AGENT`, because several sources
  (Recollect vanity domains, Te Papa media) block bots.
- **Methods.** `getJSON` requires a 2xx `application/json` response. `fetchHTML` accepts any
  status but throws on an empty body. `headStatus` and `rangeProbe` (a 1-byte `Range: bytes=0-0`
  GET for hosts that refuse HEAD) return status `0` on failure instead of throwing.
- **Bodies.** Unread probe and redirect bodies are cancelled. Workers allow 6 connections waiting
  for headers at once, and strategies make their fetches one after another.
- **No DOM parser.** `og:image` is read with a regex (`html.ts`), because a parser would not fit
  the 10 ms CPU limit on large landing pages.

## Free plan limits

The Worker runs on the Cloudflare Workers Free plan, which never bills.

- **100,000 requests a day**, shared by every Worker on the account, reset at 00:00 UTC. Over the
  limit, every Worker on the account returns error 1027 until the reset.
- **10 ms CPU per request.** Measured live: typically 3-7 ms, max 8 ms over 96 requests, plus one
  11 ms outlier that still succeeded. Time spent waiting on fetches does not count.
- **50 subrequests per request**, enforced by `Http` (above).

A WAF rate-limiting rule on the `iolab.nz` zone blocks an IP that sends more than 30 requests in
10 s to `/image`, `/collections`, `/api/image` or `/api/collections`, for 10 s. See
`docs/ACCESS-CONTROL.md` §8.

## Known bugs carried over from Swift

Kept unchanged by the port. Don't describe them as fixed.

- Victoria and Albert Museum image URLs 404.
- A DigitalNZ record with a non-string `date` fails decoding of the whole page, so the request
  returns 400.
- The HTTP `exclude` parameter splits on commas, so it can't name
  "Te Toi Uku, Crown Lynn and Clayworks Museum". The RPC `exclude` array can.
- "New Zealand Portrait Gallery NZMuseums" has 0 results, so requests for it return 400.
