//
//  DraftStore.swift
//  Macro
//
//  Created by Shrey Gangwar on 9/28/26.
//

import Foundation
import SwiftData

@MainActor
enum DraftStore {
    static func fetch(id: UUID?, in context: ModelContext) -> EntryDraft? {
        guard let id else { return nil }
        var descriptor = FetchDescriptor<EntryDraft>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    @discardableResult
    static func upsert<State: Encodable>(
        id: UUID,
        kind: DraftKind,
        type: EntryType,
        name: String,
        timestamp: Date? = nil,
        foodItem: FoodItem? = nil,
        state: State,
        photos: [LoggedPhoto] = [],
        in context: ModelContext
    ) -> EntryDraft {
        let draft: EntryDraft
        if let existing = fetch(id: id, in: context) {
            draft = existing
        } else {
            draft = EntryDraft(id: id, kind: kind, type: type, name: name)
            context.insert(draft)
        }

        draft.kind = kind
        draft.entryType = type
        draft.name = name
        draft.timestamp = timestamp
        draft.foodItem = foodItem
        draft.encodeState(state)

        for photo in draft.photos ?? [] {
            context.delete(photo)
        }
        draft.photos = photos.enumerated().map { index, photo in
            EntryPhoto(
                imageData: photo.originalData,
                scale: Double(photo.scale),
                offsetX: Double(photo.offset.width),
                offsetY: Double(photo.offset.height),
                displayOrder: index
            )
        }

        do {
            try context.save()
        } catch {
            print("Failed to save draft: \(error.localizedDescription)")
        }

        return draft
    }

    static func foodItems(
        for snapshots: [DraftIngredientSnapshot],
        in context: ModelContext?
    ) -> [UUID: FoodItem] {
        let ids = snapshots.compactMap(\.foodItemID)
        guard let context, !ids.isEmpty else { return [:] }

        let descriptor = FetchDescriptor<FoodItem>(
            predicate: #Predicate { ids.contains($0.id) }
        )
        let items = (try? context.fetch(descriptor)) ?? []
        return Dictionary(
            items.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    static func delete(id: UUID?, in context: ModelContext, save: Bool = true) {
        guard let draft = fetch(id: id, in: context) else { return }
        context.delete(draft)

        guard save else { return }
        do {
            try context.save()
        } catch {
            print("Failed to delete draft: \(error.localizedDescription)")
        }
    }
}
