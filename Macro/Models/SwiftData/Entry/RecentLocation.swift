//
//  RecentLocation.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/12/26.
//

import Foundation
import SwiftData

@Model
class RecentLocation {
    @Attribute(.unique) var id: UUID
    var location: EntryLocation
    var lastUsed: Date

    init(
        id: UUID = UUID(),
        location: EntryLocation,
        lastUsed: Date = Date()
    ) {
        self.id = id
        self.location = location
        self.lastUsed = lastUsed
    }
}
