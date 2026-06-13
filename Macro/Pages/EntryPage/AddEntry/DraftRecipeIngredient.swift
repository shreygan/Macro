//
//  DraftRecipeIngredient.swift
//  Macro
//
//  Created by Shrey Gangwar on 6/2/26.
//

import SwiftUI

struct DraftRecipeIngredient: Identifiable {
    let id = UUID()
    let item: FoodItem

    var quantity: String = "1"
    var unit: String

    var baseServingSize: Double
    var baseServingUnitName: String?
    var baseServingWeight: Double?
    var baseServingWeightUnit: String
    var baseCalories: Double
    var baseProtein: Double
    var baseCarbs: Double
    var baseFat: Double
    var baseFiber: Double

    init(item: FoodItem) {
        self.item = item
        self.unit = item.servingUnit?.unit ?? "serving"

        let defaultQty =
            item.isCustomDefaultServing
            ? item.customServingSize : item.servingSize
        self.quantity = EntryHelper.format(defaultQty)

        self.baseServingSize = item.servingSize
        self.baseServingUnitName = item.servingUnit?.unit
        self.baseServingWeight = item.servingWeight
        self.baseServingWeightUnit = item.servingWeightUnit
        self.baseCalories = item.calories
        self.baseProtein = item.protein
        self.baseCarbs = item.carbs
        self.baseFat = item.fat
        self.baseFiber = item.fiber
    }

    init(recipeIngredient: RecipeIngredient) {
        self.item = recipeIngredient.ingredientItem!
        self.quantity = EntryHelper.format(recipeIngredient.quantity)
        self.unit = recipeIngredient.unit

        self.baseServingSize = recipeIngredient.baseServingSize
        self.baseServingUnitName = recipeIngredient.baseServingUnitName
        self.baseServingWeight = recipeIngredient.baseServingWeight
        self.baseServingWeightUnit = recipeIngredient.baseServingWeightUnit
        self.baseCalories = recipeIngredient.baseCalories
        self.baseProtein = recipeIngredient.baseProtein
        self.baseCarbs = recipeIngredient.baseCarbs
        self.baseFat = recipeIngredient.baseFat
        self.baseFiber = recipeIngredient.baseFiber
    }

    var activeMultiplier: Double {
        guard let qty = Double(quantity) else { return 0 }

        if unit == baseServingWeightUnit, let baseWeight = baseServingWeight {
            return qty / baseWeight
        }
        return qty / baseServingSize
    }

    var activeCalories: Double { baseCalories * activeMultiplier }
    var activeProtein: Double { baseProtein * activeMultiplier }
    var activeCarbs: Double { baseCarbs * activeMultiplier }
    var activeFat: Double { baseFat * activeMultiplier }
    var activeFiber: Double { baseFiber * activeMultiplier }

    var activeWeight: Double? {
        if unit == baseServingWeightUnit {
            return Double(quantity)
        } else if let baseWeight = baseServingWeight {
            return baseWeight * activeMultiplier
        }
        return nil
    }

    mutating func updateUnit(to newUnit: String) {
        let oldUnit = self.unit
        guard oldUnit != newUnit else { return }

        let currentMultiplier = self.activeMultiplier

        if newUnit == baseServingWeightUnit, let baseWeight = baseServingWeight
        {
            let convertedQuantity = currentMultiplier * baseWeight
            self.quantity = EntryHelper.format(convertedQuantity)
        } else {
            let convertedQuantity = currentMultiplier * baseServingSize
            self.quantity = EntryHelper.format(convertedQuantity)
        }

        self.unit = newUnit
    }
}
