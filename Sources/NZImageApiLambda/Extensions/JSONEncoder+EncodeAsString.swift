//
//  JSONEncoder+EncodeAsString.swift
//  
//
//  Created by Bradley Windybank on 24/06/23.
//

import Foundation

extension JSONEncoder {
    func encodeAsString<T: Encodable>(_ value: T) throws -> String {
        try String(decoding: self.encode(value), as: Unicode.UTF8.self)
    }
}
