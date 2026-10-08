//
//  FoodItemStore.swift
//  Macro
//
//  Created by Shrey Gangwar on 9/30/26.
//

import Foundation
import SwiftData

struct FoodItemUsage {
    var logCount: Int
    var recipeCount: Int
}

struct FoodLogStats {
    var count: Int
    var lastLogged: Date

    static func byFood(_ entries: [LoggedEntry]) -> [UUID: FoodLogStats] {
        var result: [UUID: FoodLogStats] = [:]
        for entry in entries {
            guard let id = entry.originalFoodItem?.id else { continue }
            if var stats = result[id] {
                stats.count += 1
                stats.lastLogged = max(stats.lastLogged, entry.timestamp)
                result[id] = stats
            } else {
                result[id] = FoodLogStats(count: 1, lastLogged: entry.timestamp)
            }
        }
        return result
    }
}

@MainActor
enum FoodItemStore {
    static func loggedEntries(
        for food: FoodItem,
        in context: ModelContext
    ) -> [LoggedEntry] {
        let foodID = food.id
        let descriptor = FetchDescriptor<LoggedEntry>(
            predicate: #Predicate { $0.originalFoodItem?.id == foodID }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func logStats(in context: ModelContext) -> [UUID: FoodLogStats] {
        var descriptor = FetchDescriptor<LoggedEntry>(
            predicate: #Predicate { $0.parentEntry == nil }
        )
        descriptor.propertiesToFetch = [\.timestamp]
        descriptor.relationshipKeyPathsForPrefetching = [\.originalFoodItem]
        return FoodLogStats.byFood((try? context.fetch(descriptor)) ?? [])
    }

    static func topLevelLogsDescriptor(
        for food: FoodItem
    ) -> FetchDescriptor<LoggedEntry> {
        let foodID = food.id
        return FetchDescriptor<LoggedEntry>(
            predicate: #Predicate {
                $0.originalFoodItem?.id == foodID && $0.parentEntry == nil
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
    }

    static func recipeIngredients(
        using food: FoodItem,
        in context: ModelContext
    ) -> [RecipeIngredient] {
        let foodID = food.id
        let descriptor = FetchDescriptor<RecipeIngredient>(
            predicate: #Predicate { $0.ingredientItem?.id == foodID }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func usage(
        of food: FoodItem,
        in context: ModelContext
    ) -> FoodItemUsage {
        let foodID = food.id
        let topLevelLogs = FetchDescriptor<LoggedEntry>(
            predicate: #Predicate {
                $0.originalFoodItem?.id == foodID && $0.parentEntry == nil
            }
        )
        let recipeIDs = Set(
            recipeIngredients(using: food, in: context).compactMap {
                $0.parentRecipe?.id
            }
        )
        return FoodItemUsage(
            logCount: (try? context.fetchCount(topLevelLogs)) ?? 0,
            recipeCount: recipeIDs.count
        )
    }

    static func toggleFavorite(_ food: FoodItem, in context: ModelContext) {
        if let favorite = food.favoriteEntry {
            context.delete(favorite)
        } else {
            let existingFavorites =
                (try? context.fetch(FetchDescriptor<FavoriteEntry>())) ?? []
            let maxIndex =
                existingFavorites.compactMap { $0.orderIndex }.max() ?? -1
            context.insert(
                FavoriteEntry(orderIndex: maxIndex + 1, foodItem: food)
            )
        }
        try? context.save()
    }

    static func delete(
        _ food: FoodItem,
        deletingLogs: Bool,
        in context: ModelContext
    ) {
        for entry in loggedEntries(for: food, in: context) {
            if deletingLogs && entry.parentEntry == nil {
                context.delete(entry)
            } else {
                entry.originalFoodItem = nil
            }
        }

        for ingredient in recipeIngredients(using: food, in: context) {
            ingredient.ingredientItem = nil
        }

        context.delete(food)

        do {
            try context.save()
        } catch {
            context.rollback()
            print("Failed to delete food: \(error.localizedDescription)")
        }
    }
}
