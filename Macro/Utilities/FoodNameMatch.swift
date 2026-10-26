//
//  FoodNameMatch.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/22/26.
//

import Foundation

enum FoodNameMatch {
    private static let ignoredWords: Set<String> = [
        "serving", "servings", "slice", "slices", "piece", "pieces", "the", "and", "with",
    ]

    static func words(_ name: String) -> Set<String> {
        let words = name.lowercased()
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { $0.count >= 3 && !ignoredWords.contains($0) }
        return Set(words)
    }

    static func similarity(_ lhs: Set<String>, _ rhs: Set<String>) -> Double {
        guard !lhs.isEmpty, !rhs.isEmpty else { return 0 }
        return Double(lhs.intersection(rhs).count) / Double(min(lhs.count, rhs.count))
    }

    static func similar(to name: String, in foods: [FoodItem]) -> [FoodItem] {
        let target = words(name)
        guard !target.isEmpty else { return [] }
        return foods
            .map { ($0, similarity(target, words($0.name))) }
            .filter { $0.1 >= 0.6 }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }
}
