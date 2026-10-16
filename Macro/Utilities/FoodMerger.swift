//
//  FoodMerger.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/15/26.
//

import Foundation
import SwiftData

struct FoodMergePlan {
    struct Macros {
        var calories: Double
        var protein: Double
        var carbs: Double
        var fat: Double
        var fiber: Double

        func scaled(by factor: Double) -> Macros {
            Macros(
                calories: calories * factor,
                protein: protein * factor,
                carbs: carbs * factor,
                fat: fat * factor,
                fiber: fiber * factor
            )
        }
    }

    var kept: FoodItem
    var foods: [FoodItem]
    var name: String
    var source: String
    var category: String
    var foodGroup: String
    var defaultLocation: EntryLocation?
    var stickyNote: String
    var servingSize: Double
    var servingUnit: String
    var defaultPortionOverride: Double?
    var unitsPerServing: [UUID: Double]
    var recalculateLogs: Bool

    var removed: [FoodItem] {
        foods.filter { $0.id != kept.id }
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isValid: Bool {
        servingSize > 0 && !trimmedName.isEmpty
            && foods.allSatisfy { (unitsPerServing[$0.id] ?? 0) > 0 }
    }

    private var keptUnits: Double? {
        guard let units = unitsPerServing[kept.id], units > 0 else { return nil }
        return units
    }

    var perUnitMacros: Macros? {
        guard let keptUnits else { return nil }
        return Macros(
            calories: kept.calories,
            protein: kept.protein,
            carbs: kept.carbs,
            fat: kept.fat,
            fiber: kept.fiber
        )
        .scaled(by: 1 / keptUnits)
    }

    var servingMacros: Macros? {
        perUnitMacros?.scaled(by: servingSize)
    }

    var servingWeight: Double? {
        guard let weight = kept.servingWeight, let keptUnits else { return nil }
        return weight / keptUnits * servingSize
    }

    var keptDefaultPortion: Double? {
        guard let keptUnits, kept.servingSize > 0 else { return nil }
        return EntryHelper.defaultPortion(for: kept) / kept.servingSize * keptUnits
    }

    var defaultPortion: Double? {
        defaultPortionOverride ?? keptDefaultPortion
    }

    var hasCustomDefaultPortion: Bool {
        guard let defaultPortion, defaultPortion > 0 else { return false }
        return abs(defaultPortion - servingSize) > 0.0001
    }

    private func keepsWeight(_ unit: String, of food: FoodItem) -> Bool {
        unit == food.servingWeightUnit && food.servingWeight != nil
            && unit != food.servingUnit?.unit
            && servingWeight != nil && kept.servingWeightUnit == food.servingWeightUnit
    }

    func convertedPortion(
        quantity: Double,
        unit: String,
        of food: FoodItem
    ) -> (quantity: Double, unit: String)? {
        if keepsWeight(unit, of: food) { return (quantity, unit) }
        let isWeight = unit == food.servingWeightUnit && food.servingWeight != nil
        guard unit == (food.servingUnit?.unit ?? "serving") || isWeight,
            let units = unitsPerServing[food.id],
            let multiplier = EntryHelper.portionMultiplier(
                quantity: quantity,
                unit: unit,
                servingSize: food.servingSize,
                servingWeight: food.servingWeight,
                servingWeightUnit: food.servingWeightUnit
            )
        else { return nil }
        return (multiplier * units, servingUnit)
    }

    func macros(forQuantity quantity: Double, unit: String) -> Macros? {
        guard let servingMacros,
            let multiplier = EntryHelper.portionMultiplier(
                quantity: quantity,
                unit: unit,
                servingSize: servingSize,
                servingWeight: servingWeight,
                servingWeightUnit: kept.servingWeightUnit
            )
        else { return nil }
        return servingMacros.scaled(by: multiplier)
    }

    func canRecalculate(_ log: LoggedEntry) -> Bool {
        log.parentEntry == nil && !log.isManualOverride
    }

    func shouldRecalculate(_ log: LoggedEntry) -> Bool {
        recalculateLogs && canRecalculate(log)
    }

    func recalculatedMacros(for log: LoggedEntry, of food: FoodItem) -> Macros? {
        guard canRecalculate(log),
            let portion = convertedPortion(quantity: log.loggedQuantity, unit: log.loggedUnit, of: food)
        else { return nil }
        return macros(forQuantity: portion.quantity, unit: portion.unit)
    }
}

struct FoodMergeRecord {
    struct LogState {
        let id: UUID
        let foodID: UUID
        let name: String
        let quantity: Double
        let unit: String
        let calories: Double
        let protein: Double
        let carbs: Double
        let fat: Double
        let fiber: Double
    }

