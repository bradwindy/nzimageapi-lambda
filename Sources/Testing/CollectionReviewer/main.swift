//
//  main.swift
//  CollectionReviewer
//
//  Interactive review tool for all collections
//

import Alamofire
import Foundation
import Synchronization

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

// MARK: - Progress Tracking

struct ProgressState: Sendable {
    var currentIndex: Int = 0
    var filePath: String = ""
    var total: Int = 0
}

let progressState = Mutex(ProgressState())

func saveProgress() {
    let state = progressState.withLock { $0 }
    guard !state.filePath.isEmpty else { return }
    do {
        let progressData = "\(state.currentIndex)"
        try progressData.write(toFile: state.filePath, atomically: true, encoding: .utf8)
    } catch {
        // Silent fail - not critical
    }
}

func loadProgress() -> Int? {
    let filePath = progressState.withLock { $0.filePath }
    guard !filePath.isEmpty else { return nil }
    guard FileManager.default.fileExists(atPath: filePath) else { return nil }

    do {
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        return Int(content.trimmingCharacters(in: .whitespacesAndNewlines))
    } catch {
        return nil
    }
}

func clearProgress() {
    let filePath = progressState.withLock { $0.filePath }
    guard !filePath.isEmpty else { return }
    try? FileManager.default.removeItem(atPath: filePath)
}

func setupSignalHandler() {
    signal(SIGINT) { _ in
        print("\n\nInterrupted! Saving progress...")
        saveProgress()
        let state = progressState.withLock { $0 }
        print("Progress saved at collection \(state.currentIndex + 1)/\(state.total).")
        print("Run the script again to resume.\n")
        exit(0)
    }
}

// MARK: - Models

struct NZRecordsResult: Codable, Sendable {
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case thumbnailUrl = "thumbnail_url"
        case largeThumbnailUrl = "large_thumbnail_url"
        case objectUrl = "object_url"
        case collection = "display_collection"
        case landingUrl = "landing_url"
        case originUrl = "origin_url"
        case sourceUrl = "source_url"
    }

    var id: Int?
    var title: String?
    var description: String?
    var thumbnailUrl: URL?
    var largeThumbnailUrl: URL?
    var objectUrl: URL?
    var collection: String?
    var landingUrl: URL?
    var originUrl: URL?
    var sourceUrl: URL?
}

struct NZRecordsSearch: Codable, Sendable {
    enum CodingKeys: String, CodingKey {
        case resultCount = "result_count"
        case results
    }

    var resultCount: Int?
    var results: [NZRecordsResult]?
}

struct NZRecordsResponse: Codable, Sendable {
    var search: NZRecordsSearch?
}

// MARK: - Selection Status

enum SelectionStatus: String {
    case yes = "y"
    case no = "n"
    case skip = "s"
    case more = "m"

    var emoji: String {
        switch self {
        case .yes: return "✅"
        case .no: return "❌"
        case .skip, .more: return ""
        }
    }

    var description: String {
        switch self {
        case .yes: return "Yes"
        case .no: return "No"
        case .skip: return "Skip"
        case .more: return "More"
        }
    }
}

// MARK: - Collection Entry

struct CollectionEntry {
    let name: String
    let count: String
    let lineNumber: Int
    var fields: [(key: String, value: String, lineNumber: Int)]
    var statusLineNumber: Int
    var currentStatus: String
    var endLineNumber: Int
}

// MARK: - Digital NZ API

func fetchRandomImages(collection: String, apiKey: String, count: Int = 3) async throws -> [NZRecordsResult] {
    let endpoint = "https://api.digitalnz.org/records.json"

    // First request to get total count
    let initialParameters: [String: String] = [
        "page": "1",
        "per_page": "0",
        "and[category][]": "Images",
        "and[primary_collection][]": collection,
    ]

    let headers = HTTPHeaders(["Authentication-Token": apiKey])

    let initialResponse = try await AF.request(
        endpoint,
        parameters: initialParameters,
        headers: headers
    )
    .serializingDecodable(NZRecordsResponse.self)
    .value

    guard let resultCount = initialResponse.search?.resultCount, resultCount > 0 else {
        return []
    }

    var results: [NZRecordsResult] = []

    // Fetch random images
    for _ in 0..<count {
        let resultsPerPage = 100
        let pageCount = max(1, resultCount / resultsPerPage)
        let randomPage = Int.random(in: 1...pageCount)

        let parameters: [String: String] = [
            "page": String(randomPage),
            "per_page": String(resultsPerPage),
            "and[category][]": "Images",
            "and[primary_collection][]": collection,
        ]

        let response = try await AF.request(
            endpoint,
            parameters: parameters,
            headers: headers
        )
        .serializingDecodable(NZRecordsResponse.self)
        .value

        if let pageResults = response.search?.results, !pageResults.isEmpty {
            let randomIndex = Int.random(in: 0..<pageResults.count)
            results.append(pageResults[randomIndex])
        }
    }

    return results
}

