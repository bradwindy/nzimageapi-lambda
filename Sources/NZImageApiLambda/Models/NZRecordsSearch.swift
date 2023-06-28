//
//  NZRecordsSearch.swift
//  NZImage
//
//  Created by Bradley Windybank on 22/03/23.
//

import Foundation
import RichError

struct NZRecordsSearch: NonNullableResult {
    // MARK: Lifecycle

    init(resultCount: Int?, results: [NZRecordsResult]?) {
        self.resultCount = resultCount
        self.results = results
    }

    // MARK: Internal

    typealias ErrorType = NZRecordsSearchError

    struct NZRecordsSearchError: RichError {
        typealias ErrorKind = NZRecordsSearchErrorKind
        enum NZRecordsSearchErrorKind: String {
            case nullSearchContent
        }

        var data: [String: String]
        let kind: NZRecordsSearchErrorKind
    }

    enum CodingKeys: String, CodingKey {
        case resultCount = "result_count"
        case results
    }

    var resultCount: Int?
    var results: [NZRecordsResult]?

    func customDescription() -> String {
        guard let results = results else { return "NZRecordsSearch with result count \(String(describing: resultCount)), no results." }
        let resultsString = results.map { $0.customDescription() }.joined(separator: ", ")

        return "NZRecordsSearch with result count \(String(describing: resultCount)), results: \(resultsString)"
    }

    func checkNonNull() throws -> NZRecordsSearch {
        if resultCount != nil, results != nil {
            return self
        }
        else {
            throw NZRecordsSearchError(data: ["self_description": self.customDescription()], kind: .nullSearchContent)
        }
    }
}
