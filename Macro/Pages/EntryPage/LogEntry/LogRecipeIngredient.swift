//
//  LogRecipeIngredient.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/23/26.
//

import SwiftUI

struct LogRecipeIngredient: Identifiable, Equatable {
    let id = UUID()
    var name: String

    var quantity: String
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

    var icon: String?

    // Initialize from an existing recipe ingredient
    init(recipeIngredient: RecipeIngredient) {
        self.name = recipeIngredient.name
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

        self.icon = recipeIngredient.ingredientItem?.type.appSymbol.rawValue
    }

    // Initialize from a newly added FoodItem
    init(item: FoodItem) {
        self.name = item.name
        self.unit = item.servingUnit?.unit ?? "serving"

        let defaultQty =
            item.isCustomDefaultServing
            ? (item.customServingSize ?? item.servingSize) : item.servingSize
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

        self.icon = item.type.appSymbol.rawValue
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
}
