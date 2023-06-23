//
//  Collection+Safe.swift
//  NZImage
//
//  Created by Bradley Windybank on 23/03/23.
//

import Foundation

/// Error thrown by `Collection.throwingAccess(_ index: Index)` if the index is out of bounds.
struct CollectionIndexOutOfBoundsError: Error {
    let index: Int
    let count: Int
    let collection: any Collection
}

extension Collection {
    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
    
    /// Returns the element at the specified index if it is within bounds, otherwise throws an error.
    func throwingAccess(_ index: Index) throws -> Element {
        if indices.contains(index) {
            return self[index]
        }
        else {
            throw CollectionIndexOutOfBoundsError(index: self.distance(from: self.startIndex, to: index), count: self.count, collection: self)
        }
    }
}
