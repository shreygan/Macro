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

    static func defaultPortion(for food: FoodItem) -> Double {
        (food.isCustomDefaultServing ? food.customServingSize : nil) ?? food.servingSize
    }

    static func defaultPortionMultiplier(for food: FoodItem) -> Double {
        calculateMultiplier(targetPortion: defaultPortion(for: food), basePortion: food.servingSize)
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
        guard let recipe = entry.originalFoodItem else { return 1 }

        let multiplier: Double
        if entry.loggedUnit == recipe.servingWeightUnit
            && entry.loggedUnit != recipe.servingUnit?.unit
        {
            multiplier = recipe.servingWeight.map { entry.loggedQuantity / $0 }
                ?? 1
        } else {
            multiplier = entry.loggedQuantity / recipe.servingSize
        }
        return multiplier.isFinite && multiplier > 0 ? multiplier : 1
    }
}
