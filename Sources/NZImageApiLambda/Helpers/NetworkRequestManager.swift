//
//  NetworkRequestManager.swift
//  NZImage
//
//  Created by Bradley Windybank on 26/03/23.
//

import Alamofire
import Foundation
import RichError
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

final class NetworkRequestManager: ValidatedRequestManager {
    struct NetworkRequestManagerError: RichError {
        typealias ErrorKind = NetworkRequestManagerErrorKind

        enum NetworkRequestManagerErrorKind: String {
            case non200StatusCode
            case nonJsonResponse
        }

        var kind: NetworkRequestManagerErrorKind
        var data: [String: String]
    }

    let validation: @Sendable (URLRequest?, HTTPURLResponse, Data?) -> Result<Void, Error> = { request, response, data in
        let acceptableStatusCodes = 200 ..< 300

        let errorData: [String: String] = [
            "request": request?.description ?? "nil request",
            "response": response.description,
            "data": data?.description ?? "nil data",
        ]

        guard acceptableStatusCodes.contains(response.statusCode) else {
            return .failure(NetworkRequestManagerError(kind: .non200StatusCode, data: errorData))
        }

        guard response.mimeType == "application/json" else {
            return .failure(NetworkRequestManagerError(kind: .nonJsonResponse, data: errorData))
        }

        return .success(())
    }

    /// The browser User-Agent every non-DigitalNZ request presents. Several sources (Recollect
    /// vanity domains, Te Papa media) 403 a request that looks like a bot.
    static let browserUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"

    /// Process-lifetime `Session`s, deliberately never released.
    ///
    /// These were previously created per call. On Linux, an Alamofire `Session` owns a
    /// `URLSession`, whose `deinit` tears down swift-corelibs-foundation's libcurl
    /// `URLSession._MultiHandle`. That teardown is unsound: `_MultiHandle.deinit` calls
    /// `curl_multi_remove_handle`/`curl_multi_cleanup`, which synchronously re-enter the
    /// registered `CURLMOPT_TIMERFUNCTION` callback; for a zero timeout that lands in
    /// `updateTimeoutTimer(to: .immediate)`, which does `queue.async { nonisolatedSelf... }` and so
    /// takes a *strong* reference to the object currently being deinitialized. The Swift runtime
    /// then aborts the whole process with "Object ... of class _MultiHandle deallocated with
    /// non-zero retain count". In a Lambda that abort surfaces as `Runtime.ExitError` and a 500,
    /// after the request has already done all of its useful work.
    ///
    /// (Source: swift-corelibs-foundation, swift-6.3-RELEASE,
    /// `Sources/FoundationNetworking/URLSession/libcurl/MultiHandle.swift`.)
    ///
    /// It is a race, so it only fires some of the time, and it fires far more often when CPU is
    /// scarce, which is exactly a 512 MB Lambda. A session that is never deallocated never runs
    /// that teardown, so keeping these alive for the life of the process removes the crash
    /// entirely. Alamofire's own `AF` default session (used by `makeRequest`) is already a
    /// process-lifetime global for the same reason.
    ///
    /// Do **not** reintroduce a per-call `Session(configuration:)` here.
    static let browserSession = makeSession(
        additionalHeaders: ["User-Agent": browserUserAgent],
        requestTimeout: nil
    )

    /// As `browserSession`, but with the short timeout used by the redirect-following status probes.
    static let shortTimeoutBrowserSession = makeSession(
        additionalHeaders: ["User-Agent": browserUserAgent],
        requestTimeout: 15
    )

    /// As `shortTimeoutBrowserSession`, plus the `Range: bytes=0-0` header that keeps the probing
    /// GETs to a single byte.
    static let rangeProbeSession = makeSession(
        additionalHeaders: ["User-Agent": browserUserAgent, "Range": "bytes=0-0"],
        requestTimeout: 15
    )

    private static func makeSession(
        additionalHeaders: [String: String],
        requestTimeout: TimeInterval?
    )
        -> Session
    {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = additionalHeaders

        if let requestTimeout {
            configuration.timeoutIntervalForRequest = requestTimeout
        }

        return Session(configuration: configuration)
    }

