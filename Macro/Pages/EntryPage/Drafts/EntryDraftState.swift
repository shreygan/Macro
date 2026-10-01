//
//  EntryDraftState.swift
//  Macro
//
//  Created by Shrey Gangwar on 9/28/26.
//

import Foundation


struct DraftMacroValues: Codable, Equatable {
    var calories: String
    var protein: String
    var carbs: String
    var fat: String
    var fiber: String
}

struct DraftIngredientSnapshot: Codable, Equatable {
    var foodItemID: UUID?
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
}

extension DraftIngredientSnapshot {
    init(_ ingredient: LogRecipeIngredient) {
        self.foodItemID = ingredient.ingredientItem?.id
        self.name = ingredient.name
        self.quantity = ingredient.quantity
        self.unit = ingredient.unit
        self.baseServingSize = ingredient.baseServingSize
        self.baseServingUnitName = ingredient.baseServingUnitName
        self.baseServingWeight = ingredient.baseServingWeight
        self.baseServingWeightUnit = ingredient.baseServingWeightUnit
        self.baseCalories = ingredient.baseCalories
        self.baseProtein = ingredient.baseProtein
        self.baseCarbs = ingredient.baseCarbs
        self.baseFat = ingredient.baseFat
        self.baseFiber = ingredient.baseFiber
    }

    init(_ ingredient: DraftRecipeIngredient) {
        self.foodItemID = ingredient.item?.id
        self.name = ingredient.displayName
        self.quantity = ingredient.quantity
        self.unit = ingredient.unit
        self.baseServingSize = ingredient.baseServingSize
        self.baseServingUnitName = ingredient.baseServingUnitName
        self.baseServingWeight = ingredient.baseServingWeight
        self.baseServingWeightUnit = ingredient.baseServingWeightUnit
        self.baseCalories = ingredient.baseCalories
        self.baseProtein = ingredient.baseProtein
        self.baseCarbs = ingredient.baseCarbs
        self.baseFat = ingredient.baseFat
        self.baseFiber = ingredient.baseFiber
    }
}

extension LogRecipeIngredient {
    init(snapshot: DraftIngredientSnapshot, item: FoodItem?) {
        self.name = snapshot.name
        self.quantity = snapshot.quantity
        self.unit = snapshot.unit
        self.baseServingSize = snapshot.baseServingSize
        self.baseServingUnitName = snapshot.baseServingUnitName
        self.baseServingWeight = snapshot.baseServingWeight
        self.baseServingWeightUnit = snapshot.baseServingWeightUnit
        self.baseCalories = snapshot.baseCalories
        self.baseProtein = snapshot.baseProtein
        self.baseCarbs = snapshot.baseCarbs
        self.baseFat = snapshot.baseFat
        self.baseFiber = snapshot.baseFiber
        self.icon = item?.type.appSymbol.rawValue
        self.ingredientItem = item
    }
}

struct DraftNoteState: Codable, Equatable {
    var stickyNote: String
    var newNote: String
    var isAddingNewNote: Bool
    var isNewNotePinned: Bool
    var isOriginalNotePinned: Bool
}

struct LogEntryDraftState: Codable, Equatable {
    var name: String

    var sourceSelection: String
    var categorySelection: String
    var foodGroupSelection: String

    var date: Date
    var time: Date
    var location: String

    var portionQuantity: String
    var portionUnitSelection: String

    var macros: DraftMacroValues
    var dynamicMacros: DraftMacroValues
    var manualOverrideToggle: Bool

    var notes: DraftNoteState

    var saveOptionRawValue: String
}

struct LogRecipeDraftState: Codable, Equatable {
    var name: String

    var sourceSelection: String
    var categorySelection: String

    var date: Date
    var time: Date
    var location: String

    var portionQuantity: String
    var portionUnitSelection: String

    var ingredients: [DraftIngredientSnapshot]

    var notes: DraftNoteState

    var saveOptionRawValue: String
}

struct AddEntryDraftState: Codable, Equatable {
    var name: String
    var source: String
    var category: String
    var foodGroup: String

    var servingSize: String
    var servingSizeUnit: String
    var servingWeight: String
    var servingWeightUnit: String

    var isAIEstimated: Bool

    var macros: DraftMacroValues

    var isCustomDefaultServing: Bool
    var customServingSize: String

    var stickyNote: String

    static let empty = AddEntryDraftState(
        name: "",
        source: "",
        category: "",
        foodGroup: "",
        servingSize: "1",
        servingSizeUnit: "serving",
        servingWeight: "",
        servingWeightUnit: "g",
        isAIEstimated: false,
        macros: DraftMacroValues(
            calories: "",
            protein: "",
            carbs: "",
            fat: "",
            fiber: ""
        ),
        isCustomDefaultServing: false,
        customServingSize: "1",
        stickyNote: ""
    )
}

struct AddRecipeDraftState: Codable, Equatable {
    var name: String
    var source: String
    var category: String

    var servingSize: String
    var servingSizeUnit: String
    var servingWeight: String
    var servingWeightUnit: String

    var isCustomDefaultServing: Bool
    var customServingSize: String

    var ingredients: [DraftIngredientSnapshot]

    var stickyNote: String

    static let empty = AddRecipeDraftState(
        name: "",
        source: "",
        category: "",
        servingSize: "1",
        servingSizeUnit: "serving",
        servingWeight: "",
        servingWeightUnit: "g",
        isCustomDefaultServing: false,
        customServingSize: "1",
        ingredients: [],
        stickyNote: ""
    )
}
