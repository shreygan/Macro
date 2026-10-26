//
//  DrinkSize.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/18/26.
//

import Foundation
import SwiftData

@Model
class DrinkSize {
    var id: UUID = UUID()
    var name: String?
    var volumeML: Double = 0
    var displayOrder: Int = 0
    var isDefault: Bool = false

    var food: FoodItem?

    init(
        id: UUID = UUID(),
        name: String? = nil,
        volumeML: Double,
        displayOrder: Int,
        isDefault: Bool = false,
        food: FoodItem? = nil
    ) {
        self.id = id
        self.name = name
        self.volumeML = volumeML
        self.displayOrder = displayOrder
        self.isDefault = isDefault
        self.food = food
    }
}
