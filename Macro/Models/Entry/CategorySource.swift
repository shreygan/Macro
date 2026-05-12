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
    @Attribute(.unique) var category: String
    var isDefault: Bool
    var displayOrder: Int

    init(category: String, isDefault: Bool = false, displayOrder: Int) {
        self.category = category
        self.isDefault = isDefault
        self.displayOrder = displayOrder
    }
}
