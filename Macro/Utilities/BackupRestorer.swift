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

    var message: String {
        func count(_ value: Int, _ singular: String, _ plural: String) -> String {
            "\(value) \(value == 1 ? singular : plural)"
        }

        var lines: [String] = []
        if foods > 0 {
            lines.append(
                "Restored \(count(foods, "library entry", "library entries"))"
                    + (recipes > 0 ? " (\(count(recipes, "recipe", "recipes")))." : ".")
            )
        }
        if logs > 0 { lines.append("Restored \(count(logs, "log", "logs")).") }
        if photos > 0 { lines.append("Restored \(count(photos, "photo", "photos")).") }
        if goals > 0 { lines.append("Restored \(count(goals, "goal", "goals")).") }
        if favorites > 0 { lines.append("Restored \(count(favorites, "favorite", "favorites")).") }
        if lists > 0 { lines.append("Restored \(count(lists, "custom list item", "custom list items")).") }
        if drafts > 0 { lines.append("Restored \(count(drafts, "draft", "drafts")).") }
        if skippedExisting > 0 {
            lines.append("Kept \(count(skippedExisting, "item", "items")) you already had.")
        }
        return lines.isEmpty
            ? "Everything in this backup is already on this device."
            : lines.joined(separator: "\n")
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
        var restoredFoods: [(record: MacroBackup.FoodRecord, item: FoodItem)] = []

        for record in backup.foods {
            if foodsByID[record.id] != nil {
                summary.skippedExisting += 1
                continue
            }

            let food = FoodItem(
                id: record.id,
                name: record.name,
                type: EntryType(rawValue: record.type) ?? .food,
                source: sourceFor(record.source),
                category: categoryFor(record.category),
                foodGroup: foodGroupFor(record.foodGroup),
                servingSize: record.servingSize,
                servingUnit: unitFor(record.servingUnit),
                servingWeight: record.servingWeight,
                servingWeightUnit: record.servingWeightUnit,
                isAIEstimated: record.isAIEstimated,
                calories: record.calories,
                protein: record.protein,
                carbs: record.carbs,
                fat: record.fat,
                fiber: record.fiber,
                isCustomDefaultServing: record.isCustomDefaultServing,
                customServingSize: record.customServingSize,
                stickyNote: record.note.map {
                    Note(text: $0.text, lastUpdated: $0.lastUpdated)
                },
                dateAdded: record.dateAdded
            )
            context.insert(food)
            foodsByID[food.id] = food
            restoredFoods.append((record, food))

            summary.foods += 1
            if food.type == .recipe { summary.recipes += 1 }
        }

        for (record, recipe) in restoredFoods {
            for ingredientRecord in record.ingredients {
                let ingredient = RecipeIngredient(
                    id: ingredientRecord.id,
                    quantity: ingredientRecord.quantity,
                    unit: ingredientRecord.unit,
                    displayOrder: ingredientRecord.displayOrder,
                    name: ingredientRecord.name,
                    baseServingSize: ingredientRecord.baseServingSize,
                    baseServingUnitName: ingredientRecord.baseServingUnitName,
                    baseServingWeight: ingredientRecord.baseServingWeight,
                    baseServingWeightUnit: ingredientRecord.baseServingWeightUnit,
                    baseCalories: ingredientRecord.baseCalories,
                    baseProtein: ingredientRecord.baseProtein,
                    baseCarbs: ingredientRecord.baseCarbs,
                    baseFat: ingredientRecord.baseFat,
                    baseFiber: ingredientRecord.baseFiber
                )
                ingredient.ingredientItem = ingredientRecord.ingredientItemID.flatMap {
                    foodsByID[$0]
                }
                ingredient.parentRecipe = recipe
                context.insert(ingredient)
            }
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

        func insertLog(_ record: MacroBackup.LogRecord, parent: LoggedEntry?) {
            let log = LoggedEntry(
                id: record.id,
                name: record.name,
                typeRawValue: record.typeRawValue,
                originalFoodItem: record.originalFoodID.flatMap { foodsByID[$0] },
                parentEntry: parent,
                source: sourceFor(record.source),
                category: categoryFor(record.category),
                foodGroup: foodGroupFor(record.foodGroup),
                timestamp: record.timestamp,
                location: record.location,
                loggedQuantity: record.loggedQuantity,
                loggedUnit: record.loggedUnit,
                calories: record.calories,
                protein: record.protein,
                carbs: record.carbs,
                fat: record.fat,
                fiber: record.fiber,
                isManualOverride: record.isManualOverride,
                logNote: record.logNote,
                displayOrder: record.displayOrder
            )
            log.photos = makePhotos(record.photos)
            summary.photos += record.photos.count
            context.insert(log)

            for child in record.children {
                insertLog(child, parent: log)
            }
        }

        for record in backup.logs {
            if existingLogIDs.contains(record.id) {
                summary.skippedExisting += 1
                continue
            }
            insertLog(record, parent: nil)
            summary.logs += 1
        }

        let existingDraftIDs = Set(
            ((try? context.fetch(FetchDescriptor<EntryDraft>())) ?? []).map(\.id)
        )
        for record in backup.drafts where !existingDraftIDs.contains(record.id) {
            guard let kind = DraftKind(rawValue: record.kindRawValue),
                let type = EntryType(rawValue: record.typeRawValue)
            else { continue }

            let draft = EntryDraft(
                id: record.id,
                kind: kind,
                type: type,
                name: record.name,
                timestamp: record.timestamp,
                foodItem: record.foodItemID.flatMap { foodsByID[$0] },
                payload: record.payload,
                createdAt: record.createdAt
            )
            draft.updatedAt = record.updatedAt
            draft.photos = makePhotos(record.photos)
            summary.photos += record.photos.count
            context.insert(draft)
            summary.drafts += 1
        }

        return summary
    }

    private func makePhotos(_ records: [MacroBackup.PhotoRecord]) -> [EntryPhoto] {
        records.map {
            EntryPhoto(
                imageData: $0.imageData,
                scale: $0.scale,
                offsetX: $0.offsetX,
                offsetY: $0.offsetY,
                displayOrder: $0.displayOrder
            )
        }
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
