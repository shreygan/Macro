//
//  FoodItemPrefill.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/22/26.
//

import Foundation

extension FoodItem {
    private static func prefillString(_ value: Double?) -> String {
        guard let value else { return "" }
        return value.formatted(.number.grouping(.never).precision(.fractionLength(0...10)))
    }

    func duplicatePrefill(unit: VolumeUnit, pinsDrink: Bool) -> AddEntryDraftState {
        AddEntryDraftState(
            name: name,
            source: source?.source ?? "",
            category: category?.category ?? "",
            foodGroup: foodGroup?.foodGroup ?? "",
            servingSize: Self.prefillString(servingSize),
            servingSizeUnit: servingUnit?.unit ?? "serving",
            servingWeight: Self.prefillString(servingWeight),
            servingWeightUnit: servingWeightUnit.isEmpty ? "g" : servingWeightUnit,
            isAIEstimated: isAIEstimated,
            macros: DraftMacroValues(
                calories: Self.prefillString(calories),
                protein: Self.prefillString(protein),
                carbs: Self.prefillString(carbs),
                fat: Self.prefillString(fat),
                fiber: Self.prefillString(fiber)
            ),
            isCustomDefaultServing: isCustomDefaultServing,
            customServingSize: customServingSize.map { Self.prefillString($0) } ?? "1",
            stickyNote: "",
            defaultLocation: defaultLocation,
            drink: type == .drink ? duplicateDrinkForm(unit: unit, pinsDrink: pinsDrink) : nil
        )
    }

    private func duplicateDrinkForm(unit: VolumeUnit, pinsDrink: Bool) -> DrinkFormState? {
        var form = DrinkFormState(food: self, unit: unit)
        form.servingSizeID = nil
        form.sizes = form.sizes.map { size in
            var fresh = size
            fresh.id = UUID()
            return fresh
        }
        form.isPinned = pinsDrink
        return form.isPristine ? nil : form
    }

    var duplicateRecipePrefill: AddRecipePrefill {
        let state = AddRecipeDraftState(
            name: name,
            source: source?.source ?? "",
            category: category?.category ?? "",
            servingSize: Self.prefillString(servingSize),
            servingSizeUnit: servingUnit?.unit ?? "serving",
            servingWeight: Self.prefillString(servingWeight),
            servingWeightUnit: servingWeightUnit.isEmpty ? "g" : servingWeightUnit,
            isCustomDefaultServing: isCustomDefaultServing,
            customServingSize: customServingSize.map { Self.prefillString($0) } ?? "1",
            ingredients: [],
            stickyNote: "",
            defaultLocation: defaultLocation
        )
        let ingredients = (recipeIngredients ?? [])
            .sorted { $0.displayOrder < $1.displayOrder }
            .map { DraftRecipeIngredient(recipeIngredient: $0) }
        return AddRecipePrefill(state: state, ingredients: ingredients)
    }
}
