//
//  main.swift
//  CollectionFetcher
//
//  A command-line tool to fetch images from the local NZImageApi Lambda
//

import Foundation

@main
struct CollectionFetcher {
    static func main() async throws {
        let arguments = CommandLine.arguments

        // Parse arguments
        var host = "localhost"
        var port = 8001
        var collection: String?
        var showHelp = false

        var i = 1
        while i < arguments.count {
            let arg = arguments[i]

            switch arg {
            case "-h", "--help":
                showHelp = true

            case "--host":
                if i + 1 < arguments.count {
                    host = arguments[i + 1]
                    i += 1
                } else {
                    printError("--host requires a value")
                    exit(1)
                }

            case "--port":
                if i + 1 < arguments.count {
                    if let p = Int(arguments[i + 1]) {
                        port = p
                        i += 1
                    } else {
                        printError("--port requires a numeric value")
                        exit(1)
                    }
                } else {
                    printError("--port requires a value")
                    exit(1)
                }

            default:
                if arg.hasPrefix("-") {
                    printError("Unknown option: \(arg)")
                    exit(1)
                } else {
                    collection = arg
                }
            }

            i += 1
        }

        if showHelp {
            printHelp()
            return
        }

        // Build URL
        var urlComponents = URLComponents()
        urlComponents.scheme = "http"
        urlComponents.host = host
        urlComponents.port = port
        urlComponents.path = "/image"

        if let collection = collection {
            urlComponents.queryItems = [URLQueryItem(name: "collection", value: collection)]
        }

        guard let url = urlComponents.url else {
            printError("Failed to construct URL")
            exit(1)
        }

        // Make request
        print("🔍 Fetching from: \(url.absoluteString)")
        if let collection = collection {
            print("📁 Collection: \(collection)")
        } else {
            print("🎲 Using random collection")
        }
        print("")

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                printError("Invalid response type")
                exit(1)
            }

            print("📊 Status: \(httpResponse.statusCode) \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))")
            print("")

            if httpResponse.statusCode == 200 {
                // Parse and pretty-print JSON
                if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    printSuccess("✅ Success!")
                    print("")
                    printJSON(json)
                } else {
                    printError("Failed to parse JSON response")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("Raw response:")
                        print(responseString)
                    }
                    exit(1)
                }
            } else {
                printError("Request failed with status \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response:")
                    print(responseString)
                }
                exit(1)
            }

        } catch {
            printError("Request failed: \(error.localizedDescription)")
            exit(1)
        }
    }

    static func printHelp() {
        print("""
        CollectionFetcher - Fetch images from local NZImageApi Lambda

        USAGE:
            CollectionFetcher [COLLECTION] [OPTIONS]

        ARGUMENTS:
            COLLECTION          The collection name to query (optional, random if not specified)

        OPTIONS:
            --host <host>       Lambda host (default: localhost)
            --port <port>       Lambda port (default: 8001)
            -h, --help          Show this help message

        EXAMPLES:
            # Get a random image
            CollectionFetcher

            # Get an image from a specific collection
            CollectionFetcher "Te Papa Collections Online"

            # Use a different port
            CollectionFetcher --port 9000

            # Specify collection and custom host
            CollectionFetcher "Canterbury Museum" --host 127.0.0.1 --port 8080

        AVAILABLE COLLECTIONS:
            - Auckland Libraries Heritage Images Collection
            - Auckland Museum Collections
            - Te Papa Collections Online
            - Kura Heritage Collections Online
            - Canterbury Museum
            - Antarctica NZ Digital Asset Manager
            - National Publicity Studios black and white file prints
            - Tauranga City Libraries Other Collection
            - Hawke's Bay Knowledge Bank
            - South Canterbury Museum
            - Manawatū Heritage
            - Howick Historical Village NZMuseums
            - Presbyterian Research Centre
            - National Army Museum
            - TAPUHI
            - Auckland Art Gallery Toi o Tāmaki
            - Waimate Museum and Archives PastPerfect
            - Te Toi Uku, Crown Lynn and Clayworks Museum
            - Culture Waitaki
            - Wellington City Recollect
            - Te Hikoi Museum
            - V.C. Browne & Son NZ Aerial Photograph Collection
            - Tāmiro
            - Alexander Turnbull Library Flickr
            - He Purapura Marara Scattered Seeds
        """)
    }

    static func printJSON(_ json: [String: Any]) {
        let keys = ["id", "title", "description", "thumbnail_url", "large_thumbnail_url", "object_url", "display_collection", "landing_url"]

        for key in keys {
            if let value = json[key] {
                let displayKey = key.padding(toLength: 20, withPad: " ", startingAt: 0)

                if let stringValue = value as? String {
                    print("  \(displayKey): \(stringValue)")
                } else if let intValue = value as? Int {
                    print("  \(displayKey): \(intValue)")
                } else {
                    print("  \(displayKey): \(value)")
                }
            }
        }
    }

    static func printSuccess(_ message: String) {
        print("\u{001B}[32m\(message)\u{001B}[0m")
    }

    static func printError(_ message: String) {
        print("\u{001B}[31m❌ Error: \(message)\u{001B}[0m")
    }
}
