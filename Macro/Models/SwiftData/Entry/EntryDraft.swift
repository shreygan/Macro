//
//  EntryDraft.swift
//  Macro
//
//  Created by Shrey Gangwar on 9/28/26.
//

import Foundation
import SwiftData

enum DraftKind: String, Codable, CaseIterable {
    case logFood
    case logRecipe
    case addFood
    case addRecipe

    var isLog: Bool { self == .logFood || self == .logRecipe }
}

@Model
class EntryDraft {
    @Attribute(.unique) var id: UUID

    var kindRawValue: String
    var typeRawValue: String
    var name: String

    // Log drafts only: when the food was eaten
    var timestamp: Date?

    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .nullify)
    var foodItem: FoodItem?

    @Relationship(deleteRule: .cascade, inverse: \EntryPhoto.parentDraft)
    var photos: [EntryPhoto]? = []

    var payload: Data

    init(
        id: UUID = UUID(),
        kind: DraftKind,
        type: EntryType,
        name: String,
        timestamp: Date? = nil,
        foodItem: FoodItem? = nil,
        payload: Data = Data(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kindRawValue = kind.rawValue
        self.typeRawValue = type.rawValue
        self.name = name
        self.timestamp = timestamp
        self.foodItem = foodItem
        self.payload = payload
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    var kind: DraftKind? {
        get { DraftKind(rawValue: kindRawValue) }
        set { kindRawValue = newValue?.rawValue ?? "" }
    }

    var entryType: EntryType? {
        get { EntryType(rawValue: typeRawValue) }
        set { typeRawValue = newValue?.rawValue ?? "" }
    }

    var isAvailable: Bool {
        !isDeleted && modelContext != nil
    }

    static var logDraftsPredicate: Predicate<EntryDraft> {
        let logFood = DraftKind.logFood.rawValue
        let logRecipe = DraftKind.logRecipe.rawValue
        return #Predicate<EntryDraft> {
            $0.kindRawValue == logFood || $0.kindRawValue == logRecipe
        }
    }

    func decodeState<State: Decodable>(_ type: State.Type) -> State? {
        try? JSONDecoder().decode(type, from: payload)
    }

    func encodeState<State: Encodable>(_ state: State) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        payload = data
        updatedAt = Date()
    }
}
