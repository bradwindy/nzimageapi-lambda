//
//  AKLMuseumResponse.swift
//  NZImageApiLambda
//
//  Created by Bradley Windybank on 30/11/2024.
//

import Foundation
import RichError

struct AKLMuseumResponse: NonNullableResult, Sendable {
    // MARK: Lifecycle

    init(opacObjectFieldSets: [OpacObjectFieldSet]?) {
        self.opacObjectFieldSets = opacObjectFieldSets
    }

    // MARK: Internal

    typealias ErrorType = AKLMuseumResponseError

    struct AKLMuseumResponseError: RichError {
        typealias ErrorKind = AKLMuseumResponseErrorKind
        enum AKLMuseumResponseErrorKind: String {
            case nullResponseContent
        }

        var data: [String: String]
        let kind: ErrorKind
    }

    enum CodingKeys: String, CodingKey {
        case opacObjectFieldSets
    }

    var opacObjectFieldSets: [OpacObjectFieldSet]?

    func customDescription() -> String {
        guard let opacObjectFieldSets else {
            return "AKLMuseumResponse, no opacObjectFieldSets."
        }

        let resultsString = opacObjectFieldSets.map { $0.customDescription() }.joined(separator: ", ")

        return "AKLMuseumResponse, results: \(resultsString)"
    }

    func checkNonNull() throws -> Self {
        if opacObjectFieldSets != nil {
            return self
        }
        else {
            throw AKLMuseumResponseError(
                data: ["self_description": self.customDescription()],
                kind: .nullResponseContent
            )
        }
    }
}
