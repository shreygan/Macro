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
    @Attribute(.unique) var source: String
    var isDefault: Bool
    var displayOrder: Int
    var isHidden: Bool = false

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