    func makeRequest<ResponseType: NonNullableResult & Sendable>(
        endpoint: String,
        apiKey: String? = nil,
        parameters: [String: any Sendable]? = nil
    )
        async throws -> ResponseType
    {
        var headers: HTTPHeaders? = nil

        if let apiKey {
            headers = HTTPHeaders(["Authentication-Token": apiKey])
        }

        let request = AF.request(endpoint, parameters: parameters, headers: headers)

        let result = await request
            .validate(validation)
            .serializingDecodable(ResponseType.self)
            .result

        switch result {
        case let .success(value):
            return value

        case let .failure(error):
            throw error
        }
    }

    func fetchHTML(endpoint: String) async throws -> String {
        // Also set the User-Agent as a per-REQUEST header (not only on the session config) so it is
        // carried onto the redirected URLRequest when URLSession auto-follows a redirect. Some
        // Recollect instances 301/302 the harvested *.recollect.co.nz landing host to a council vanity
        // domain (e.g. tasman.recollect.co.nz -> heritage.tasmanlibraries.govt.nz) that 403s any
        // request lacking a browser UA. Session-level httpAdditionalHeaders are NOT reliably reapplied
        // to the cross-host redirect (URLSession returns the 403 error page, so an og:image scrape sees
        // no image and falls back), whereas request headers ARE copied across the redirect.
        let headers: HTTPHeaders = ["User-Agent": Self.browserUserAgent]
        let response = await Self.browserSession.request(endpoint, headers: headers).serializingString().response

        switch response.result {
        case let .success(value):
            return value
        case let .failure(error):
            throw error
        }
    }

    /// Returns the final HTTP status code of a HEAD request **following redirects**,
    /// or 0 on failure. Used to probe whether an endpoint ultimately serves content
    /// (200) versus redirecting to an error page (e.g. a Recollect master download that
    /// 302s and then resolves to a 404). A HEAD carries no body, so this is cheap and
    /// safe at request time even for very large assets. Uses a browser User-Agent and a
    /// short timeout.
    func headStatusFollowingRedirects(endpoint: String) async -> Int {
        let response = await Self.shortTimeoutBrowserSession
            .request(endpoint, method: .head)
            .serializingData()
            .response

        return response.response?.statusCode ?? 0
    }

    /// Returns the final HTTP status code of a **1-byte ranged GET** (`Range: bytes=0-0`) following
    /// redirects, or 0 on failure. Unlike `headStatusFollowingRedirects`, this works for endpoints
    /// that reject HEAD: e.g. Te Papa's `media.tepapa.govt.nz/collection/<id>/full` returns 403 to a
    /// HEAD but 206/200 to a ranged GET when the high-res asset exists, and 500 when it does not
    /// (in-copyright records). The `Range` header keeps the transfer to a single byte, so it never
    /// downloads the full image at request time (the endpoint must honour Range — Te Papa/S3 does).
    /// Browser User-Agent + short timeout.
    func rangeStatusFollowingRedirects(endpoint: String) async -> Int {
        let response = await Self.rangeProbeSession
            .request(endpoint, method: .get)
            .serializingData()
            .response

        return response.response?.statusCode ?? 0
    }

    /// Returns the final HTTP status code AND `Content-Type` of a **1-byte ranged GET**
    /// (`Range: bytes=0-0`) following redirects, or `(0, nil)` on failure. Same rationale as
    /// `rangeStatusFollowingRedirects` (works where HEAD is rejected, e.g. presigned S3 URLs signed
    /// for GET only), but also surfaces the MIME type so a caller can branch on the resolved
    /// original's actual format (e.g. `image/jpeg` vs `image/tiff`) without downloading the body.
    func rangeContentType(endpoint: String) async -> (status: Int, contentType: String?) {
        let response = await Self.rangeProbeSession
            .request(endpoint, method: .get)
            .serializingData()
            .response

        let status = response.response?.statusCode ?? 0
        let contentType = response.response?.value(forHTTPHeaderField: "Content-Type")
        return (status, contentType)
    }

    func headRequest(endpoint: String) async throws -> (contentType: String, contentLength: Int64) {
        let response = await Self.browserSession
            .request(endpoint, method: .head)
            .serializingData()
            .response

        guard let httpResponse = response.response else {
            throw NetworkRequestManagerError(
                kind: .non200StatusCode,
                data: ["endpoint": endpoint, "error": "No response received"]
            )
        }

        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "unknown"
        let contentLength = Int64(httpResponse.value(forHTTPHeaderField: "Content-Length") ?? "0") ?? 0

        return (contentType, contentLength)
    }
}
