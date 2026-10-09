//
//  BackupRestorer.swift
//  Macro
//
//  Created by Shrey Gangwar on 9/30/26.
//

import Foundation
import SwiftData

enum BackupRestoreMode: String, CaseIterable {
    case merge = "Merge"
    case replace = "Replace All"
}

struct BackupRestoreSummary: Identifiable {
    let id = UUID()
    var foods = 0
    var recipes = 0
    var logs = 0
    var photos = 0
    var goals = 0
    var lists = 0
    var favorites = 0
    var drafts = 0
    var skippedExisting = 0

    var message: String? {
        let parts = [
            (foods, "entry", "entries"),
            (logs, "log", "logs"),
            (goals, "goal", "goals"),
            (photos, "photo", "photos"),
            (favorites, "favorite", "favorites"),
            (lists, "list item", "list items"),
            (drafts, "draft", "drafts"),
        ]
        .filter { $0.0 > 0 }
        .map { "\($0.0) \($0.0 == 1 ? $0.1 : $0.2)" }

        guard !parts.isEmpty else { return nil }
        guard parts.count > 3 else { return parts.joined(separator: " · ") }
        return (parts.prefix(2) + ["+\(parts.count - 2) more"]).joined(separator: " · ")
    }
}

enum BackupRestoreError: LocalizedError {
    case nothingChanged(Error)
    case recovered(Error)
    case unrecovered(Error, snapshotURL: URL)

    var snapshotURL: URL? {
        if case .unrecovered(_, let url) = self { return url }
        return nil
    }

    var errorDescription: String? {
        switch self {
        case .nothingChanged(let error):
            return "The backup couldn't be restored and your existing data was left in place. \(error.localizedDescription)"
        case .recovered(let error):
            return "The backup couldn't be restored, so your previous data was put back. \(error.localizedDescription)"
        case .unrecovered(let error, _):
            return "The backup couldn't be restored and your previous data couldn't be put back automatically. Save a copy of your previous data now, then restore it from Import › Full Backup. \(error.localizedDescription)"
        }
    }
}

@MainActor
struct BackupRestorer {
    let context: ModelContext

    func restore(_ backup: MacroBackup, mode: BackupRestoreMode) async throws
        -> BackupRestoreSummary
    {
        switch mode {
        case .merge:
            let summary = apply(backup, exact: false)
            try saveOrRollback()
            return summary
        case .replace:
            let snapshotURL = try await writeSnapshot()

            do {
                try eraseAll()
            } catch {
                try? FileManager.default.removeItem(at: snapshotURL)
                throw BackupRestoreError.nothingChanged(error)
            }

            do {
                let summary = apply(backup, exact: true)
                try context.save()
                try? AppSeeder.seedDefaults(into: context)
                try? FileManager.default.removeItem(at: snapshotURL)
                return summary
            } catch {
                context.rollback()

                do {
                    let data = try Data(contentsOf: snapshotURL)
                    let snapshot = try await Task.detached(priority: .userInitiated) {
                        try MacroBackup.decode(data)
                    }.value
                    _ = apply(snapshot, exact: true)
                    try context.save()
                    try? FileManager.default.removeItem(at: snapshotURL)
                    throw BackupRestoreError.recovered(error)
                } catch let restoreError as BackupRestoreError {
                    throw restoreError
                } catch {
                    context.rollback()
                    throw BackupRestoreError.unrecovered(error, snapshotURL: snapshotURL)
                }
            }
        }
    }

