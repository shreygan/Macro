//
//  EntryDeleter.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/8/26.
//

import Foundation
import SwiftData

struct DeletedFoodRecord {
    let food: MacroBackup.FoodRecord
    let favoriteOrder: Int?
    let drafts: [MacroBackup.DraftRecord]
    let deletedLogs: [MacroBackup.LogRecord]
    let unlinkedLogIDs: [UUID]
    let unlinkedIngredientIDs: [UUID]
}

enum EntryDeleter {
    @discardableResult
    static func delete(
        _ entry: LoggedEntry,
        in context: ModelContext
    ) throws -> MacroBackup.LogRecord? {
        guard entry.modelContext != nil, !entry.isDeleted else { return nil }
        let record = MacroBackup.logRecord(entry)
        context.delete(entry)
        do {
            try context.save()
            return record
        } catch {
            context.rollback()
            throw error
        }
    }

    static func restore(_ record: MacroBackup.LogRecord, in context: ModelContext) throws {
        record.insert(relationships: .resolving(in: context), in: context)
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    @discardableResult
    static func delete(
        _ draft: EntryDraft,
        in context: ModelContext
    ) throws -> MacroBackup.DraftRecord? {
        guard draft.modelContext != nil, !draft.isDeleted else { return nil }
        let record = MacroBackup.draftRecord(draft)
        context.delete(draft)
        do {
            try context.save()
            return record
        } catch {
            context.rollback()
            throw error
        }
    }

    @MainActor
    @discardableResult
    static func deleteDraft(
        id: UUID,
        in context: ModelContext
    ) throws -> MacroBackup.DraftRecord? {
        guard let draft = DraftStore.fetch(id: id, in: context) else { return nil }
        return try delete(draft, in: context)
    }

    static func restore(_ record: MacroBackup.DraftRecord, in context: ModelContext) throws {
        let food = record.foodItemID.flatMap(RecordRelationships.resolving(in: context).food)
        record.insert(foodItem: food, in: context)
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    @MainActor
    @discardableResult
    static func delete(
        _ food: FoodItem,
        deletingLogs: Bool,
        in context: ModelContext
    ) throws -> DeletedFoodRecord? {
        guard food.modelContext != nil, !food.isDeleted else { return nil }

        let foodRecord = MacroBackup.foodRecord(food)
        let favoriteOrder = food.favoriteEntry?.orderIndex
        let drafts = (food.drafts ?? []).map(MacroBackup.draftRecord)

        var deletedLogs: [MacroBackup.LogRecord] = []
        var unlinkedLogIDs: [UUID] = []
        for entry in FoodItemStore.loggedEntries(for: food, in: context) {
            if deletingLogs && entry.parentEntry == nil {
                deletedLogs.append(MacroBackup.logRecord(entry))
                context.delete(entry)
            } else {
                unlinkedLogIDs.append(entry.id)
                entry.originalFoodItem = nil
            }
        }

        let ingredients = FoodItemStore.recipeIngredients(using: food, in: context)
        for ingredient in ingredients {
            ingredient.ingredientItem = nil
        }

        context.delete(food)

        do {
            try context.save()
            return DeletedFoodRecord(
                food: foodRecord,
                favoriteOrder: favoriteOrder,
                drafts: drafts,
                deletedLogs: deletedLogs,
                unlinkedLogIDs: unlinkedLogIDs,
                unlinkedIngredientIDs: ingredients.map(\.id)
            )
        } catch {
            context.rollback()
            throw error
        }
    }

    @MainActor
    static func restore(_ record: DeletedFoodRecord, in context: ModelContext) throws {
        let resolved = RecordRelationships.resolving(in: context)
        let food = record.food.insert(relationships: resolved, in: context)

        var relationships = resolved
        relationships.food = { $0 == food.id ? food : resolved.food($0) }
        record.food.insertIngredients(into: food, relationships: relationships, in: context)

        if let favoriteOrder = record.favoriteOrder {
            FoodItemStore.insertFavorite(food, at: favoriteOrder, in: context)
        }

        for draft in record.drafts {
            draft.insert(foodItem: food, in: context)
        }

        for log in record.deletedLogs {
            log.insert(relationships: relationships, in: context)
        }

        let logIDs = record.unlinkedLogIDs
        let unlinkedLogs = FetchDescriptor<LoggedEntry>(
            predicate: #Predicate { logIDs.contains($0.id) }
        )
        for entry in (try? context.fetch(unlinkedLogs)) ?? [] {
            entry.originalFoodItem = food
        }

        let ingredientIDs = record.unlinkedIngredientIDs
        let unlinkedIngredients = FetchDescriptor<RecipeIngredient>(
            predicate: #Predicate { ingredientIDs.contains($0.id) }
        )
        for ingredient in (try? context.fetch(unlinkedIngredients)) ?? [] {
            ingredient.ingredientItem = food
        }

        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
