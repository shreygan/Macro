//
//  FoodItem.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/12/26.
//

import Foundation
import SwiftData

@Model
class FoodItem {
    @Attribute(.unique) var id: UUID
    var name: String
    
    var source: EntrySource?
    var category: CategorySource?
    var servingUnit: ServingSizeUnit?

    var servingSize: Double
    var servingWeight: Double?
    var servingWeightUnit: String

    var isIngredientBased: Bool
    var isAIEstimated: Bool

    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double?

    var isCustomDefaultServing: Bool
    var customServingSize: Double?
    
    var dateAdded: Date

    init(
        id: UUID = UUID(),
        name: String,
        source: EntrySource? = nil,
        category: CategorySource? = nil,
        servingSize: Double,
        servingUnit: ServingSizeUnit? = nil,
        servingWeight: Double? = nil,
        servingWeightUnit: String,
        isIngredientBased: Bool,
        isAIEstimated: Bool,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        fiber: Double? = nil,
        isCustomDefaultServing: Bool,
        customServingSize: Double? = nil,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.source = source
        self.category = category
        self.servingSize = servingSize
        self.servingUnit = servingUnit
        self.servingWeight = servingWeight
        self.servingWeightUnit = servingWeightUnit
        self.isIngredientBased = isIngredientBased
        self.isAIEstimated = isAIEstimated
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.isCustomDefaultServing = isCustomDefaultServing
        self.customServingSize = customServingSize
        self.dateAdded = dateAdded
    }
}
