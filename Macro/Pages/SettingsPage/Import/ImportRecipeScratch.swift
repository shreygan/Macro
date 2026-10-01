//
//  ImportRecipeScratch.swift
//  Macro
//
//  Created by Shrey Gangwar on 9/30/26.
//

import Foundation
import SwiftData

struct ImportRecipeEdit: Identifiable {
    let id = UUID()
    let draftID: UUID
    let recipe: FoodItem
}

@MainActor
enum ImportRecipeScratch {
    private static let container: ModelContainer? = {
        let schema = Schema([
            User.self,
            FoodItem.self,
            EntrySource.self,
            CategorySource.self,
            FoodGroupSource.self,
            ServingSizeUnit.self,
            FavoriteEntry.self,
            LoggedEntry.self,
            EntryDraft.self,
        ])
        let configuration = ModelConfiguration(
            "ImportRecipeScratch",
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try? ModelContainer(for: schema, configurations: [configuration])
    }()

    private static var currentContext: ModelContext?

    static func makeRecipe(from draft: DraftFoodItem) -> FoodItem? {
        guard let container else { return nil }

        let context = ModelContext(container)
        context.autosaveEnabled = false
        currentContext = context
        let resolver = ImportResolver(context: context)

        let note = (draft.stickyNote ?? "").trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let recipe = FoodItem(
            id: draft.importID ?? UUID(),
            name: draft.name,
            type: .recipe,
            source: resolver.source(draft.source),
            category: resolver.category(draft.category),
            foodGroup: resolver.foodGroup(draft.foodGroup),
            servingSize: draft.servingSize,
            servingUnit: resolver.unit(draft.servingUnit, plural: nil),
            servingWeight: draft.servingWeight,
            servingWeightUnit: draft.servingWeightUnit,
            isAIEstimated: draft.isAIEstimated,
            calories: draft.calories,
            protein: draft.protein,
            carbs: draft.carbs,
            fat: draft.fat,
            fiber: draft.fiber,
            isCustomDefaultServing: draft.isCustomDefaultServing,
            customServingSize: draft.customServingSize,
            stickyNote: note.isEmpty ? nil : Note(text: note)
        )
        context.insert(recipe)

        var itemsByID: [UUID: FoodItem] = [:]

        for (index, ingredient) in draft.ingredients.enumerated() {
            let itemID = ingredient.linkedItemID ?? UUID()
            let item =
                itemsByID[itemID]
                ?? FoodItem(
                    id: itemID,
                    name: ingredient.name,
                    type: ingredient.linkedItemType ?? .ingredient,
                    source: resolver.source(ingredient.linkedItemSource),
                    servingSize: ingredient.baseServingSize,
                    servingUnit: resolver.unit(
                        ingredient.baseServingUnitName ?? "serving",
                        plural: nil
                    ),
                    servingWeight: ingredient.baseServingWeight,
                    servingWeightUnit: ingredient.baseServingWeightUnit,
                    isAIEstimated: false,
                    calories: ingredient.baseCalories,
                    protein: ingredient.baseProtein,
                    carbs: ingredient.baseCarbs,
                    fat: ingredient.baseFat,
                    fiber: ingredient.baseFiber,
                    isCustomDefaultServing: false
                )

            if itemsByID[itemID] == nil {
                context.insert(item)
                itemsByID[itemID] = item
            }

            let recipeIngredient = RecipeIngredient(
                quantity: ingredient.quantity,
                unit: ingredient.unit,
                displayOrder: index,
                name: ingredient.name,
                baseServingSize: ingredient.baseServingSize,
                baseServingUnitName: ingredient.baseServingUnitName,
                baseServingWeight: ingredient.baseServingWeight,
                baseServingWeightUnit: ingredient.baseServingWeightUnit,
                baseCalories: ingredient.baseCalories,
                baseProtein: ingredient.baseProtein,
                baseCarbs: ingredient.baseCarbs,
                baseFat: ingredient.baseFat,
                baseFiber: ingredient.baseFiber
            )
            recipeIngredient.ingredientItem = item
            recipeIngredient.parentRecipe = recipe

            context.insert(recipeIngredient)
            recipe.recipeIngredients?.append(recipeIngredient)
        }

        return recipe
    }
}