    struct IngredientState {
        let id: UUID
        let foodID: UUID
        let name: String
        let quantity: Double
        let unit: String
        let baseServingSize: Double
        let baseServingUnitName: String?
    }

    struct DraftState {
        let id: UUID
        let foodID: UUID?
        let name: String
        let payload: Data
        let updatedAt: Date
    }

    let mergedName: String
    let keptID: UUID
    let kept: MacroBackup.FoodRecord
    let keptWasFavorite: Bool
    let removed: [MacroBackup.FoodRecord]
    let removedFavoriteOrders: [UUID: Int]
    let reassignedFavoriteFrom: UUID?
    let logs: [LogState]
    let ingredients: [IngredientState]
    let drafts: [DraftState]
}

enum FoodMergeError: Error {
    case keptFoodMissing
}

@MainActor
enum FoodMerger {
    static func merge(_ plan: FoodMergePlan, in context: ModelContext) throws -> FoodMergeRecord? {
        guard plan.isValid, let servingMacros = plan.servingMacros else { return nil }
        let kept = plan.kept

        let keptRecord = MacroBackup.foodRecord(kept)
        let removedRecords = plan.removed.map(MacroBackup.foodRecord)
        let keptWasFavorite = kept.favoriteEntry != nil
        var removedFavoriteOrders: [UUID: Int] = [:]
        for food in plan.removed {
            if let order = food.favoriteEntry?.orderIndex {
                removedFavoriteOrders[food.id] = order
            }
        }

        var logStates: [FoodMergeRecord.LogState] = []
        var ingredientStates: [FoodMergeRecord.IngredientState] = []
        var draftStates: [FoodMergeRecord.DraftState] = []

        let logsByFood = Dictionary(
            uniqueKeysWithValues: plan.foods.map {
                ($0.id, FoodItemStore.loggedEntries(for: $0, in: context))
            }
        )
        let ingredientsByFood = Dictionary(
            uniqueKeysWithValues: plan.foods.map {
                ($0.id, FoodItemStore.recipeIngredients(using: $0, in: context))
            }
        )
        let draftsByFood = Dictionary(
            uniqueKeysWithValues: plan.foods.map { ($0.id, $0.drafts ?? []) }
        )

        for food in plan.foods {
            for log in logsByFood[food.id] ?? [] {
                logStates.append(
                    FoodMergeRecord.LogState(
                        id: log.id,
                        foodID: food.id,
                        name: log.name,
                        quantity: log.loggedQuantity,
                        unit: log.loggedUnit,
                        calories: log.calories,
                        protein: log.protein,
                        carbs: log.carbs,
                        fat: log.fat,
                        fiber: log.fiber
                    )
                )
                if let portion = plan.convertedPortion(
                    quantity: log.loggedQuantity,
                    unit: log.loggedUnit,
                    of: food
                ) {
                    log.loggedQuantity = portion.quantity
                    log.loggedUnit = portion.unit
                    if plan.shouldRecalculate(log),
                        let macros = plan.macros(forQuantity: portion.quantity, unit: portion.unit)
                    {
                        log.calories = macros.calories
                        log.protein = macros.protein
                        log.carbs = macros.carbs
                        log.fat = macros.fat
                        log.fiber = macros.fiber
                    }
                }
                log.name = plan.trimmedName
                log.originalFoodItem = kept
            }

            for ingredient in ingredientsByFood[food.id] ?? [] {
                ingredientStates.append(
                    FoodMergeRecord.IngredientState(
                        id: ingredient.id,
                        foodID: food.id,
                        name: ingredient.name,
                        quantity: ingredient.quantity,
                        unit: ingredient.unit,
                        baseServingSize: ingredient.baseServingSize,
                        baseServingUnitName: ingredient.baseServingUnitName
                    )
                )
                if let converted = convertedIngredient(
                    quantity: ingredient.quantity,
                    unit: ingredient.unit,
                    baseServingSize: ingredient.baseServingSize,
                    baseServingUnitName: ingredient.baseServingUnitName,
                    baseServingWeightUnit: ingredient.baseServingWeightUnit,
                    of: food,
                    plan: plan
                ) {
                    ingredient.quantity = converted.quantity
                    ingredient.unit = converted.unit
                    ingredient.baseServingSize = converted.baseServingSize
                    ingredient.baseServingUnitName = plan.servingUnit
                }
                ingredient.name = plan.trimmedName
                ingredient.ingredientItem = kept
            }

            let drafts = draftsByFood[food.id] ?? []
            if food.id != kept.id {
                food.drafts = []
            }
            for draft in drafts {
                draftStates.append(
                    FoodMergeRecord.DraftState(
                        id: draft.id,
                        foodID: food.id,
                        name: draft.name,
                        payload: draft.payload,
                        updatedAt: draft.updatedAt
                    )
                )
                if draft.kind == .logFood,
                    var state = draft.decodeState(LogEntryDraftState.self)
                {
                    if let quantity = Double(state.portionQuantity),
                        let portion = plan.convertedPortion(
                            quantity: quantity,
                            unit: state.portionUnitSelection,
                            of: food
                        )
                    {
                        state.portionQuantity = EntryHelper.format(portion.quantity)
                        state.portionUnitSelection = portion.unit
                    }
                    state.name = plan.trimmedName
                    if let data = try? JSONEncoder().encode(state) {
                        draft.payload = data
                    }
                }
                draft.name = plan.trimmedName
                draft.foodItem = kept
            }
        }

        let foodsByID = Dictionary(uniqueKeysWithValues: plan.foods.map { ($0.id, $0) })
        let recipeDrafts = (try? context.fetch(FetchDescriptor<EntryDraft>())) ?? []
        for draft in recipeDrafts where draft.kind == .logRecipe || draft.kind == .addRecipe {
            let original = state(of: draft)
            let changed: Bool
            if draft.kind == .logRecipe, var state = draft.decodeState(LogRecipeDraftState.self) {
                changed = convertSnapshots(&state.ingredients, foodsByID: foodsByID, plan: plan)
                if changed, let data = try? JSONEncoder().encode(state) { draft.payload = data }
            } else if var state = draft.decodeState(AddRecipeDraftState.self) {
                changed = convertSnapshots(&state.ingredients, foodsByID: foodsByID, plan: plan)
                if changed, let data = try? JSONEncoder().encode(state) { draft.payload = data }
            } else {
                changed = false
            }
            if changed && !draftStates.contains(where: { $0.id == draft.id }) {
                draftStates.append(original)
            }
        }

        var reassignedFavoriteFrom: UUID?
        if !keptWasFavorite,
            let first = removedFavoriteOrders.min(by: { $0.value < $1.value }),
            let source = foodsByID[first.key],
            let favorite = source.favoriteEntry
        {
            source.favoriteEntry = nil
            favorite.foodItem = kept
            reassignedFavoriteFrom = first.key
        }

        let relationships = RecordRelationships.resolving(in: context)
        kept.name = plan.trimmedName
        kept.source = relationships.source(plan.source)
        switch kept.type {
        case .food:
            kept.category = relationships.category(plan.category)
        case .ingredient:
            kept.foodGroup = relationships.foodGroup(plan.foodGroup)
        case .drink, .recipe:
            break
        }
        kept.defaultLocation = plan.defaultLocation
        let note = plan.stickyNote.trimmingCharacters(in: .whitespacesAndNewlines)
        if note.isEmpty {
            if let existing = kept.stickyNote {
                context.delete(existing)
            }
            kept.stickyNote = nil
        } else if let existing = kept.stickyNote {
            if existing.text != note {
                existing.text = note
                existing.lastUpdated = Date()
            }
        } else {
            kept.stickyNote = Note(text: note)
        }
        kept.servingSize = plan.servingSize
        kept.servingUnit = relationships.unit(plan.servingUnit)
        kept.servingWeight = plan.servingWeight
        kept.isCustomDefaultServing = plan.hasCustomDefaultPortion
        kept.customServingSize = plan.hasCustomDefaultPortion ? plan.defaultPortion : nil
        kept.calories = servingMacros.calories
        kept.protein = servingMacros.protein
        kept.carbs = servingMacros.carbs
        kept.fat = servingMacros.fat
        kept.fiber = servingMacros.fiber
        kept.dateAdded = plan.foods.map(\.dateAdded).min() ?? kept.dateAdded

        for food in plan.removed {
            context.delete(food)
        }

        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }

