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
    @Attribute(.unique) var unit: String

    var pluralVariant: String?
    var isDefault: Bool
    var displayOrder: Int

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
