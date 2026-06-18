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
    var isFavorite: Bool = false
}
