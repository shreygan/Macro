//
//  QuickLogger.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/8/26.
//

import Foundation
import SwiftData

struct LogUndoRecord {
    let entry: LoggedEntry
    var originalFood: MacroBackup.FoodRecord? = nil
    var createdFood: FoodItem? = nil
    var createdListItems: [any PersistentModel] = []
    var draft: MacroBackup.DraftRecord? = nil
}

enum QuickLogger {
    @discardableResult
    static func log(
        _ food: FoodItem,
        at timestamp: Date = .now,
        location: EntryLocation? = nil,
        in context: ModelContext
    ) throws -> LoggedEntry {
        let savedLocation = SavedLocation.find(id: location?.savedLocationID, in: context)
        let entry =
            food.type == .recipe
            ? logRecipe(
                food,
                at: timestamp,
                location: location,
                savedLocation: savedLocation,
                in: context
            )
            : logFood(
                food,
                at: timestamp,
                location: location,
                savedLocation: savedLocation,
                in: context
            )
        RecentLocationStore.record(location, usedAt: timestamp, in: context)

        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return entry
    }

    static func readyLocation(for food: FoodItem, in context: ModelContext) -> EntryLocation? {
        if let location = food.defaultLocation {
            return DefaultLocationResolver.resolved(location, in: context)
        }
        let manager = LocationManager.shared
        guard manager.isAuthorized, let fix = manager.freshLocation else { return nil }
        if !manager.isReducedAccuracy, let saved = SavedLocation.nearest(to: fix, in: context) {
            return saved.entryLocation
        }
        return LocationSelection.current(nil).resolvedLocation
    }

    static func finishLocation(
        of entry: LoggedEntry,
        awaitingCurrent: Bool,
        replacing previous: EntryLocation? = nil,
        in context: ModelContext
    ) {
        if awaitingCurrent {
            Task { await attachLocation(to: entry, replacing: previous, in: context) }
        } else if entry.needsLocationName {
            Task { await PendingLocationNamer.run(in: context) }
        }
    }

    static func attachLocation(
        to entry: LoggedEntry,
        replacing previous: EntryLocation? = nil,
        in context: ModelContext
    ) async {
        guard LocationManager.shared.isAuthorized else { return }
        let saved = (try? context.fetch(FetchDescriptor<SavedLocation>())) ?? []
        let place = await LocationManager.shared.currentPlace(matching: saved)
        guard let place, entry.modelContext != nil, !entry.isDeleted,
            entry.storedLocation == previous
        else { return }

        apply(place, to: entry, in: context)
        RecentLocationStore.record(place, usedAt: entry.timestamp, in: context)
        do {
            try context.save()
        } catch {
            context.rollback()
            return
        }

        if place.needsName {
            await PendingLocationNamer.run(in: context)
        }
    }

    private static func apply(
        _ location: EntryLocation,
        to entry: LoggedEntry,
        in context: ModelContext
    ) {
        entry.setLocation(location, in: context)
        for child in entry.childEntries ?? [] {
            child.setLocation(location, in: context)
        }
    }

    @MainActor
    static func undo(_ record: LogUndoRecord, in context: ModelContext) throws {
        let entry = record.entry
        guard entry.modelContext != nil, !entry.isDeleted else { return }
        context.delete(entry)

        if let createdFood = record.createdFood,
            createdFood.modelContext != nil, !createdFood.isDeleted
        {
            context.delete(createdFood)
        }

        let relationships = RecordRelationships.resolving(in: context)
        if let original = record.originalFood,
            let food = relationships.food(original.id)
        {
            original.apply(to: food, relationships: relationships, in: context)
        }

        for item in record.createdListItems
        where item.modelContext != nil && !item.isDeleted {
            context.delete(item)
        }

        if let draft = record.draft {
            draft.insert(
                foodItem: draft.foodItemID.flatMap(relationships.food),
                in: context
            )
        }

        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func logFood(
        _ food: FoodItem,
        at timestamp: Date,
        location: EntryLocation?,
        savedLocation: SavedLocation?,
        in context: ModelContext
    ) -> LoggedEntry {
        let multiplier = EntryHelper.defaultPortionMultiplier(for: food)

        let entry = LoggedEntry(
            name: food.name,
            typeRawValue: food.type.rawValue,
            originalFoodItem: food,
            source: food.source,
            category: food.category,
            foodGroup: food.foodGroup,
            timestamp: timestamp,
            location: location,
            savedLocation: savedLocation,
            loggedQuantity: EntryHelper.defaultPortion(for: food),
            loggedUnit: food.servingUnit?.unit ?? "serving",
            calories: food.calories * multiplier,
            protein: food.protein * multiplier,
            carbs: food.carbs * multiplier,
            fat: food.fat * multiplier,
            fiber: food.fiber * multiplier
        )
        context.insert(entry)
        entry.snapshotDrinkAmounts(children: [])
        return entry
    }

    private static func logRecipe(
        _ recipe: FoodItem,
        at timestamp: Date,
        location: EntryLocation?,
        savedLocation: SavedLocation?,
        in context: ModelContext
    ) -> LoggedEntry {
        let multiplier = EntryHelper.defaultPortionMultiplier(for: recipe)
        let ingredients = (recipe.recipeIngredients ?? [])
            .sorted { $0.displayOrder < $1.displayOrder }
            .map(LogRecipeIngredient.init(recipeIngredient:))

        let entry = LoggedEntry(
            name: recipe.name,
            typeRawValue: recipe.type.rawValue,
            originalFoodItem: recipe,
            source: recipe.source,
            category: recipe.category,
            timestamp: timestamp,
            location: location,
            savedLocation: savedLocation,
            loggedQuantity: EntryHelper.defaultPortion(for: recipe),
            loggedUnit: recipe.servingUnit?.unit ?? "serving",
            calories: ingredients.reduce(0) { $0 + $1.activeCalories } * multiplier,
            protein: ingredients.reduce(0) { $0 + $1.activeProtein } * multiplier,
            carbs: ingredients.reduce(0) { $0 + $1.activeCarbs } * multiplier,
            fat: ingredients.reduce(0) { $0 + $1.activeFat } * multiplier,
            fiber: ingredients.reduce(0) { $0 + $1.activeFiber } * multiplier
        )
        context.insert(entry)

        var children: [LoggedEntry] = []
        for (index, ingredient) in ingredients.enumerated() {
            let child = LoggedEntry(
                name: ingredient.name,
                typeRawValue: "ingredient",
                originalFoodItem: ingredient.ingredientItem,
                parentEntry: entry,
                timestamp: timestamp,
                location: location,
                savedLocation: savedLocation,
                loggedQuantity: (Double(ingredient.quantity) ?? 0) * multiplier,
                loggedUnit: ingredient.unit,
                calories: ingredient.activeCalories * multiplier,
                protein: ingredient.activeProtein * multiplier,
                carbs: ingredient.activeCarbs * multiplier,
                fat: ingredient.activeFat * multiplier,
                fiber: ingredient.activeFiber * multiplier,
                displayOrder: index
            )
            context.insert(child)
            children.append(child)
        }
        entry.snapshotDrinkAmounts(children: children)

        return entry
    }
}
