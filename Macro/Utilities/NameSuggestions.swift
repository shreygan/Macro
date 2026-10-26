//
//  NameSuggestions.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/22/26.
//

import Foundation

enum NameSuggestions {
    static let limit = 3
    private static let minimumLength = 3

    struct Match {
        let food: FoodItem
        var alias: String?
        var fillsName = false

        var aliasNote: String? {
            alias.map { String(localized: "Matches “\($0)”") }
        }
    }

    static func hasEnoughText(_ name: String) -> Bool {
        words(in: name).joined().count >= minimumLength
    }

    static func suggestions(
        for name: String,
        type: EntryType,
        in foods: [FoodItem],
        excluding excludedID: UUID? = nil
    ) -> [Match] {
        let typed = words(in: name)
        guard typed.joined().count >= minimumLength else { return [] }

        let candidates = foods.filter { $0.type == type && $0.id != excludedID }
        var result: [Match] = []

        if type == .drink, let alias = DrinkAliases.match(words: typed),
            let seed = candidates.first(where: { $0.seedKey == alias.key }) ?? BuiltInCatalog.preview(for: alias.key),
            seed.id != excludedID
        {
            result.append(Match(food: seed, alias: alias.alias))
        }

        let search = FoodSearch(name)
        let matches = candidates
            .filter { completes(typed, name: $0.name) }
            .compactMap { food in search.relevance(name: food.name, fields: []).map { (food, $0) } }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
                return lhs.0.name.localizedStandardCompare(rhs.0.name) == .orderedAscending
            }
            .map(\.0)

        for food in matches where !result.contains(where: { $0.food.id == food.id }) {
            result.append(Match(food: food, fillsName: true))
        }
        return Array(result.prefix(limit))
    }

    private static func completes(_ typed: [String], name: String) -> Bool {
        let nameWords = words(in: name)
        return typed.allSatisfy { word in nameWords.contains { $0.hasPrefix(word) } }
    }

    private static func words(in text: String) -> [String] {
        DrinkAliases.words(in: text)
    }
}
