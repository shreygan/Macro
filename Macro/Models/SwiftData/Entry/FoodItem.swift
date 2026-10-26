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
    var id: UUID = UUID()
    var name: String = ""

    var type: EntryType = EntryType.food

    var source: EntrySource?
    var category: CategorySource?
    var foodGroup: FoodGroupSource?

    var servingUnit: ServingSizeUnit?
    var servingSize: Double = 1
    var servingWeight: Double?
    var servingWeightUnit: String = ""

    var isAIEstimated: Bool = false

    var calories: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var fiber: Double = 0

    var isCustomDefaultServing: Bool = false
    var customServingSize: Double?

    var defaultLocation: EntryLocation?

    var hydrationPercent: Double = 100
    var caffeineMg: Double?
    var abv: Double?
    var hasNutrition: Bool = false
    var symbol: String?
    var tintRawValue: String?
    var hydrationOrder: Int?
    var seedKey: String?
    var isInLibrary: Bool = true

    var dateAdded: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \DrinkSize.food)
    var drinkSizes: [DrinkSize]? = []

    @Relationship(deleteRule: .cascade, inverse: \Note.foodItem)
    var stickyNote: Note?

    @Relationship(deleteRule: .nullify, inverse: \LoggedEntry.originalFoodItem)
    var loggedEntries: [LoggedEntry]? = []

    @Relationship(deleteRule: .nullify, inverse: \RecipeIngredient.ingredientItem)
    var usedInRecipes: [RecipeIngredient]? = []

    @Relationship(deleteRule: .cascade, inverse: \RecipeIngredient.parentRecipe)
    var recipeIngredients: [RecipeIngredient]? = []

    @Relationship(deleteRule: .cascade, inverse: \FavoriteEntry.foodItem)
    var favoriteEntry: FavoriteEntry?

    @Relationship(deleteRule: .cascade, inverse: \EntryDraft.foodItem)
    var drafts: [EntryDraft]? = []

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
        defaultLocation: EntryLocation? = nil,
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
        self.defaultLocation = defaultLocation
        self.stickyNote = stickyNote
        self.dateAdded = dateAdded
    }
}
