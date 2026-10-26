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
    var draftCount: Int = 0

    var hasUses: Bool {
        logCount > 0 || recipeCount > 0 || draftCount > 0
    }
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

struct FoodRecipeStats {
    var recipeIDs: Set<UUID>
    var lastUsed: Date

    var count: Int { recipeIDs.count }
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

    static func logStats(
        in context: ModelContext,
        includingHydrationLogs: Bool = false
    ) -> [UUID: FoodLogStats] {
        var descriptor = FetchDescriptor<LoggedEntry>(
            predicate: includingHydrationLogs
                ? #Predicate { $0.parentEntry == nil }
                : #Predicate { $0.parentEntry == nil && !$0.isHydrationLog }
        )
        descriptor.propertiesToFetch = [\.timestamp]
        descriptor.relationshipKeyPathsForPrefetching = [\.originalFoodItem]
        return FoodLogStats.byFood((try? context.fetch(descriptor)) ?? [])
    }

    static func logStats(
        for foods: [FoodItem],
        in context: ModelContext
    ) -> [UUID: FoodLogStats] {
        var result: [UUID: FoodLogStats] = [:]
        for food in foods {
            var latest = topLevelLogsDescriptor(for: food)
            latest.fetchLimit = 1
            guard
                let count = try? context.fetchCount(topLevelLogsDescriptor(for: food)),
                count > 0,
                let last = try? context.fetch(latest).first
            else { continue }
            result[food.id] = FoodLogStats(count: count, lastLogged: last.timestamp)
        }
        return result
    }

    static func topLevelLogsDescriptor(
        for food: FoodItem
    ) -> FetchDescriptor<LoggedEntry> {
        let foodID = food.id
        return FetchDescriptor<LoggedEntry>(
            predicate: #Predicate {
                $0.originalFoodItem?.id == foodID && $0.parentEntry == nil
            },
            sortBy: [
                SortDescriptor(\.timestamp, order: .reverse),
                SortDescriptor(\.id),
            ]
        )
    }

    static func hasPhotoHistory(
        for food: FoodItem,
        excluding entryID: UUID? = nil,
        in context: ModelContext
    ) -> Bool {
        let foodID = food.id
        let predicate: Predicate<EntryPhoto>
        if let entryID {
            predicate = #Predicate {
                $0.parentEntry?.originalFoodItem?.id == foodID
                    && $0.parentEntry?.parentEntry == nil
                    && $0.parentEntry?.id != entryID
            }
        } else {
            predicate = #Predicate {
                $0.parentEntry?.originalFoodItem?.id == foodID
                    && $0.parentEntry?.parentEntry == nil
            }
        }
        let count = (try? context.fetchCount(FetchDescriptor(predicate: predicate))) ?? 0
        return count > 0
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

    static func recipeStats(in context: ModelContext) -> [UUID: FoodRecipeStats] {
        var descriptor = FetchDescriptor<RecipeIngredient>()
        descriptor.relationshipKeyPathsForPrefetching = [
            \.ingredientItem, \.parentRecipe,
        ]
        var result: [UUID: FoodRecipeStats] = [:]
        for ingredient in (try? context.fetch(descriptor)) ?? [] {
            guard let id = ingredient.ingredientItem?.id,
                let recipe = ingredient.parentRecipe
            else { continue }
            if var stats = result[id] {
                stats.recipeIDs.insert(recipe.id)
                stats.lastUsed = max(stats.lastUsed, ingredient.dateAdded)
                result[id] = stats
            } else {
                result[id] = FoodRecipeStats(
                    recipeIDs: [recipe.id],
                    lastUsed: ingredient.dateAdded
                )
            }
        }
        return result
    }

    static func recipesContaining(
        _ food: FoodItem,
        in context: ModelContext
    ) -> Set<UUID> {
        var descriptor = FetchDescriptor<RecipeIngredient>()
        descriptor.relationshipKeyPathsForPrefetching = [
            \.ingredientItem, \.parentRecipe,
        ]
        var parents: [UUID: Set<UUID>] = [:]
        for ingredient in (try? context.fetch(descriptor)) ?? [] {
            guard let childID = ingredient.ingredientItem?.id,
                let parentID = ingredient.parentRecipe?.id
            else { continue }
            parents[childID, default: []].insert(parentID)
        }

        var result: Set<UUID> = []
        var queue = [food.id]
        while let id = queue.popLast() {
            for parentID in parents[id] ?? [] {
                if result.insert(parentID).inserted {
                    queue.append(parentID)
                }
            }
        }
        return result
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
            recipeCount: recipeIDs.count,
            draftCount: food.drafts?.count ?? 0
        )
    }

    @discardableResult
    static func toggleFavorite(
        _ food: FoodItem,
        in context: ModelContext,
        at orderIndex: Int? = nil
    ) throws -> Int? {
        let previousOrder = food.favoriteEntry?.orderIndex
        if let favorite = food.favoriteEntry {
            context.delete(favorite)
        } else {
            insertFavorite(food, at: orderIndex, in: context)
            food.isInLibrary = true
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return previousOrder
    }

    static func setInLibrary(
        _ isInLibrary: Bool,
        for food: FoodItem,
        restoringFavoriteAt favoriteOrder: Int? = nil,
        in context: ModelContext
    ) throws -> Int? {
        let previousOrder = food.favoriteEntry?.orderIndex
        food.isInLibrary = isInLibrary
        if !isInLibrary, let favorite = food.favoriteEntry {
            context.delete(favorite)
        } else if isInLibrary, let favoriteOrder, food.favoriteEntry == nil {
            insertFavorite(food, at: favoriteOrder, in: context)
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return previousOrder
    }

    static func insertFavorite(
        _ food: FoodItem,
        at orderIndex: Int?,
        in context: ModelContext
    ) {
        let existingFavorites =
            (try? context.fetch(FetchDescriptor<FavoriteEntry>())) ?? []
        guard let orderIndex else {
            let maxIndex = existingFavorites.map(\.orderIndex).max() ?? -1
            context.insert(FavoriteEntry(orderIndex: maxIndex + 1, foodItem: food))
            return
        }
        if existingFavorites.contains(where: { $0.orderIndex == orderIndex }) {
            for favorite in existingFavorites where favorite.orderIndex >= orderIndex {
                favorite.orderIndex += 1
            }
        }
        context.insert(FavoriteEntry(orderIndex: orderIndex, foodItem: food))
    }
}
