//
//  DraftLogEntry.swift
//  Macro
//
//  Created by Shrey Gangwar on 9/30/26.
//

import Foundation

struct DraftLogEntry: Identifiable, Equatable {
    let id = UUID()
    var importID: UUID?
    var foodID: UUID?
    var typeRawValue: String
    var name: String
    var source: String
    var category: String
    var foodGroup: String
    var timestamp: Date
    var location: String?
    var quantity: Double
    var unit: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double
    var isManualOverride: Bool
    var note: String?
    var displayOrder: Int
    var components: [DraftLogEntry] = []
    var duplicateOf: UUID?

    var entryType: EntryType? { EntryType(rawValue: typeRawValue) }
}
