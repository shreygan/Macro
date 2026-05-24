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

    init(source: String, isDefault: Bool = false, displayOrder: Int) {
        self.source = source
        self.isDefault = isDefault
        self.displayOrder = displayOrder
    }
}
