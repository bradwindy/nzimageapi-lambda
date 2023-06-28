//
//  NZRecordsResponse.swift
//  NZImage
//
//  Created by Bradley Windybank on 22/03/23.
//

import RichError

struct NZRecordsResponse: NonNullableResult {
    // MARK: Lifecycle

    init(search: NZRecordsSearch?) {
        self.search = search
    }

    // MARK: Internal

    typealias ErrorType = NZRecordsResponseError

    struct NZRecordsResponseError: RichError {
        typealias ErrorKind = NZRecordsResponseErrorKind
        
        enum NZRecordsResponseErrorKind: String {
            case nullResponseContent
        }

        var data: [String : String]
        let kind: NZRecordsResponseErrorKind
    }

    enum CodingKeys: String, CodingKey {
        case search
    }

    var search: NZRecordsSearch?

    func customDescription() -> String {
        return "NZRecordsResponse with search \(String(describing: search?.customDescription()))"
    }

    func checkNonNull() throws -> NZRecordsResponse {
        if search != nil {
            return self
        }
        else {
            throw NZRecordsResponseError(data: ["self_description": self.customDescription()], kind: .nullResponseContent)
        }
    }
}
