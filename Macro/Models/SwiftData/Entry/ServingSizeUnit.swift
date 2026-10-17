//
//  ServingSizeUnit.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/12/26.
//

import Foundation
import SwiftData

@Model
class ServingSizeUnit {
    var id: UUID = UUID()
    var unit: String = ""

    var pluralVariant: String?
    var isDefault: Bool = false
    var displayOrder: Int = 0

    @Relationship(deleteRule: .nullify, inverse: \FoodItem.servingUnit)
    var foods: [FoodItem]? = []

    init(
        unit: String,
        pluralVariant: String? = nil,
        isDefault: Bool = false,
        displayOrder: Int
    ) {
        self.unit = unit
        self.pluralVariant = pluralVariant
        self.isDefault = isDefault
        self.displayOrder = displayOrder
    }

    func displayString(for quantity: String) -> String {
        let trimmedQuantity = quantity.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        if let numericValue = Double(trimmedQuantity), numericValue == 1.0 {
            return unit
        }

        if let plural = pluralVariant, !plural.isEmpty {
            return plural
        } else {
            return unit
        }
    }
}
