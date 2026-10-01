//
//  LoggedEntryPrefill.swift
//  Macro
//
//  Created by Shrey Gangwar on 9/30/26.
//

import Foundation

extension LoggedEntry {
    var sortedComponents: [LoggedEntry] {
        (childEntries ?? []).sorted { $0.displayOrder < $1.displayOrder }
    }

    var libraryEntryType: EntryType {
        switch entryType {
        case .recipe: sortedComponents.isEmpty ? .food : .recipe
        case .some(let type): type
        case .none: .food
        }
    }

    private var isLoggedByWeight: Bool {
        ["g", "ml"].contains(loggedUnit)
    }

    private var prefillServing: (size: String, unit: String, weight: String, weightUnit: String) {
        if isLoggedByWeight {
            return ("1", "serving", EntryHelper.format(loggedQuantity), loggedUnit)
        }
        return (
            EntryHelper.format(loggedQuantity > 0 ? loggedQuantity : 1),
            loggedUnit.isEmpty ? "serving" : loggedUnit,
            "",
            "g"
        )
    }

    var addEntryPrefill: AddEntryDraftState {
        let serving = prefillServing
        return AddEntryDraftState(
            name: name,
            source: source?.source ?? "",
            category: category?.category ?? "",
            foodGroup: foodGroup?.foodGroup ?? "",
            servingSize: serving.size,
            servingSizeUnit: serving.unit,
            servingWeight: serving.weight,
            servingWeightUnit: serving.weightUnit,
            isAIEstimated: false,
            macros: DraftMacroValues(
                calories: EntryHelper.format(calories),
                protein: EntryHelper.format(protein),
                carbs: EntryHelper.format(carbs),
                fat: EntryHelper.format(fat),
                fiber: EntryHelper.format(fiber)
            ),
            isCustomDefaultServing: false,
            customServingSize: "1",
            stickyNote: logNote ?? ""
        )
    }

    var addRecipePrefill: AddRecipePrefill {
        let serving = prefillServing
        let state = AddRecipeDraftState(
            name: name,
            source: source?.source ?? "",
            category: category?.category ?? "",
            servingSize: serving.size,
            servingSizeUnit: serving.unit,
            servingWeight: "",
            servingWeightUnit: serving.weightUnit,
            isCustomDefaultServing: false,
            customServingSize: "1",
            ingredients: [],
            stickyNote: logNote ?? ""
        )

        let ingredients = sortedComponents.map { child in
            guard let item = child.originalFoodItem else {
                return DraftRecipeIngredient(
                    logIngredient: LogRecipeIngredient(
                        loggedEntry: child,
                        recipeMultiplier: 1
                    )
                )
            }
            var ingredient = DraftRecipeIngredient(item: item)
            ingredient.quantity = EntryHelper.format(child.loggedQuantity)
            ingredient.unit = child.loggedUnit
            return ingredient
        }

        return AddRecipePrefill(state: state, ingredients: ingredients)
    }
}

struct AddRecipePrefill {
    var state: AddRecipeDraftState
    var ingredients: [DraftRecipeIngredient]
}
