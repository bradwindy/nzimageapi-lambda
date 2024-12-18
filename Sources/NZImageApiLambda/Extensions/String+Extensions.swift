//
//  File.swift
//
//
//  Created by Bradley Windybank on 23/08/23.
//

import Foundation

extension String {
    func slice(from: String, to: String) -> String? {
        return (range(of: from)?.upperBound).flatMap { substringFrom in
            (range(of: to, range: substringFrom ..< endIndex)?.lowerBound).map { substringTo in
                String(self[substringFrom ..< substringTo])
            }
        }
    }

    func numberOfOccurrences(of substring: String) -> Int {
        return self.components(separatedBy: substring).count - 1
    }
}
