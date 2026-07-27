//
//  LoggedEntry.swift
//  Macro
//
//  Created by Shrey Gangwar on 7/22/26.
//

import Foundation
import SwiftData

@Model
class LoggedEntry {
    @Attribute(.unique) var id: UUID

    var name: String
    var typeRawValue: String

    @Relationship(deleteRule: .nullify)
    var originalFoodItem: FoodItem?

    @Relationship(deleteRule: .cascade, inverse: \LoggedEntry.parentEntry)
    var childEntries: [LoggedEntry]? = []

    var parentEntry: LoggedEntry?

    var timestamp: Date
    var location: String?

    var loggedQuantity: Double
    var loggedUnit: String

    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double

    var isManualOverride: Bool

    var logNote: String?

    @Relationship(deleteRule: .cascade, inverse: \EntryPhoto.parentEntry)
    var photos: [EntryPhoto]? = []

    init(
        id: UUID = UUID(),
        name: String,
        typeRawValue: String,
        originalFoodItem: FoodItem? = nil,
        parentEntry: LoggedEntry? = nil,
        timestamp: Date = Date(),
        location: String? = nil,
        loggedQuantity: Double,
        loggedUnit: String,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        fiber: Double,
        isManualOverride: Bool = false,
        logNote: String? = nil,
        photos: [EntryPhoto]? = nil
    ) {
        self.id = id
        self.name = name
        self.typeRawValue = typeRawValue
        self.originalFoodItem = originalFoodItem
        self.parentEntry = parentEntry
        self.timestamp = timestamp
        self.location = location
        self.loggedQuantity = loggedQuantity
        self.loggedUnit = loggedUnit
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.isManualOverride = isManualOverride
        self.logNote = logNote
        self.photos = photos
    }

    var entryType: EntryType? {
        get { EntryType(rawValue: typeRawValue) }
        set { typeRawValue = newValue?.rawValue ?? "" }
    }
}
