//
//  RecipeIngredient.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/16/26.
//

import SwiftData
import SwiftUI

@Model
class RecipeIngredient {
    @Attribute(.unique) var id: UUID

    var parentRecipe: FoodItem?

    var ingredientItem: FoodItem?

    var quantity: Double
    var unit: String

    init(id: UUID = UUID(), quantity: Double, unit: String) {
        self.id = id
        self.quantity = quantity
        self.unit = unit
    }
}
