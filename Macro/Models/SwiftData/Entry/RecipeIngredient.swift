//
//  RecipeIngredient.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/16/26.
//

import SwiftData
import SwiftUI

@Model
class RecipeIngredient {
    var id: UUID = UUID()

    var parentRecipe: FoodItem?
    var ingredientItem: FoodItem?

    var quantity: Double = 0
    var unit: String = ""
    var displayOrder: Int = 0
    var dateAdded: Date = Date.now

    // Cached data incase Ingredient deleted
    var name: String = ""

    var baseServingSize: Double = 0
    var baseServingUnitName: String?
    var baseServingWeight: Double?
    var baseServingWeightUnit: String = ""

    var baseCalories: Double = 0
    var baseProtein: Double = 0
    var baseCarbs: Double = 0
    var baseFat: Double = 0
    var baseFiber: Double = 0

    init(
        id: UUID = UUID(),
        quantity: Double,
        unit: String,
        displayOrder: Int,
        name: String,
        baseServingSize: Double,
        baseServingUnitName: String?,
        baseServingWeight: Double?,
        baseServingWeightUnit: String,
        baseCalories: Double,
        baseProtein: Double,
        baseCarbs: Double,
        baseFat: Double,
        baseFiber: Double
    ) {
        self.id = id
        self.quantity = quantity
        self.unit = unit
        self.displayOrder = displayOrder
        self.name = name
        self.baseServingSize = baseServingSize
        self.baseServingUnitName = baseServingUnitName
        self.baseServingWeight = baseServingWeight
        self.baseServingWeightUnit = baseServingWeightUnit
        self.baseCalories = baseCalories
        self.baseProtein = baseProtein
        self.baseCarbs = baseCarbs
        self.baseFat = baseFat
        self.baseFiber = baseFiber
    }

    static func datesByItem(_ ingredients: [RecipeIngredient]) -> [UUID: Date] {
        var result: [UUID: Date] = [:]
        for ingredient in ingredients {
            guard let id = ingredient.ingredientItem?.id else { continue }
            result[id] = min(result[id] ?? ingredient.dateAdded, ingredient.dateAdded)
        }
        return result
    }

    var calories: Double {
        let multiplier = EntryHelper.ingredientMultiplier(
            quantity: quantity,
            unit: unit,
            baseServingSize: baseServingSize,
            baseServingWeight: baseServingWeight,
            baseServingWeightUnit: baseServingWeightUnit
        )
        return multiplier.isFinite ? baseCalories * multiplier : 0
    }
}
