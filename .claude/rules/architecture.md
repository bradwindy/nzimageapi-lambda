# Swift Lambda architecture

Read this when touching request handling, adding/adjusting a collection's image-URL
strategy, or working with the DigitalNZ data models.

## Request flow

1. `Sources/NZImageApiLambda/App.swift` — `@main`, wires `LambdaRuntime` (swift-aws-lambda-runtime v2 closure API) to `NZImageApiLambda.handle`.
2. `NZImageApiLambda.handle` (`Sources/NZImageApiLambda/NZImageApiLambda.swift`) — checks the `secret` header against `API_CLIENT_SECRETS` (see CLAUDE.md's Architecture essentials for the auth model), then routes `GET /image`.
3. `NZImageApi.image(collection:logger:)` (`Sources/NZImageApiLambda/NZImageApi.swift`) — picks a collection (weighted-random if none requested) and calls the data source.
4. `DigitalNZAPIDataSource.newResult` (`Sources/NZImageApiLambda/Data Sources/DigitalNZAPIDataSource.swift`) — the DigitalNZ two-request pattern (below), then hands the chosen result to `URLProcessor.getLargerImage`.
5. `URLProcessor.getLargerImage` (`Sources/NZImageApiLambda/Helpers/URLProcessor.swift`) — looks up the collection in the strategy registry first, falls back to a legacy `switch`, and returns the result with its image URL upgraded to the highest resolution reachable.

## DigitalNZ two-request pattern

`DigitalNZAPIDataSource.newResult` never fetches "a page of random results" directly —
DigitalNZ has no random-sort. Instead:

1. First request: `per_page=0` against `https://api.digitalnz.org/records.json` (key sent
   as the `Authentication-Token` header) just to get `resultCount` for the chosen collection.
2. Compute `pageCount = ceil(resultCount / 100)`, capped at DigitalNZ's hard `page<=50000` limit.
3. Pick a random page in `1...pageCount`, then a random result within whatever that page
   actually returned (the last page is often short, so this samples the *actual* page size,
   not the assumed 100).

`Self.pageCount(forResultCount:perPage:)` is the ceiling-divide helper — unit-tested directly.

## Models

- `NZRecordsResult` (`Sources/NZImageApiLambda/Models/NZRecordsResult.swift`) — the record
  shape, `Codable` with explicit snake_case `CodingKeys` (`thumbnail_url`, `large_thumbnail_url`,
  `display_collection` → `collection`, etc). Two validation helpers:
  `checkNonNull()` (full response validity) and `checkHasTitleAndLargeImage()` (the minimum
  needed to proceed).
- `NonNullableResult` (`Sources/NZImageApiLambda/Helpers/NonNullableResult.swift`) — the
  protocol both `NZRecordsResult` and `NZRecordsResponse`/`NZRecordsSearch` conform to, used
  to fail fast with a `RichError` instead of force-unwrapping optionals from an external API.

## URLProcessor strategy-registry pattern

`URLProcessor.strategies: [String: URLStrategy]` maps a DigitalNZ `display_collection` name
to a `URLStrategy` closure (`@Sendable (result: NZRecordsResult, url: URL) async throws -> String`).
`getLargerImage` checks the registry first; only collections not yet migrated fall through
to the legacy `switch` statement below it. **Every new or touched collection should get a
registry entry**, not a new `switch` case — the `switch` exists purely as a shrinking
migration remnant from the high-res sweep.

To add or change a collection's strategy:
1. Check `Research/highres/recipes.md` for the per-platform recipe (Recollect, eHive IIIF,
   Vernon Browser, NDHA/Rosetta, CONTENTdm/V&A IIIF, Flickr, etc.) — most new collections
   fit an existing platform pattern.
2. Add/edit the entry in `strategies`, reusing the shared per-platform helper functions
   already in `URLProcessor.swift` (e.g. `recollectLargest`, `recollectDisplayMax`) where possible.
3. If the master needs format conversion (JP2/TIFF), route through `signedConverterURL`
   instead of decoding in-process — see [`converter.md`](converter.md).
4. Validate end-to-end with `./Sources/Testing/CollectionTester/test-collection.sh "<Collection>"`.

## HTTP client lifecycle

All outbound HTTP goes through `NetworkRequestManager`
(`Sources/NZImageApiLambda/Helpers/NetworkRequestManager.swift`), which uses Alamofire. Two rules,
both there to keep the Lambda process alive:

- **DigitalNZ requests** use Alamofire's global `AF` session.
- **Everything else** (HTML scrapes, HEAD probes, ranged GET probes) uses one of three
  process-lifetime `static let` `Session`s on `NetworkRequestManager`, differing only in request
  timeout and whether they send `Range: bytes=0-0`.

Nothing may create a `Session` (or a bare `URLSession`) per call. On Linux, releasing one runs
`URLSession._MultiHandle.deinit` in swift-corelibs-foundation, which calls `curl_multi_cleanup`;
that synchronously re-enters the registered `CURLMOPT_TIMERFUNCTION`, and for a zero timeout
`updateTimeoutTimer(to: .immediate)` does `queue.async { nonisolatedSelf... }`, taking a strong
reference to the object being deinitialized. The Swift runtime then aborts (or segfaults on the
dangling reference), and Lambda reports `Runtime.ExitError` with a 500 even though the handler had
already produced its answer. It is a race, so it only fires under scheduling pressure, which a
512 MB Lambda has plenty of.

To reproduce or re-verify, run the Lambda's local server in a Linux container under CPU pressure
and hammer `POST /invoke`; a per-call-session build fails several requests in 40, a shared-session
build fails none. `Tests/NZImageApiLambdaTests/NetworkRequestManagerSessionTests.swift` pins the
shared-session invariant and each session's configuration.
