//
//  OrderedDictionary+WeightedPick.swift
//  NZImage
//
//  Created by Bradley Windybank on 10/04/23.
//

import Foundation
import OrderedCollections

public extension OrderedDictionary<String, Double> {
    /**
     Weighted pick from `OrderedDictionary<String, Double>` where `Double` is a weight between 0 and 1. The weight determines how likely the item in the dictionary is to picked. All weights in the dictionary should sum to 1.
     
     Example dictionary:
     ```
     let weightedItems: OrderedDictionary = ["Item 1": 0.5,
                                             "Item 2": 0.2,
                                             "Item 3": 0.2,
                                             "Item 4": 0.1]
     ```
     */
    func weightedRandomPick() -> String {
        let randomFloatThreshold = Double.random(in: 0 ..< 1)
        var totalCombinedWeights: Double = 0

        for position in 0 ..< self.count {
            totalCombinedWeights += self.elements[position].value

            if totalCombinedWeights > randomFloatThreshold {
                return self.elements[position].key
            }
        }

        return self.elements[self.count - 1].key
    }
}
