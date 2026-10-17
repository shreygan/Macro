//
//  FoodGroupSource.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/16/26.
//

import Foundation
import SwiftData

@Model
class FoodGroupSource {
    var id: UUID = UUID()
    var foodGroup: String = ""
    var isDefault: Bool = false
    var displayOrder: Int = 0
    var isHidden: Bool = false

    @Relationship(deleteRule: .nullify, inverse: \FoodItem.foodGroup)
    var foods: [FoodItem]? = []

    @Relationship(deleteRule: .nullify, inverse: \LoggedEntry.foodGroup)
    var logs: [LoggedEntry]? = []

    init(
        foodGroup: String,
        isDefault: Bool = false,
        displayOrder: Int,
        isHidden: Bool = false
    ) {
        self.foodGroup = foodGroup
        self.isDefault = isDefault
        self.displayOrder = displayOrder
        self.isHidden = isHidden
    }
}
