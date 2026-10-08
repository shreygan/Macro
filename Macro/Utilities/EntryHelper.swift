//
//  EntryHelper.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/12/26.
//

import Foundation
import UIKit

enum EntryHelper {

    /// Formats a Double into a clean string, dropping trailing zeros
    static func format(_ number: Double?) -> String {
        guard let number = number else { return "" }
        return String(format: "%g", number)
    }

    /// Calculates the multiplier based on target and base portions
    static func calculateMultiplier(targetPortion: Double, basePortion: Double)
        -> Double
    {
        guard basePortion > 0 else { return 0.0 }
        return targetPortion / basePortion
    }

    static func portionMultiplier(
        quantity: Double,
        unit: String,
        servingSize: Double,
        servingWeight: Double?,
        servingWeightUnit: String
    ) -> Double? {
        if unit == servingWeightUnit, let servingWeight {
            return servingWeight > 0 ? quantity / servingWeight : nil
        }
        return servingSize > 0 ? quantity / servingSize : nil
    }

    static func ingredientMultiplier(
        quantity: Double,
        unit: String,
        baseServingSize: Double,
        baseServingWeight: Double?,
        baseServingWeightUnit: String
    ) -> Double {
        portionMultiplier(
            quantity: quantity,
            unit: unit,
            servingSize: baseServingSize,
            servingWeight: baseServingWeight,
            servingWeightUnit: baseServingWeightUnit
        ) ?? 0
    }

    static func ingredientWeight(
        quantity: Double,
        unit: String,
        baseServingSize: Double,
        baseServingWeight: Double?,
        baseServingWeightUnit: String
    ) -> Double? {
        if unit == baseServingWeightUnit { return quantity }
        guard let baseServingWeight else { return nil }
        return baseServingWeight
            * ingredientMultiplier(
                quantity: quantity,
                unit: unit,
                baseServingSize: baseServingSize,
                baseServingWeight: baseServingWeight,
                baseServingWeightUnit: baseServingWeightUnit
            )
    }

    static func recipeWeight(for recipe: FoodItem) -> Double? {
        if let servingWeight = recipe.servingWeight { return servingWeight }
        let total = (recipe.recipeIngredients ?? [])
            .compactMap {
                ingredientWeight(
                    quantity: $0.quantity,
                    unit: $0.unit,
                    baseServingSize: $0.baseServingSize,
                    baseServingWeight: $0.baseServingWeight,
                    baseServingWeightUnit: $0.baseServingWeightUnit
                )
            }
            .reduce(0, +)
        return total > 0 ? total : nil
    }

    static func defaultPortion(for food: FoodItem) -> Double {
        (food.isCustomDefaultServing ? food.customServingSize : nil) ?? food.servingSize
    }

    static func defaultPortionMultiplier(for food: FoodItem) -> Double {
        calculateMultiplier(targetPortion: defaultPortion(for: food), basePortion: food.servingSize)
    }

    static func portionText(
        quantity: Double,
        unit: String,
        servingUnits: [ServingSizeUnit]
    ) -> String {
        let quantityText = format(quantity)
        let unitText =
            servingUnits.first { $0.unit == unit }?
            .displayString(for: quantityText) ?? unit
        return "\(quantityText) \(unitText)"
    }

    static func formatMacro(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }

    /// Scales a macro string by a given multiplier
    static func scale(_ valueString: String, by multiplier: Double) -> String {
        guard !valueString.isEmpty, let value = Double(valueString) else {
            return valueString
        }
        return format(value * multiplier)
    }

    /// Converts a logged entry's saved photos into editable draft photos
    static func loggedPhotos(from photos: [EntryPhoto]?) -> [LoggedPhoto] {
        (photos ?? [])
            .sorted { $0.displayOrder < $1.displayOrder }
            .compactMap { photoEntity -> LoggedPhoto? in
                guard let uiImage = UIImage(data: photoEntity.imageData) else {
                    return nil
                }
                return LoggedPhoto(
                    image: uiImage,
                    originalData: photoEntity.imageData,
                    pickerItem: nil,
                    scale: CGFloat(photoEntity.scale),
                    offset: CGSize(
                        width: photoEntity.offsetX,
                        height: photoEntity.offsetY
                    )
                )
            }
    }

    /// The portion multiplier a recipe was logged with
    static func loggedRecipeMultiplier(for entry: LoggedEntry) -> Double {
        guard let recipe = entry.originalFoodItem,
            let multiplier = portionMultiplier(
                quantity: entry.loggedQuantity,
                unit: entry.loggedUnit,
                servingSize: recipe.servingSize,
                servingWeight: recipeWeight(for: recipe),
                servingWeightUnit: recipe.servingWeightUnit
            ),
            multiplier > 0
        else { return 1 }
        return multiplier
    }
}
