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
