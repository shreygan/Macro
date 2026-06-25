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

    var type: EntryType

    var source: EntrySource?
    var category: CategorySource?
    var foodGroup: FoodGroupSource?

    var servingUnit: ServingSizeUnit?
    var servingSize: Double
    var servingWeight: Double?
    var servingWeightUnit: String

    var isAIEstimated: Bool

    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double

    var isCustomDefaultServing: Bool
    var customServingSize: Double?

    var dateAdded: Date

    @Relationship(deleteRule: .cascade)
    var stickyNote: Note?

    @Relationship(deleteRule: .cascade, inverse: \RecipeIngredient.parentRecipe)
    var recipeIngredients: [RecipeIngredient]? = []

    init(
        id: UUID = UUID(),
        name: String,
        type: EntryType = .food,
        source: EntrySource? = nil,
        category: CategorySource? = nil,
        foodGroup: FoodGroupSource? = nil,
        servingSize: Double,
        servingUnit: ServingSizeUnit? = nil,
        servingWeight: Double? = nil,
        servingWeightUnit: String,
        isAIEstimated: Bool,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        fiber: Double,
        isCustomDefaultServing: Bool,
        customServingSize: Double? = nil,
        stickyNote: Note? = nil,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.source = source
        self.category = category
        self.foodGroup = foodGroup
        self.servingSize = servingSize
        self.servingUnit = servingUnit
        self.servingWeight = servingWeight
        self.servingWeightUnit = servingWeightUnit
        self.isAIEstimated = isAIEstimated
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.isCustomDefaultServing = isCustomDefaultServing
        self.customServingSize = customServingSize
        self.stickyNote = stickyNote
        self.dateAdded = dateAdded
    }
}
