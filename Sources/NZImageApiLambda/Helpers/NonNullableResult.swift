//
//  NonNullableResult.swift
//  NZImage
//
//  Created by Bradley Windybank on 10/04/23.
//

/// A result that can be checked to see if its properties are not null, and throws an error if they are. Useful for standardising the way network API responses are handled.
protocol NonNullableResult: Decodable {
    /// Result must provide error type
    associatedtype ErrorType: NonNullableError

    /// Should be used to check to see if properties are not null.
    func checkNonNull() throws -> Self
    func customDescription() -> String
}

/// An error thown by `NonNullableResult` when one of its properties are null.
protocol NonNullableError: Error {
    associatedtype ErrorKind

    var result: any NonNullableResult { get }
    var kind: ErrorKind { get }
}
