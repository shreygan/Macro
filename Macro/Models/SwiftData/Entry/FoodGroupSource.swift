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
    @Attribute(.unique) var foodGroup: String
    var isDefault: Bool
    var displayOrder: Int
    var isHidden: Bool = false

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