// MARK: - File Parsing

func parseCollectionsFile(at path: String) throws -> (lines: [String], collections: [CollectionEntry]) {
    let content = try String(contentsOfFile: path, encoding: .utf8)
    let lines = content.components(separatedBy: .newlines)

    var collections: [CollectionEntry] = []
    var currentCollection: CollectionEntry?

    for (index, line) in lines.enumerated() {
        // Check if this is a collection line (starts with ")
        if line.hasPrefix("\"") && line.contains("\": ") {
            // Save previous collection if exists
            if var collection = currentCollection {
                collection.endLineNumber = index - 1
                collections.append(collection)
            }

            // Extract collection name and count
            if let endQuote = line.dropFirst().firstIndex(of: "\"") {
                let name = String(line[line.index(after: line.startIndex)..<endQuote])
                let afterQuote = line[line.index(endQuote, offsetBy: 3)...]
                let count = String(afterQuote).trimmingCharacters(in: .whitespaces)

                currentCollection = CollectionEntry(
                    name: name,
                    count: count,
                    lineNumber: index,
                    fields: [],
                    statusLineNumber: -1,
                    currentStatus: "",
                    endLineNumber: -1
                )
            }
        } else if var collection = currentCollection {
            // Parse field lines
            if line.hasPrefix("- ") {
                let fieldContent = String(line.dropFirst(2))
                if let colonIndex = fieldContent.firstIndex(of: ":") {
                    let key = String(fieldContent[..<colonIndex])
                    let value = String(fieldContent[fieldContent.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

                    collection.fields.append((key: key, value: value, lineNumber: index))

                    // Track status line
                    if key == "Status" {
                        collection.statusLineNumber = index
                        collection.currentStatus = value
                    }

                    currentCollection = collection
                }
            } else if line.trimmingCharacters(in: .whitespaces).isEmpty && !collection.fields.isEmpty {
                // End of this collection's fields (blank line after fields)
                collection.endLineNumber = index - 1
                collections.append(collection)
                currentCollection = nil
            }
        }
    }

    // Don't forget the last collection
    if var collection = currentCollection {
        collection.endLineNumber = lines.count - 1
        collections.append(collection)
    }

    return (lines, collections)
}

// MARK: - File Update

func updateCollectionInFile(at path: String, collection: CollectionEntry, status: SelectionStatus, notes: String?) throws {
    var content = try String(contentsOfFile: path, encoding: .utf8)
    var lines = content.components(separatedBy: .newlines)

    // Update status emoji if we have a status line
    if collection.statusLineNumber != -1 {
        let statusLine = lines[collection.statusLineNumber]
        // Replace the status value after "- Status: "
        if statusLine.contains("- Status: ") {
            let newStatusLine = "- Status: \(status.emoji)"
            lines[collection.statusLineNumber] = newStatusLine
        }
    } else {
        // No status line exists, insert one after the collection name
        let newStatusLine = "- Status: \(status.emoji)"
        lines.insert(newStatusLine, at: collection.lineNumber + 1)
    }

    // Re-read to get updated line numbers after potential insertion
    content = lines.joined(separator: "\n")
    lines = content.components(separatedBy: .newlines)

    // Find the end of this collection's fields (before the blank line)
    var insertIndex = collection.lineNumber + 1
    while insertIndex < lines.count && lines[insertIndex].hasPrefix("- ") {
        insertIndex += 1
    }

    // Add timestamped notes if provided
    if let notes = notes, !notes.isEmpty {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let timestamp = formatter.string(from: Date())
        let noteLine = "- Review [\(timestamp)]: \(notes)"
        lines.insert(noteLine, at: insertIndex)
    }

    // Write back to file
    content = lines.joined(separator: "\n")
    try content.write(toFile: path, atomically: true, encoding: .utf8)
}

// MARK: - Interactive CLI

func printClickableLink(_ url: URL, label: String) {
    // OSC 8 hyperlink escape sequence for terminals that support it
    let hyperlink = "\u{1B}]8;;\(url.absoluteString)\u{07}\(label)\u{1B}]8;;\u{07}"
    print(hyperlink)
}

func getSelectionInput(prompt: String) -> SelectionStatus {
    print(prompt, terminator: " ")
    fflush(stdout)

    while true {
        if let input = readLine()?.lowercased().trimmingCharacters(in: .whitespaces) {
            switch input {
            case "y", "yes":
                return .yes
            case "n", "no":
                return .no
            case "s", "skip":
                return .skip
            case "m", "more":
                return .more
            default:
                break
            }
        }
        print("Please enter y/n/m/s: ", terminator: "")
        fflush(stdout)
    }
}

func getTextInput(prompt: String) -> String {
    print(prompt, terminator: " ")
    fflush(stdout)
    return readLine() ?? ""
}

// MARK: - Display Helpers

func printCollectionInfo(_ collection: CollectionEntry) {
    print("\nCollection info:")
    print("  Items: \(collection.count)")

    if !collection.fields.isEmpty {
        print("\n  Current fields:")
        for field in collection.fields {
            // Highlight status and review fields
            if field.key == "Status" {
                print("  \u{001B}[1m- \(field.key): \(field.value)\u{001B}[0m")
            } else if field.key.hasPrefix("Review") {
                print("  \u{001B}[33m- \(field.key): \(field.value)\u{001B}[0m")
            } else {
                print("  - \(field.key): \(field.value)")
            }
        }
    }
    print("")
}

// MARK: - Main

@main
struct CollectionReviewerApp {
    static func main() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["DIGITALNZ_API_KEY"] else {
            fputs("Error: DIGITALNZ_API_KEY environment variable not set\n", stderr)
            exit(1)
        }

        // Get path to details file
        let fileManager = FileManager.default
        let currentDir = fileManager.currentDirectoryPath
        let detailsPath = "\(currentDir)/Research/details-of-collections.txt"
        progressState.withLock { $0.filePath = "\(currentDir)/Research/.collection-reviewer-progress" }

        guard fileManager.fileExists(atPath: detailsPath) else {
            fputs("Error: Could not find \(detailsPath)\n", stderr)
            exit(1)
        }

        // Set up signal handler for Ctrl-C
        setupSignalHandler()

        // Parse collections
        let (_, collections) = try parseCollectionsFile(at: detailsPath)

        if collections.isEmpty {
            print("No collections found.")
            return
        }

        progressState.withLock { $0.total = collections.count }

        // Check for saved progress
        var startIndex = 0
        if let savedIndex = loadProgress(), savedIndex < collections.count {
            print("Found saved progress at collection \(savedIndex + 1)/\(collections.count).")
            let resumeChoice = getSelectionInput(prompt: "Resume from where you left off? (y = resume, n = start over, s = skip to end):")

            switch resumeChoice {
            case .yes, .more:
                startIndex = savedIndex
                print("Resuming from collection \(startIndex + 1)...\n")
            case .no:
                clearProgress()
                print("Starting from the beginning...\n")
            case .skip:
                print("Exiting.\n")
                return
            }
        }

        print("Found \(collections.count) collections.\n")
        print("Selection options: y = Yes (✅), n = No (❌), m = More images, s = Skip\n")
        print("Press Ctrl-C to save progress and exit.\n")

        for index in startIndex..<collections.count {
            let collection = collections[index]
            progressState.withLock { $0.currentIndex = index }
            print("═══════════════════════════════════════════════════════════════")
            print("[\(index + 1)/\(collections.count)] Reviewing: \"\(collection.name)\"")
            print("═══════════════════════════════════════════════════════════════")

            // Show existing collection info and notes
            printCollectionInfo(collection)

            // Image viewing and selection loop
            var selection: SelectionStatus = .more
            while selection == .more {
                // Fetch random images
                print("Fetching 3 random images...")
                let images = try await fetchRandomImages(collection: collection.name, apiKey: apiKey, count: 3)

                if images.isEmpty {
                    print("No images found for this collection.\n")
                } else {
                    print("\nSample images from this collection:\n")

                    for (i, image) in images.enumerated() {
                        let imageNum = i + 1
                        print("Image \(imageNum):")
                        if let title = image.title {
                            print("  Title: \(title)")
                        }

                        // Show landing URL
                        if let landingUrl = image.landingUrl {
                            print("  Landing: ", terminator: "")
                            printClickableLink(landingUrl, label: landingUrl.absoluteString)
                        }

                        // Show large thumbnail URL
                        if let largeThumbnail = image.largeThumbnailUrl {
                            print("  Large Thumb: ", terminator: "")
                            printClickableLink(largeThumbnail, label: largeThumbnail.absoluteString)
                        }

                        // Show object URL if available
                        if let objectUrl = image.objectUrl {
                            print("  Object URL: ", terminator: "")
                            printClickableLink(objectUrl, label: objectUrl.absoluteString)
                        }
                        print("")
                    }
                }

                // Get user decision
                selection = getSelectionInput(prompt: "Selection (y/n/m/s):")

                if selection == .more {
                    print("\nFetching more images...\n")
                }
            }

            if selection == .skip {
                print("Skipped.\n")
                continue
            }

            // Get notes for any selection
            let userNotes = getTextInput(prompt: "Notes (optional):")

            // Update file
            try updateCollectionInFile(at: detailsPath, collection: collection, status: selection, notes: userNotes.isEmpty ? nil : userNotes)

            print("Status updated to \(selection.emoji) (\(selection.description))\n")
        }

        // Clear progress file on completion
        clearProgress()

        print("═══════════════════════════════════════════════════════════════")
        print("Review complete! All \(collections.count) collections processed.")
        print("═══════════════════════════════════════════════════════════════")
    }
}