    private func writeSnapshot() async throws -> URL {
        let snapshot = try MacroBackup.make(from: context)
        let data = try await Task.detached(priority: .userInitiated) {
            try MacroBackup.encode(snapshot)
        }.value

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Macro Pre-Restore \(UUID().uuidString).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    private func saveOrRollback() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw BackupRestoreError.nothingChanged(error)
        }
    }

    private func eraseAll() throws {
        do {
            try context.eraseAllData()
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private func apply(_ backup: MacroBackup, exact: Bool) -> BackupRestoreSummary {
        var summary = BackupRestoreSummary()

        let sources = restoreList(
            backup.sources,
            name: \.name,
            isDefault: \.isDefault,
            order: \.displayOrder,
            existingName: { (item: EntrySource) in item.source },
            existingOrder: \.displayOrder,
            exact: exact,
            summary: &summary
        ) { record, order in
            EntrySource(
                source: record.name,
                isDefault: record.isDefault,
                displayOrder: order,
                isHidden: record.isHidden ?? false
            )
        }
        let categories = restoreList(
            backup.categories,
            name: \.name,
            isDefault: \.isDefault,
            order: \.displayOrder,
            existingName: { (item: CategorySource) in item.category },
            existingOrder: \.displayOrder,
            exact: exact,
            summary: &summary
        ) { record, order in
            CategorySource(
                category: record.name,
                isDefault: record.isDefault,
                displayOrder: order,
                isHidden: record.isHidden ?? false
            )
        }
        let foodGroups = restoreList(
            backup.foodGroups,
            name: \.name,
            isDefault: \.isDefault,
            order: \.displayOrder,
            existingName: { (item: FoodGroupSource) in item.foodGroup },
            existingOrder: \.displayOrder,
            exact: exact,
            summary: &summary
        ) { record, order in
            FoodGroupSource(
                foodGroup: record.name,
                isDefault: record.isDefault,
                displayOrder: order,
                isHidden: record.isHidden ?? false
            )
        }
        let units = restoreList(
            backup.servingUnits,
            name: \.unit,
            isDefault: \.isDefault,
            order: \.displayOrder,
            existingName: { (item: ServingSizeUnit) in item.unit },
            existingOrder: \.displayOrder,
            exact: exact,
            summary: &summary
        ) { record, order in
            ServingSizeUnit(
                unit: record.unit,
                pluralVariant: record.pluralVariant,
                isDefault: record.isDefault,
                displayOrder: order
            )
        }

        let resolver = ImportResolver(context: context)
        let sourceFor: (String?) -> EntrySource? = { name in
            guard let name, !name.isEmpty else { return nil }
            return sources[name] ?? resolver.source(name)
        }
        let categoryFor: (String?) -> CategorySource? = { name in
            guard let name, !name.isEmpty else { return nil }
            return categories[name] ?? resolver.category(name)
        }
        let foodGroupFor: (String?) -> FoodGroupSource? = { name in
            guard let name, !name.isEmpty else { return nil }
            return foodGroups[name] ?? resolver.foodGroup(name)
        }
        let unitFor: (String?) -> ServingSizeUnit? = { name in
            guard let name, !name.isEmpty else { return nil }
            return units[name] ?? resolver.unit(name, plural: nil)
        }

        restoreUser(backup, exact: exact, summary: &summary)

        let existingFoods = (try? context.fetch(FetchDescriptor<FoodItem>())) ?? []
        var foodsByID = Dictionary(
            existingFoods.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let relationships = RecordRelationships(
            food: { foodsByID[$0] },
            source: sourceFor,
            category: categoryFor,
            foodGroup: foodGroupFor,
            unit: unitFor
        )
        var restoredFoods: [(record: MacroBackup.FoodRecord, item: FoodItem)] = []

        for record in backup.foods {
            if foodsByID[record.id] != nil {
                summary.skippedExisting += 1
                continue
            }

            let food = record.insert(relationships: relationships, in: context)
            foodsByID[food.id] = food
            restoredFoods.append((record, food))

            summary.foods += 1
            if food.type == .recipe { summary.recipes += 1 }
        }

        for (record, recipe) in restoredFoods {
            record.insertIngredients(into: recipe, relationships: relationships, in: context)
        }

        let restoredIDs = Set(restoredFoods.map(\.item.id))
        let existingFavorites =
            (try? context.fetch(FetchDescriptor<FavoriteEntry>())) ?? []
        var nextFavoriteOrder = (existingFavorites.map(\.orderIndex).max() ?? -1) + 1

        for favorite in backup.favorites.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            guard restoredIDs.contains(favorite.foodID),
                let food = foodsByID[favorite.foodID]
            else { continue }

            let order = exact ? favorite.orderIndex : nextFavoriteOrder
            context.insert(FavoriteEntry(orderIndex: order, foodItem: food))
            nextFavoriteOrder += 1
            summary.favorites += 1
        }

        let existingLogIDs = Set(
            ((try? context.fetch(FetchDescriptor<LoggedEntry>())) ?? []).map(\.id)
        )

        for record in backup.logs {
            if existingLogIDs.contains(record.id) {
                summary.skippedExisting += 1
                continue
            }
            record.insert(relationships: relationships, in: context)
            summary.logs += 1
            summary.photos += record.photoCount
        }

        let existingDraftIDs = Set(
            ((try? context.fetch(FetchDescriptor<EntryDraft>())) ?? []).map(\.id)
        )
        for record in backup.drafts where !existingDraftIDs.contains(record.id) {
            let food = record.foodItemID.flatMap { foodsByID[$0] }
            guard record.insert(foodItem: food, in: context) != nil else { continue }
            summary.photos += record.photos.count
            summary.drafts += 1
        }

        return summary
    }

    private func restoreUser(
        _ backup: MacroBackup,
        exact: Bool,
        summary: inout BackupRestoreSummary
    ) {
        let existingUser = (try? context.fetch(FetchDescriptor<User>()))?.first
        let user: User

        if let existingUser {
            user = existingUser
        } else {
            user = User(
                name: backup.user?.name,
                onboardingComplete: backup.user?.onboardingComplete ?? false
            )
            user.dayStartMinutes = backup.user?.dayStartMinutes ?? 0
            context.insert(user)
        }

        if exact, let record = backup.user {
            user.name = record.name
            user.onboardingComplete = record.onboardingComplete
            user.dayStartMinutes = record.dayStartMinutes
        }

        let existingGoalIDs = Set((user.goalsHistory ?? []).map(\.id))
        for record in backup.goals where !existingGoalIDs.contains(record.id) {
            let goal = UserGoals(
                id: record.id,
                date: record.date,
                calories: record.calories,
                calorieMode: GoalLimitMode(rawValue: record.calorieMode) ?? .off,
                protein: record.protein,
                proteinMode: GoalLimitMode(rawValue: record.proteinMode) ?? .off,
                carbs: record.carbs,
                carbsMode: GoalLimitMode(rawValue: record.carbsMode) ?? .off,
                fat: record.fat,
                fatMode: GoalLimitMode(rawValue: record.fatMode) ?? .off,
                fiber: record.fiber,
                fiberMode: GoalLimitMode(rawValue: record.fiberMode) ?? .off,
                owner: user
            )
            context.insert(goal)
            summary.goals += 1
        }
    }

    private func restoreList<Record, Model: PersistentModel>(
        _ records: [Record],
        name: (Record) -> String,
        isDefault: (Record) -> Bool,
        order: (Record) -> Int,
        existingName: (Model) -> String,
        existingOrder: (Model) -> Int,
        exact: Bool,
        summary: inout BackupRestoreSummary,
        make: (Record, Int) -> Model
    ) -> [String: Model] {
        let existing = (try? context.fetch(FetchDescriptor<Model>())) ?? []
        var byName = Dictionary(
            existing.map { (existingName($0), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var nextOrder = (existing.map(existingOrder).max() ?? -1) + 1

        for record in records.sorted(by: { order($0) < order($1) })
        where byName[name(record)] == nil {
            let item = make(record, exact ? order(record) : nextOrder)
            context.insert(item)
            byName[name(record)] = item
            nextOrder += 1
            if !isDefault(record) { summary.lists += 1 }
        }
        return byName
    }
}

@MainActor
struct RecordRelationships {
    var food: (UUID) -> FoodItem?
    var source: (String?) -> EntrySource?
    var category: (String?) -> CategorySource?
    var foodGroup: (String?) -> FoodGroupSource?
    var unit: (String?) -> ServingSizeUnit?

    static func resolving(in context: ModelContext) -> RecordRelationships {
        let resolver = ImportResolver(context: context)
        return RecordRelationships(
            food: { id in
                try? context.fetch(
                    FetchDescriptor<FoodItem>(predicate: #Predicate { $0.id == id })
                ).first
            },
            source: { $0.flatMap(resolver.source) },
            category: { $0.flatMap(resolver.category) },
            foodGroup: { $0.flatMap(resolver.foodGroup) },
            unit: { name in
                guard let name, !name.isEmpty else { return nil }
                return resolver.unit(name, plural: nil)
            }
        )
    }
}

extension MacroBackup.FoodRecord {
    @MainActor
    @discardableResult
    func insert(relationships: RecordRelationships, in context: ModelContext) -> FoodItem {
        let food = FoodItem(
            id: id,
            name: name,
            type: EntryType(rawValue: type) ?? .food,
            source: relationships.source(source),
            category: relationships.category(category),
            foodGroup: relationships.foodGroup(foodGroup),
            servingSize: servingSize,
            servingUnit: relationships.unit(servingUnit),
            servingWeight: servingWeight,
            servingWeightUnit: servingWeightUnit,
            isAIEstimated: isAIEstimated,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: fiber,
            isCustomDefaultServing: isCustomDefaultServing,
            customServingSize: customServingSize,
            stickyNote: note.map { Note(text: $0.text, lastUpdated: $0.lastUpdated) },
            dateAdded: dateAdded
        )
        context.insert(food)
        return food
    }

    @MainActor
    func apply(to food: FoodItem, relationships: RecordRelationships, in context: ModelContext) {
        food.name = name
        food.type = EntryType(rawValue: type) ?? food.type
        food.source = relationships.source(source)
        food.category = relationships.category(category)
        food.foodGroup = relationships.foodGroup(foodGroup)
        food.servingSize = servingSize
        food.servingUnit = relationships.unit(servingUnit)
        food.servingWeight = servingWeight
        food.servingWeightUnit = servingWeightUnit
        food.isAIEstimated = isAIEstimated
        food.calories = calories
        food.protein = protein
        food.carbs = carbs
        food.fat = fat
        food.fiber = fiber
        food.isCustomDefaultServing = isCustomDefaultServing
        food.customServingSize = customServingSize
        food.dateAdded = dateAdded

        if let note {
            if let existing = food.stickyNote {
                existing.text = note.text
                existing.lastUpdated = note.lastUpdated
            } else {
                food.stickyNote = Note(text: note.text, lastUpdated: note.lastUpdated)
            }
        } else if let existing = food.stickyNote {
            context.delete(existing)
            food.stickyNote = nil
        }

        for ingredient in food.recipeIngredients ?? [] {
            context.delete(ingredient)
        }
        food.recipeIngredients = []
        insertIngredients(into: food, relationships: relationships, in: context)
    }

    @MainActor
    func insertIngredients(
        into recipe: FoodItem,
        relationships: RecordRelationships,
        in context: ModelContext
    ) {
        for record in ingredients {
            let ingredient = RecipeIngredient(
                id: record.id,
                quantity: record.quantity,
                unit: record.unit,
                displayOrder: record.displayOrder,
                name: record.name,
                baseServingSize: record.baseServingSize,
                baseServingUnitName: record.baseServingUnitName,
                baseServingWeight: record.baseServingWeight,
                baseServingWeightUnit: record.baseServingWeightUnit,
                baseCalories: record.baseCalories,
                baseProtein: record.baseProtein,
                baseCarbs: record.baseCarbs,
                baseFat: record.baseFat,
                baseFiber: record.baseFiber
            )
            ingredient.ingredientItem = record.ingredientItemID.flatMap(relationships.food)
            ingredient.parentRecipe = recipe
            context.insert(ingredient)
        }
    }
}

extension MacroBackup.LogRecord {
    var photoCount: Int {
        children.reduce(photos.count) { $0 + $1.photoCount }
    }

    @MainActor
    @discardableResult
    func insert(
        parent: LoggedEntry? = nil,
        relationships: RecordRelationships,
        in context: ModelContext
    ) -> LoggedEntry {
        let log = LoggedEntry(
            id: id,
            name: name,
            typeRawValue: typeRawValue,
            originalFoodItem: originalFoodID.flatMap(relationships.food),
            parentEntry: parent,
            source: relationships.source(source),
            category: relationships.category(category),
            foodGroup: relationships.foodGroup(foodGroup),
            timestamp: timestamp,
            location: location,
            loggedQuantity: loggedQuantity,
            loggedUnit: loggedUnit,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: fiber,
            isManualOverride: isManualOverride,
            logNote: logNote,
            displayOrder: displayOrder
        )
        log.photos = photos.map { $0.makePhoto() }
        context.insert(log)

        for child in children {
            child.insert(parent: log, relationships: relationships, in: context)
        }
        return log
    }
}

extension MacroBackup.DraftRecord {
    @MainActor
    @discardableResult
    func insert(foodItem: FoodItem?, in context: ModelContext) -> EntryDraft? {
        guard let kind = DraftKind(rawValue: kindRawValue),
            let type = EntryType(rawValue: typeRawValue)
        else { return nil }

        let draft = EntryDraft(
            id: id,
            kind: kind,
            type: type,
            name: name,
            timestamp: timestamp,
            foodItem: foodItem,
            payload: payload,
            createdAt: createdAt
        )
        draft.updatedAt = updatedAt
        draft.photos = photos.map { $0.makePhoto() }
        context.insert(draft)
        return draft
    }
}

extension MacroBackup.PhotoRecord {
    func makePhoto() -> EntryPhoto {
        EntryPhoto(
            imageData: imageData,
            scale: scale,
            offsetX: offsetX,
            offsetY: offsetY,
            displayOrder: displayOrder
        )
    }
}
