//
//  OpacObjectField.swift
//  NZImageApiLambda
//
//  Created by Bradley Windybank on 30/11/2024.
//

import Foundation
import RichError

struct OpacObjectField: NonNullableResult, Sendable {
    // MARK: Lifecycle

    init(value: String?) {
        self.value = value
    }

    // MARK: Internal

    typealias ErrorType = OpacObjectFieldError

    struct OpacObjectFieldError: RichError {
        typealias ErrorKind = OpacObjectFieldErrorKind
        enum OpacObjectFieldErrorKind: String {
            case nullFieldContent
        }

        var data: [String: String]
        let kind: ErrorKind
    }

    enum CodingKeys: String, CodingKey {
        case value
    }

    var value: String?

    func customDescription() -> String {
        guard let value else {
            return "OpacObjectField with nil value"
        }

        return "OpacObjectField with value: \(value)"
    }

    func checkNonNull() throws -> Self {
        if value != nil {
            return self
        }
        else {
            throw OpacObjectFieldError(
                data: ["self_description": self.customDescription()],
                kind: .nullFieldContent
            )
        }
    }
}
