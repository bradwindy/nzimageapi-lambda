//
//  OpacObjectFieldSet.swift
//  NZImageApiLambda
//
//  Created by Bradley Windybank on 30/11/2024.
//

import Foundation
import RichError

struct OpacObjectFieldSet: NonNullableResult {
    // MARK: Lifecycle

    init(identifier: String?, opacObjectFields: [OpacObjectField]?) {
        self.identifier = identifier
        self.opacObjectFields = opacObjectFields
    }

    // MARK: Internal

    typealias ErrorType = OpacObjectFieldSetError

    struct OpacObjectFieldSetError: RichError {
        typealias ErrorKind = OpacObjectFieldSetErrorKind
        enum OpacObjectFieldSetErrorKind: String {
            case nullFieldSetContent
        }

        var data: [String: String]
        let kind: ErrorKind
    }

    enum CodingKeys: String, CodingKey {
        case identifier
        case opacObjectFields
    }

    var identifier: String?
    var opacObjectFields: [OpacObjectField]?

    func customDescription() -> String {
        guard let opacObjectFields else {
            return "OpacObjectFieldSet with identifier \(String(describing: identifier)), no fields."
        }

        let resultsString = opacObjectFields.map { $0.customDescription() }.joined(separator: ", ")

        return "OpacObjectFieldSet with identifier \(String(describing: identifier)), results: \(resultsString)"
    }

    func checkNonNull() throws -> Self {
        if identifier != nil,
           opacObjectFields != nil
        {
            return self
        }
        else {
            throw OpacObjectFieldSetError(
                data: ["self_description": self.customDescription()],
                kind: .nullFieldSetContent
            )
        }
    }
}
