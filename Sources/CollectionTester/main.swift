//
//  main.swift
//  CollectionTester
//
//  Tests all collections to ensure image URLs are valid
//

import Foundation
import NZImageApiLambdaLib

actor TestResults {
    var results: [String: CollectionTestResult] = [:]

    func record(collection: String, success: Bool, url: URL?, error: String? = nil, statusCode: Int? = nil) {
        if results[collection] == nil {
            results[collection] = CollectionTestResult(collectionName: collection)
        }

        if success {
            results[collection]?.successCount += 1
            if let url = url {
                results[collection]?.successfulUrls.append(url)
            }
        } else {
            results[collection]?.failureCount += 1
            if let error = error {
                results[collection]?.errors.append(error)
            }
            if let statusCode = statusCode {
                results[collection]?.failedStatusCodes.append(statusCode)
            }
            if let url = url {
                results[collection]?.failedUrls.append(url)
            }
        }
    }

    func getResults() -> [String: CollectionTestResult] {
        return results
    }
}

struct CollectionTestResult {
    var collectionName: String
    var successCount: Int = 0
    var failureCount: Int = 0
    var successfulUrls: [URL] = []
    var failedUrls: [URL] = []
    var errors: [String] = []
    var failedStatusCodes: [Int] = []

    var totalTests: Int {
        successCount + failureCount
    }

    var successRate: Double {
        guard totalTests > 0 else { return 0 }
        return Double(successCount) / Double(totalTests) * 100
    }
}

@main
struct CollectionTester {
    static func main() async throws {
        print("🧪 Starting Collection Image URL Validation Tests\n")
        print("=" + String(repeating: "=", count: 79))

        let api = NZImageApi()
        let testResults = TestResults()
        let testsPerCollection = 5

        let collections = Array(NZImageApi.collectionWeights.keys)
        print("\n📊 Testing \(collections.count) collections with \(testsPerCollection) requests each")
        print("=" + String(repeating: "=", count: 79) + "\n")

        var testNumber = 0
        let totalTests = collections.count * testsPerCollection

        for collection in collections {
            print("📁 Testing: \(collection)")

            for attempt in 1...testsPerCollection {
                testNumber += 1

                print("  [\(testNumber)/\(totalTests)] Attempt \(attempt)/\(testsPerCollection)...", terminator: " ")

                guard let result = await api.image(collection: collection) else {
                    print("❌ Failed to fetch image")
                    await testResults.record(
                        collection: collection,
                        success: false,
                        url: nil,
                        error: "Failed to fetch image from API"
                    )
                    continue
                }

                guard let imageUrl = result.largeThumbnailUrl else {
                    print("❌ No large thumbnail URL")
                    await testResults.record(
                        collection: collection,
                        success: false,
                        url: nil,
                        error: "No largeThumbnailUrl in response"
                    )
                    continue
                }

                // Test if the URL is accessible
                let urlStatus = await validateUrl(imageUrl)

                switch urlStatus {
                case .success:
                    print("✅ Valid (\(imageUrl.absoluteString.prefix(60))...)")
                    await testResults.record(
                        collection: collection,
                        success: true,
                        url: imageUrl
                    )

                case .httpError(let statusCode):
                    print("❌ HTTP \(statusCode)")
                    await testResults.record(
                        collection: collection,
                        success: false,
                        url: imageUrl,
                        error: "HTTP error \(statusCode)",
                        statusCode: statusCode
                    )

                case .networkError(let error):
                    print("❌ Network error: \(error)")
                    await testResults.record(
                        collection: collection,
                        success: false,
                        url: imageUrl,
                        error: "Network error: \(error)"
                    )

                case .invalidResponse:
                    print("❌ Invalid response")
                    await testResults.record(
                        collection: collection,
                        success: false,
                        url: imageUrl,
                        error: "Invalid response from server"
                    )
                }

                // Small delay to avoid overwhelming servers
                try? await Task.sleep(for: .milliseconds(500))
            }

            print("")
        }

        // Print summary
        print("\n" + String(repeating: "=", count: 80))
        print("📈 TEST RESULTS SUMMARY")
        print(String(repeating: "=", count: 80) + "\n")

        let results = await testResults.getResults()
        var overallSuccess = 0
        var overallFailure = 0
        var failedCollections: [String] = []

        for collection in collections {
            guard let result = results[collection] else { continue }

            overallSuccess += result.successCount
            overallFailure += result.failureCount

            let statusSymbol = result.successRate == 100 ? "✅" : result.successRate >= 80 ? "⚠️" : "❌"

            print("\(statusSymbol) \(collection)")
            print("   Success: \(result.successCount)/\(result.totalTests) (\(String(format: "%.1f", result.successRate))%)")

            if result.failureCount > 0 {
                failedCollections.append(collection)
                print("   Failures: \(result.failureCount)")

                // Show unique error types
                let uniqueErrors = Set(result.errors)
                for error in uniqueErrors {
                    let count = result.errors.filter { $0 == error }.count
                    print("     - \(error) (\(count)x)")
                }

                // Show unique status codes
                let uniqueStatusCodes = Set(result.failedStatusCodes)
                if !uniqueStatusCodes.isEmpty {
                    print("     HTTP Status Codes: \(uniqueStatusCodes.sorted().map(String.init).joined(separator: ", "))")
                }

                // Show a sample failed URL
                if let firstFailedUrl = result.failedUrls.first {
                    print("     Sample URL: \(firstFailedUrl.absoluteString)")
                }
            }
            print("")
        }

        // Overall statistics
        print(String(repeating: "=", count: 80))
        let completedTests = overallSuccess + overallFailure
        let overallSuccessRate = Double(overallSuccess) / Double(completedTests) * 100

        print("🎯 OVERALL RESULTS:")
        print("   Total Tests: \(completedTests)")
        print("   Successful: \(overallSuccess) (\(String(format: "%.1f", overallSuccessRate))%)")
        print("   Failed: \(overallFailure)")
        print("   Collections with failures: \(failedCollections.count)/\(collections.count)")

        if !failedCollections.isEmpty {
            print("\n⚠️  Collections with failures:")
            for collection in failedCollections {
                print("   - \(collection)")
            }
        }

        print(String(repeating: "=", count: 80))

        // Exit with appropriate code
        if overallFailure > 0 {
            print("\n❌ Tests completed with failures")
            exit(1)
        } else {
            print("\n✅ All tests passed!")
            exit(0)
        }
    }

    static func validateUrl(_ url: URL) async -> URLValidationResult {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 30

        // Set a user agent to avoid being blocked
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .invalidResponse
            }

            if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                return .success
            } else {
                return .httpError(httpResponse.statusCode)
            }
        } catch {
            return .networkError(error.localizedDescription)
        }
    }
}

enum URLValidationResult {
    case success
    case httpError(Int)
    case networkError(String)
    case invalidResponse
}
