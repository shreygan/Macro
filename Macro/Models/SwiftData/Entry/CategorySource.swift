//
//  CategorySource.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/10/26.
//

import Foundation
import SwiftData

@Model
class CategorySource {
    var id: UUID = UUID()
    var category: String = ""
    var isDefault: Bool = false
    var displayOrder: Int = 0
    var isHidden: Bool = false

    @Relationship(deleteRule: .nullify, inverse: \FoodItem.category)
    var foods: [FoodItem]? = []

    @Relationship(deleteRule: .nullify, inverse: \LoggedEntry.category)
    var logs: [LoggedEntry]? = []

    init(
        category: String,
        isDefault: Bool = false,
        displayOrder: Int,
        isHidden: Bool = false
    ) {
        self.category = category
        self.isDefault = isDefault
        self.displayOrder = displayOrder
        self.isHidden = isHidden
    }
}
