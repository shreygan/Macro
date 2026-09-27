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

    var ingredientItem: FoodItem?

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
        self.ingredientItem = recipeIngredient.ingredientItem
    }

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
        self.ingredientItem = item
    }

    init(loggedEntry: LoggedEntry, recipeMultiplier: Double) {
        let multiplier = recipeMultiplier > 0 ? recipeMultiplier : 1
        let item = loggedEntry.originalFoodItem
        let qty = loggedEntry.loggedQuantity / multiplier

        self.name = loggedEntry.name
        self.quantity = EntryHelper.format(qty)
        self.unit = loggedEntry.loggedUnit
        self.baseServingWeightUnit = item?.servingWeightUnit ?? "g"

        if qty <= 0 {
            // A zero quantity can't act as a base, so fall back to the item
            self.baseServingSize = item?.servingSize ?? 1
            self.baseServingUnitName =
                item?.servingUnit?.unit ?? loggedEntry.loggedUnit
            self.baseServingWeight = item?.servingWeight
        } else if let item, let itemWeight = item.servingWeight,
            itemWeight > 0, loggedEntry.loggedUnit == item.servingWeightUnit
        {
            // Logged by weight
            self.baseServingWeight = qty
            self.baseServingSize = qty / itemWeight * item.servingSize
            self.baseServingUnitName = item.servingUnit?.unit
        } else {
            // Logged by serving unit
            self.baseServingSize = qty
            self.baseServingUnitName = loggedEntry.loggedUnit
            if let item, let itemWeight = item.servingWeight,
                item.servingSize > 0
            {
                self.baseServingWeight = qty / item.servingSize * itemWeight
            } else {
                self.baseServingWeight = nil
            }
        }

        if qty <= 0, let item {
            self.baseCalories = item.calories
            self.baseProtein = item.protein
            self.baseCarbs = item.carbs
            self.baseFat = item.fat
            self.baseFiber = item.fiber
        } else {
            self.baseCalories = loggedEntry.calories / multiplier
            self.baseProtein = loggedEntry.protein / multiplier
            self.baseCarbs = loggedEntry.carbs / multiplier
            self.baseFat = loggedEntry.fat / multiplier
            self.baseFiber = loggedEntry.fiber / multiplier
        }

        self.icon = item?.type.appSymbol.rawValue
        self.ingredientItem = item
    }

    static func makeDrafts(for entry: LoggedEntry) -> [LogRecipeIngredient] {
        let multiplier = EntryHelper.loggedRecipeMultiplier(for: entry)
        return (entry.childEntries ?? [])
            .sorted { $0.displayOrder < $1.displayOrder }
            .map {
                LogRecipeIngredient(
                    loggedEntry: $0,
                    recipeMultiplier: multiplier
                )
            }
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
