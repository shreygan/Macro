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
    @Attribute(.unique) var id: UUID

    var parentRecipe: FoodItem?
    var ingredientItem: FoodItem?

    var quantity: Double
    var unit: String
    var displayOrder: Int

    // Cached data incase Ingredient deleted
    var name: String

    var baseServingSize: Double
    var baseServingUnitName: String?
    var baseServingWeight: Double?
    var baseServingWeightUnit: String

    var baseCalories: Double
    var baseProtein: Double
    var baseCarbs: Double
    var baseFat: Double
    var baseFiber: Double

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
}
