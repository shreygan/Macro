//
//  BuiltInCatalog.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/25/26.
//

import Foundation
import SwiftData

enum BuiltInCatalog {
    private static var previews: [String: FoodItem] = [:]

    static func preview(for key: String) -> FoodItem? {
        if let drink = previews[key], drink.modelContext == nil, !drink.isDeleted { return drink }
        guard let seed = AppSeeder.defaultDrinks.first(where: { $0.key == key }),
            let drink = AppSeeder.previewDrink(for: seed)
        else { return nil }
        drink.seedKey = key
        drink.isInLibrary = false
        previews[key] = drink
        return drink
    }

    static func isStored(_ food: FoodItem) -> Bool {
        food.modelContext != nil
    }

    static func items(stored foods: [FoodItem], type: EntryType? = nil) -> [FoodItem] {
        let storedByKey = Dictionary(
            foods.compactMap { food in food.seedKey.map { ($0, food) } },
            uniquingKeysWith: { first, _ in first }
        )
        return AppSeeder.defaultDrinks.compactMap { seed -> FoodItem? in
            if let stored = storedByKey[seed.key] {
                return stored.isInLibrary ? nil : stored
            }
            return preview(for: seed.key)
        }
        .filter { type == nil || $0.type == type }
    }

    static func matches(
        _ searchText: String,
        stored foods: [FoodItem],
        type: EntryType? = nil
    ) -> [FoodItem] {
        guard !searchText.isEmpty else { return [] }
        let candidates = items(stored: foods, type: type)
        let ranked = FoodSearch(searchText).ranked(candidates, stats: [:])
        let aliases = DrinkAliasSearch(searchText)
        let aliased = candidates.filter { aliases.includes($0) && !ranked.contains($0) }
        return ranked + aliased
    }

    @MainActor
    static func stored(_ food: FoodItem, in context: ModelContext) throws -> FoodItem {
        guard !isStored(food),
            let key = food.seedKey,
            let seed = AppSeeder.defaultDrinks.first(where: { $0.key == key }),
            let drink = try AppSeeder.storedDrink(for: seed, in: context)
        else { return food }
        return drink
    }

    static func isUnchanged(_ food: FoodItem) -> Bool {
        guard let key = food.seedKey, let base = preview(for: key) else { return false }
        let sizes: (FoodItem) -> [[String]] = { item in
            item.sortedDrinkSizes.map { [$0.name ?? "", "\($0.volumeML)", "\($0.isDefault)"] }
        }
        return food.name == base.name && food.type == base.type
            && food.servingWeight == base.servingWeight
            && food.calories == base.calories && food.protein == base.protein && food.carbs == base.carbs
            && food.fat == base.fat && food.fiber == base.fiber && food.hasNutrition == base.hasNutrition
            && food.isAIEstimated == base.isAIEstimated
            && food.caffeineMg == base.caffeineMg && food.abv == base.abv
            && food.hydrationPercent == base.hydrationPercent
            && food.symbol == base.symbol && food.tintRawValue == base.tintRawValue
            && sizes(food) == sizes(base)
            && food.source == nil && food.category == nil && food.foodGroup == nil
            && food.defaultLocation == nil && food.stickyNote == nil
            && !food.isCustomDefaultServing
    }

    @MainActor
    static func discardIfUnused(_ food: FoodItem, in context: ModelContext) {
        guard !food.isDeleted, food.modelContext != nil,
            food.seedKey != nil,
            !food.isInLibrary,
            food.hydrationOrder == nil,
            food.favoriteEntry == nil,
            (food.loggedEntries ?? []).isEmpty,
            (food.drafts ?? []).isEmpty,
            (food.usedInRecipes ?? []).isEmpty,
            isUnchanged(food)
        else { return }
        context.delete(food)
        do {
            try context.save()
        } catch {
            context.rollback()
        }
    }
}
