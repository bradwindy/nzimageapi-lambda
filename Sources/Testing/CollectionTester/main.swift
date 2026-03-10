//
//  main.swift
//  CollectionTester
//
//  Tests collections by building and running the lambda server locally
//

import Foundation
import LambdaTesting

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

@main
struct CollectionTester {
    static func main() async throws {
        let arguments = parseArguments()

        if arguments.showHelp {
            printHelp()
            return
        }

        let serverManager = LambdaServerManager(port: arguments.port, host: arguments.host)

        // Build the lambda
        print("🔨 Building lambda...")
        guard await serverManager.buildLambda(clean: arguments.cleanBuild) else {
            printError("Build failed")
            exit(1)
        }
        print("✅ Build complete\n")

        // Start the lambda server
        print("🚀 Starting local lambda server on port \(arguments.port)...")
        print("⏳ Waiting for server to start...")
        guard await serverManager.startServer() else {
            printError("Failed to start lambda server")
            exit(1)
        }
        print("✅ Server is ready!\n")

        // Ensure cleanup on exit
        defer {
            print("\n🧹 Shutting down lambda server...")
            Task {
                await serverManager.stopServer()
            }
        }

        // Make the request
        print("🔍 Making request...")
        if let collection = arguments.collection {
            print("📁 Collection: \(collection)")
        } else {
            print("🎲 Using random collection")
        }
        print("")

        let response = await serverManager.makeRequest(collection: arguments.collection)

        guard let response = response else {
            printError("Failed to make request")
            exit(1)
        }

        // Check status code
        if response.statusCode != 200 {
            printError("Request failed with status code: \(response.statusCode)")
            print("\nResponse:")
            if let bodyString = String(data: response.rawBody, encoding: .utf8) {
                print(bodyString)
            }
            exit(1)
        }

        print("✅ Success!\n")

        // Display response
        printResponse(response)

        // Verify image URL
        print("\n🔍 Verifying image URL...")

        guard let imageUrlString = response.largeThumbnailUrl else {
            print("⚠️  No large_thumbnail_url in response")
            return
        }

        print("📸 Image URL: \(imageUrlString)")

        let (httpStatus, contentType, fileType) = await serverManager.validateImageURL(imageUrlString)

        if httpStatus == 200 {
            print("✅ Image URL is valid (HTTP \(httpStatus))")
            print("   Content-Type: \(contentType)")
            print("   File Type: \(fileType)")
        } else {
            printError("Image URL returned HTTP \(httpStatus)")
            exit(1)
        }
    }

    // MARK: - Argument Parsing

    struct Arguments {
        var collection: String?
        var port: Int = 7000
        var host: String = "127.0.0.1"
        var showHelp: Bool = false
        var cleanBuild: Bool = false
    }

    static func parseArguments() -> Arguments {
        var args = Arguments()
        let arguments = CommandLine.arguments
        var i = 1

        while i < arguments.count {
            let arg = arguments[i]

            switch arg {
            case "-h", "--help":
                args.showHelp = true
            case "--clean":
                args.cleanBuild = true
            case "--port":
                if i + 1 < arguments.count, let port = Int(arguments[i + 1]) {
                    args.port = port
                    i += 1
                }
            case "--host":
                if i + 1 < arguments.count {
                    args.host = arguments[i + 1]
                    i += 1
                }
            default:
                if !arg.hasPrefix("-") {
                    args.collection = arg
                }
            }
            i += 1
        }

        return args
    }

    // MARK: - Output Helpers

    static func printResponse(_ response: LambdaImageResponse) {
        if let id = response.id {
            print("  \"id\": \(id),")
        }
        if let title = response.title {
            print("  \"title\": \"\(title)\",")
        }
        if let description = response.description {
            print("  \"description\": \"\(description)\",")
        }
        if let thumbnailUrl = response.thumbnailUrl {
            print("  \"thumbnail_url\": \"\(thumbnailUrl)\",")
        }
        if let largeThumbnailUrl = response.largeThumbnailUrl {
            print("  \"large_thumbnail_url\": \"\(largeThumbnailUrl)\",")
        }
        if let objectUrl = response.objectUrl {
            print("  \"object_url\": \"\(objectUrl)\",")
        }
        if let displayCollection = response.displayCollection {
            print("  \"display_collection\": \"\(displayCollection)\",")
        }
        if let landingUrl = response.landingUrl {
            print("  \"landing_url\": \"\(landingUrl)\",")
        }
        if let sourceUrl = response.sourceUrl {
            print("  \"source_url\": \"\(sourceUrl)\",")
        }
    }

    static func printError(_ message: String) {
        print("\u{001B}[31m❌ Error: \(message)\u{001B}[0m")
    }

    static func printHelp() {
        print("""
        CollectionTester - Test NZ Image API Lambda locally

        USAGE:
            CollectionTester [COLLECTION] [OPTIONS]

        ARGUMENTS:
            COLLECTION          Collection name to test (optional, random if not specified)

        OPTIONS:
            --port <port>       Port for lambda server (default: 7000)
            --host <host>       Host for lambda server (default: 127.0.0.1)
            --clean             Do a clean build before testing
            -h, --help          Show this help message

        EXAMPLES:
            # Test random collection
            CollectionTester

            # Test specific collection
            CollectionTester "Te Papa Collections Online"

            # Use custom port
            CollectionTester --port 8000 "Canterbury Museum"

            # Clean build first
            CollectionTester --clean "Auckland Museum Collections"

        DESCRIPTION:
            This tool:
            1. Builds the lambda
            2. Starts a local lambda server
            3. Makes a test request
            4. Validates the image URL
            5. Shuts down the server
        """)
    }
}
