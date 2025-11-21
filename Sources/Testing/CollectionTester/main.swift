//
//  main.swift
//  CollectionTester
//
//  Tests collections by building and running the lambda server locally
//

import Foundation
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

        // Build the lambda
        print("🔨 Building lambda...")
        guard await buildLambda() else {
            printError("Build failed")
            exit(1)
        }
        print("✅ Build complete\n")

        // Check if port is available and kill existing process
        if await isPortInUse(arguments.port) {
            print("⚠️  Port \(arguments.port) is already in use")
            print("Attempting to kill existing process...")
            await killProcessOnPort(arguments.port)
            try? await Task.sleep(for: .seconds(1))
        }

        // Start the lambda server
        print("🚀 Starting local lambda server on port \(arguments.port)...")
        guard let serverProcess = await startLambdaServer(port: arguments.port) else {
            printError("Failed to start lambda server")
            exit(1)
        }

        // Ensure cleanup on exit
        defer {
            print("\n🧹 Shutting down lambda server...")
            serverProcess.terminate()
        }

        // Wait for server to be ready
        print("⏳ Waiting for server to start...")
        guard await waitForServerReady(host: arguments.host, port: arguments.port) else {
            printError("Server failed to start after 30 seconds")
            exit(1)
        }
        print("✅ Server is ready!\n")

        // Make the request
        print("🔍 Making request...")
        if let collection = arguments.collection {
            print("📁 Collection: \(collection)")
        } else {
            print("🎲 Using random collection")
        }
        print("")

        let response = await makeRequest(
            host: arguments.host,
            port: arguments.port,
            collection: arguments.collection
        )

        guard let response = response else {
            printError("Failed to make request")
            exit(1)
        }

        // Check status code
        if response.statusCode != 200 {
            printError("Request failed with status code: \(response.statusCode)")
            print("\nResponse:")
            if let bodyString = String(data: response.body, encoding: .utf8) {
                print(bodyString)
            }
            exit(1)
        }

        print("✅ Success!\n")

        // Parse and display response
        guard let json = try? JSONSerialization.jsonObject(with: response.body) as? [String: Any] else {
            printError("Failed to parse JSON response")
            exit(1)
        }

        printJSON(json)

        // Verify image URL
        print("\n🔍 Verifying image URL...")

        guard let imageUrlString = json["large_thumbnail_url"] as? String,
              let imageUrl = URL(string: imageUrlString) else {
            print("⚠️  No large_thumbnail_url in response")
            return
        }

        print("📸 Image URL: \(imageUrlString)")

        let (httpStatus, contentType, fileType) = await validateImageURL(imageUrl)

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

    // MARK: - Build & Server Management

    static func buildLambda() async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = ["build"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    static func isPortInUse(_ port: Int) async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/lsof")
        process.arguments = ["-Pi", ":\(port)", "-sTCP:LISTEN", "-t"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return !data.isEmpty
        } catch {
            return false
        }
    }

    static func killProcessOnPort(_ port: Int) async {
        let lsofProcess = Process()
        lsofProcess.executableURL = URL(fileURLWithPath: "/usr/bin/lsof")
        lsofProcess.arguments = ["-ti", ":\(port)"]

        let pipe = Pipe()
        lsofProcess.standardOutput = pipe
        lsofProcess.standardError = Pipe()

        do {
            try lsofProcess.run()
            lsofProcess.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let pidString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !pidString.isEmpty else {
                return
            }

            let killProcess = Process()
            killProcess.executableURL = URL(fileURLWithPath: "/bin/kill")
            killProcess.arguments = ["-9", pidString]
            try? killProcess.run()
            killProcess.waitUntilExit()
        } catch {
            return
        }
    }

    static func startLambdaServer(port: Int) async -> Process? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ".build/debug/NZImageApiLambda")

        var environment = ProcessInfo.processInfo.environment
        environment["SECRET"] = "super_secret_secret"
        environment["LOCAL_LAMBDA_SERVER_ENABLED"] = "true"
        environment["PORT"] = "\(port)"
        process.environment = environment

        let outputFile = "/tmp/lambda-server.log"
        FileManager.default.createFile(atPath: outputFile, contents: nil)

        if let fileHandle = FileHandle(forWritingAtPath: outputFile) {
            process.standardOutput = fileHandle
            process.standardError = fileHandle
        }

        do {
            try process.run()
            return process
        } catch {
            return nil
        }
    }

    static func waitForServerReady(host: String, port: Int) async -> Bool {
        let maxRetries = 30

        for _ in 0..<maxRetries {
            if await checkServerHealth(host: host, port: port) {
                return true
            }
            try? await Task.sleep(for: .seconds(1))
        }

        return false
    }

    static func checkServerHealth(host: String, port: Int) async -> Bool {
        let url = URL(string: "http://\(host):\(port)/invoke")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = "{}".data(using: .utf8)
        request.timeoutInterval = 2

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode != nil
        } catch {
            return false
        }
    }

    // MARK: - HTTP Requests

    struct LambdaResponse {
        let statusCode: Int
        let body: Data
    }

    static func makeRequest(host: String, port: Int, collection: String?) async -> LambdaResponse? {
        let url = URL(string: "http://\(host):\(port)/invoke")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build request body
        var requestBody: [String: Any] = [
            "routeKey": "GET /image",
            "version": "2.0",
            "rawPath": "/image",
            "stageVariables": [:],
            "requestContext": [
                "timeEpoch": Int(Date().timeIntervalSince1970 * 1000),
                "domainPrefix": "image",
                "accountId": "0123456789",
                "stage": "$default",
                "domainName": "image.test.com",
                "apiId": "pb5dg6g3rg",
                "requestId": "test-\(Int(Date().timeIntervalSince1970))",
                "http": [
                    "path": "/image",
                    "userAgent": "CollectionTester",
                    "method": "GET",
                    "protocol": "HTTP/1.1",
                    "sourceIp": "127.0.0.1"
                ],
                "time": ISO8601DateFormatter().string(from: Date())
            ],
            "isBase64Encoded": false,
            "headers": [
                "secret": "super_secret_secret",
                "host": "\(host):\(port)",
                "user-agent": "CollectionTester",
                "content-length": "0"
            ]
        ]

        if let collection = collection {
            requestBody["queryStringParameters"] = ["collection": collection]
            requestBody["rawQueryString"] = "collection=\(collection.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? collection)"
        } else {
            requestBody["rawQueryString"] = ""
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            return nil
        }

        request.httpBody = jsonData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return nil
            }

            // Parse lambda response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let statusCode = json["statusCode"] as? Int {
                // If there's a body field, use it; otherwise use empty data
                let bodyData: Data
                if let bodyString = json["body"] as? String {
                    bodyData = bodyString.data(using: .utf8) ?? Data()
                } else {
                    bodyData = Data()
                }
                return LambdaResponse(statusCode: statusCode, body: bodyData)
            }

            return LambdaResponse(statusCode: httpResponse.statusCode, body: data)
        } catch {
            return nil
        }
    }

    static func validateImageURL(_ url: URL) async -> (httpStatus: Int, contentType: String, fileType: String) {
        // Get HTTP status and content type
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10

        var httpStatus = 0
        var contentType = "unknown"

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                httpStatus = httpResponse.statusCode
                contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "unknown"
            }
        } catch {
            httpStatus = 0
        }

        // Get file type by downloading first few bytes
        var fileType = "unknown"
        if httpStatus == 200 {
            var dataRequest = URLRequest(url: url)
            dataRequest.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            dataRequest.setValue("bytes=0-19", forHTTPHeaderField: "Range")

            do {
                let (data, _) = try await URLSession.shared.data(for: dataRequest)
                fileType = detectFileType(data)
            } catch {
                fileType = "error: \(error.localizedDescription)"
            }
        }

        return (httpStatus, contentType, fileType)
    }

    static func detectFileType(_ data: Data) -> String {
        guard data.count >= 2 else { return "unknown" }

        let bytes = [UInt8](data.prefix(20))

        // JPEG: FF D8
        if bytes.count >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8 {
            return "JPEG image"
        }

        // PNG: 89 50 4E 47
        if bytes.count >= 4 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 {
            return "PNG image"
        }

        // GIF: 47 49 46
        if bytes.count >= 3 && bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 {
            return "GIF image"
        }

        // WebP: 52 49 46 46 ... 57 45 42 50
        if bytes.count >= 12 && bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
           bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50 {
            return "WebP image"
        }

        return "unknown binary data"
    }

    // MARK: - Output Helpers

    static func printJSON(_ json: [String: Any]) {
        let keys = ["id", "title", "description", "thumbnail_url", "large_thumbnail_url", "object_url", "display_collection", "landing_url", "source_url"]

        for key in keys {
            if let value = json[key] {
                if let stringValue = value as? String {
                    print("  \"\(key)\": \"\(stringValue)\",")
                } else if let intValue = value as? Int {
                    print("  \"\(key)\": \(intValue),")
                } else {
                    print("  \"\(key)\": \(value),")
                }
            }
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
            -h, --help          Show this help message

        EXAMPLES:
            # Test random collection
            CollectionTester

            # Test specific collection
            CollectionTester "Te Papa Collections Online"

            # Use custom port
            CollectionTester --port 8000 "Canterbury Museum"

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
