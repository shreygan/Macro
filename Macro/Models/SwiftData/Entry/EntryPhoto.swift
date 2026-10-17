//
//  EntryPhoto.swift
//  Macro
//
//  Created by Shrey Gangwar on 7/26/26.
//

import Foundation
import SwiftData

@Model
nonisolated class EntryPhoto {
    @Attribute(.externalStorage) var imageData: Data = Data()

    var scale: Double = 1.0
    var offsetX: Double = 0.0
    var offsetY: Double = 0.0

    var displayOrder: Int = 0

    var parentEntry: LoggedEntry?
    var parentDraft: EntryDraft?

    init(
        imageData: Data,
        scale: Double = 1.0,
        offsetX: Double = 0.0,
        offsetY: Double = 0.0,
        displayOrder: Int = 0
    ) {
        self.imageData = imageData
        self.scale = scale
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.displayOrder = displayOrder
    }
}
