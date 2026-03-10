//
//  LambdaTesting.swift
//  LambdaTesting
//
//  Shared library for Lambda server management and API testing
//

import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

// MARK: - Lambda Response

public struct LambdaImageResponse: Sendable {
    public let statusCode: Int
    public let id: Int?
    public let title: String?
    public let description: String?
    public let thumbnailUrl: String?
    public let largeThumbnailUrl: String?
    public let objectUrl: String?
    public let displayCollection: String?
    public let landingUrl: String?
    public let sourceUrl: String?
    public let rawBody: Data

    public init(statusCode: Int, body: Data) {
        self.statusCode = statusCode
        self.rawBody = body

        // Parse JSON body
        if let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
            self.id = json["id"] as? Int
            self.title = json["title"] as? String
            self.description = json["description"] as? String
            self.thumbnailUrl = json["thumbnail_url"] as? String
            self.largeThumbnailUrl = json["large_thumbnail_url"] as? String
            self.objectUrl = json["object_url"] as? String
            self.displayCollection = json["display_collection"] as? String
            self.landingUrl = json["landing_url"] as? String
            self.sourceUrl = json["source_url"] as? String
        } else {
            self.id = nil
            self.title = nil
            self.description = nil
            self.thumbnailUrl = nil
            self.largeThumbnailUrl = nil
            self.objectUrl = nil
            self.displayCollection = nil
            self.landingUrl = nil
            self.sourceUrl = nil
        }
    }
}

// MARK: - Lambda Server Manager

public actor LambdaServerManager {
    private var serverProcess: Process?
    private let port: Int
    private let host: String

    public init(port: Int = 7000, host: String = "127.0.0.1") {
        self.port = port
        self.host = host
    }

    deinit {
        serverProcess?.terminate()
    }

    // MARK: - Public API

    public func buildLambda(clean: Bool = false) async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")

        if clean {
            process.arguments = ["build", "--build-path", ".build"]
            // First do a clean
            let cleanProcess = Process()
            cleanProcess.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
            cleanProcess.arguments = ["package", "clean"]
            cleanProcess.standardOutput = Pipe()
            cleanProcess.standardError = Pipe()
            do {
                try cleanProcess.run()
                cleanProcess.waitUntilExit()
            } catch {
                // Ignore clean errors
            }
        }

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

    public func startServer() async -> Bool {
        // Check if port is in use
        if await isPortInUse() {
            await killProcessOnPort()
            try? await Task.sleep(for: .seconds(1))
        }

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
            self.serverProcess = process

            // Wait for server to be ready
            return await waitForServerReady()
        } catch {
            return false
        }
    }

    public func stopServer() {
        serverProcess?.terminate()
        serverProcess = nil
    }

    public func makeRequest(collection: String?) async -> LambdaImageResponse? {
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
                    "userAgent": "LambdaTesting",
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
                "user-agent": "LambdaTesting",
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
                let bodyData: Data
                if let bodyString = json["body"] as? String {
                    bodyData = bodyString.data(using: .utf8) ?? Data()
                } else {
                    bodyData = Data()
                }
                return LambdaImageResponse(statusCode: statusCode, body: bodyData)
            }

            return LambdaImageResponse(statusCode: httpResponse.statusCode, body: data)
        } catch {
            return nil
        }
    }

    public func validateImageURL(_ urlString: String) async -> (httpStatus: Int, contentType: String, fileType: String) {
        guard let url = URL(string: urlString) else {
            return (0, "invalid URL", "unknown")
        }

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
                fileType = "error"
            }
        }

        return (httpStatus, contentType, fileType)
    }

    // MARK: - Private Helpers

    private func isPortInUse() async -> Bool {
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

    private func killProcessOnPort() async {
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

    private func waitForServerReady() async -> Bool {
        let maxRetries = 30

        for _ in 0..<maxRetries {
            if await checkServerHealth() {
                return true
            }
            try? await Task.sleep(for: .seconds(1))
        }

        return false
    }

    private func checkServerHealth() async -> Bool {
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

    private func detectFileType(_ data: Data) -> String {
        guard data.count >= 2 else { return "unknown" }

        let bytes = [UInt8](data.prefix(20))

        if bytes.count >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8 {
            return "JPEG image"
        }

        if bytes.count >= 4 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 {
            return "PNG image"
        }

        if bytes.count >= 3 && bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 {
            return "GIF image"
        }

        if bytes.count >= 12 && bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
           bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50 {
            return "WebP image"
        }

        return "unknown binary data"
    }
}
