//
//  EntrySource.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/10/26.
//

import Foundation
import SwiftData

@Model
class EntrySource {
    var id: UUID = UUID()
    var source: String = ""
    var isDefault: Bool = false
    var displayOrder: Int = 0
    var isHidden: Bool = false

    @Relationship(deleteRule: .nullify, inverse: \FoodItem.source)
    var foods: [FoodItem]? = []

    @Relationship(deleteRule: .nullify, inverse: \LoggedEntry.source)
    var logs: [LoggedEntry]? = []

    init(
        source: String,
        isDefault: Bool = false,
        displayOrder: Int,
        isHidden: Bool = false
    ) {
        self.source = source
        self.isDefault = isDefault
        self.displayOrder = displayOrder
        self.isHidden = isHidden
    }
}
