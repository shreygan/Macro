//
//  EntryPhoto.swift
//  Macro
//
//  Created by Shrey Gangwar on 7/26/26.
//

import Foundation
import SwiftData

@Model
class EntryPhoto {
    @Attribute(.externalStorage) var imageData: Data

    var scale: Double
    var offsetX: Double
    var offsetY: Double

    var parentEntry: LoggedEntry?

    init(
        imageData: Data,
        scale: Double = 1.0,
        offsetX: Double = 0.0,
        offsetY: Double = 0.0
    ) {
        self.imageData = imageData
        self.scale = scale
        self.offsetX = offsetX
        self.offsetY = offsetY
    }
}
