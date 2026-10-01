//
//  DraftFoodItem.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/31/26.
//

import SwiftData
import SwiftUI

struct DraftFoodItem: Identifiable, Equatable {
    let id = UUID()
    var type: EntryType = .food
    var name: String
    var source: String
    var category: String
    var foodGroup: String
    var servingSize: Double
    var servingUnit: String
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
    var stickyNote: String?
    var isFavorite: Bool = false
    var favoriteOrder: Int? = nil
    var importID: UUID? = nil
    var servingUnitPlural: String? = nil
    var noteUpdated: Date? = nil
    var dateAdded: Date? = nil
    var ingredients: [DraftImportIngredient] = []
    var duplicateOf: UUID? = nil
}

struct DraftImportIngredient: Equatable {
    var linkedItemID: UUID?
    var linkedItemType: EntryType?
    var linkedItemSource: String
    var name: String
    var quantity: Double
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

    var multiplier: Double {
        EntryHelper.ingredientMultiplier(
            quantity: quantity,
            unit: unit,
            baseServingSize: baseServingSize,
            baseServingWeight: baseServingWeight,
            baseServingWeightUnit: baseServingWeightUnit
        )
    }
}