        return FoodMergeRecord(
            mergedName: plan.trimmedName,
            keptID: kept.id,
            kept: keptRecord,
            keptWasFavorite: keptWasFavorite,
            removed: removedRecords,
            removedFavoriteOrders: removedFavoriteOrders,
            reassignedFavoriteFrom: reassignedFavoriteFrom,
            logs: logStates,
            ingredients: ingredientStates,
            drafts: draftStates
        )
    }

    static func restore(_ record: FoodMergeRecord, in context: ModelContext) throws {
        let relationships = RecordRelationships.resolving(in: context)
        guard let kept = relationships.food(record.keptID) else {
            throw FoodMergeError.keptFoodMissing
        }

        var foodsByID: [UUID: FoodItem] = [kept.id: kept]
        for removed in record.removed {
            foodsByID[removed.id] = removed.insert(relationships: relationships, in: context)
        }

        record.kept.apply(to: kept, relationships: relationships, in: context)

        if let fromID = record.reassignedFavoriteFrom,
            let favorite = kept.favoriteEntry,
            let original = foodsByID[fromID]
        {
            kept.favoriteEntry = nil
            favorite.foodItem = original
        }
        for (foodID, order) in record.removedFavoriteOrders where foodID != record.reassignedFavoriteFrom {
            if let food = foodsByID[foodID] {
                FoodItemStore.insertFavorite(food, at: order, in: context)
            }
        }

        let logIDs = record.logs.map(\.id)
        let logs = (try? context.fetch(
            FetchDescriptor<LoggedEntry>(predicate: #Predicate { logIDs.contains($0.id) })
        )) ?? []
        let logStates = Dictionary(uniqueKeysWithValues: record.logs.map { ($0.id, $0) })
        for log in logs {
            guard let state = logStates[log.id] else { continue }
            log.name = state.name
            log.loggedQuantity = state.quantity
            log.loggedUnit = state.unit
            log.calories = state.calories
            log.protein = state.protein
            log.carbs = state.carbs
            log.fat = state.fat
            log.fiber = state.fiber
            log.originalFoodItem = foodsByID[state.foodID]
        }

        let ingredientIDs = record.ingredients.map(\.id)
        let ingredients = (try? context.fetch(
            FetchDescriptor<RecipeIngredient>(predicate: #Predicate { ingredientIDs.contains($0.id) })
        )) ?? []
        let ingredientStates = Dictionary(uniqueKeysWithValues: record.ingredients.map { ($0.id, $0) })
        for ingredient in ingredients {
            guard let state = ingredientStates[ingredient.id] else { continue }
            ingredient.name = state.name
            ingredient.quantity = state.quantity
            ingredient.unit = state.unit
            ingredient.baseServingSize = state.baseServingSize
            ingredient.baseServingUnitName = state.baseServingUnitName
            ingredient.ingredientItem = foodsByID[state.foodID]
        }

        let draftIDs = record.drafts.map(\.id)
        let drafts = (try? context.fetch(
            FetchDescriptor<EntryDraft>(predicate: #Predicate { draftIDs.contains($0.id) })
        )) ?? []
        let draftStates = Dictionary(uniqueKeysWithValues: record.drafts.map { ($0.id, $0) })
        for draft in drafts {
            guard let state = draftStates[draft.id] else { continue }
            draft.name = state.name
            draft.payload = state.payload
            draft.updatedAt = state.updatedAt
            draft.foodItem = state.foodID.flatMap { foodsByID[$0] ?? relationships.food($0) }
        }

        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func state(of draft: EntryDraft) -> FoodMergeRecord.DraftState {
        FoodMergeRecord.DraftState(
            id: draft.id,
            foodID: draft.foodItem?.id,
            name: draft.name,
            payload: draft.payload,
            updatedAt: draft.updatedAt
        )
    }

    private static func convertedIngredient(
        quantity: Double,
        unit: String,
        baseServingSize: Double,
        baseServingUnitName: String?,
        baseServingWeightUnit: String,
        of food: FoodItem,
        plan: FoodMergePlan
    ) -> (quantity: Double, unit: String, baseServingSize: Double)? {
        let foodUnit = food.servingUnit?.unit ?? "serving"
        guard (baseServingUnitName ?? "serving") == foodUnit, food.servingSize > 0,
            let units = plan.unitsPerServing[food.id]
        else { return nil }
        let scale = units / food.servingSize
        let newBase = baseServingSize * scale
        if unit == foodUnit {
            return (quantity * scale, plan.servingUnit, newBase)
        }
        if unit == baseServingWeightUnit {
            return (quantity, unit, newBase)
        }
        return nil
    }

    private static func convertSnapshots(
        _ snapshots: inout [DraftIngredientSnapshot],
        foodsByID: [UUID: FoodItem],
        plan: FoodMergePlan
    ) -> Bool {
        var changed = false
        for index in snapshots.indices {
            guard let id = snapshots[index].foodItemID, let food = foodsByID[id] else { continue }
            var snapshot = snapshots[index]
            if let converted = convertedIngredient(
                quantity: Double(snapshot.quantity) ?? 0,
                unit: snapshot.unit,
                baseServingSize: snapshot.baseServingSize,
                baseServingUnitName: snapshot.baseServingUnitName,
                baseServingWeightUnit: snapshot.baseServingWeightUnit,
                of: food,
                plan: plan
            ) {
                if Double(snapshot.quantity) != nil {
                    snapshot.quantity = EntryHelper.format(converted.quantity)
                }
                snapshot.unit = converted.unit
                snapshot.baseServingSize = converted.baseServingSize
                snapshot.baseServingUnitName = plan.servingUnit
            }
            snapshot.foodItemID = plan.kept.id
            snapshot.name = plan.trimmedName
            snapshots[index] = snapshot
            changed = true
        }
        return changed
    }
}
