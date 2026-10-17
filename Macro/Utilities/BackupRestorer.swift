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
    var photosIncomplete = false

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

    func restore(_ file: MacroBackupFile, mode: BackupRestoreMode) async throws
        -> BackupRestoreSummary
    {
        switch mode {
        case .merge:
            let photos = PendingBackupPhotos()
            var summary = apply(file.backup, exact: false, photos: photos)
            try saveOrRollback()
            do {
                try await attach(photos, from: file)
            } catch {
                summary.photosIncomplete = true
            }
            return summary
        case .replace:
            let snapshot = try await writeSnapshot()

            do {
                try MacroBackupFile.ensureFreeSpace(for: file.backup.photoByteCount)
                try eraseAll()
            } catch {
                snapshot.remove()
                throw BackupRestoreError.nothingChanged(error)
            }

            do {
                let summary = try await applyExactly(file)
                try? AppSeeder.seedDefaults(into: context)
                snapshot.remove()
                return summary
            } catch {
                context.rollback()

                do {
                    try eraseAll()
                    _ = try await applyExactly(snapshot)
                    snapshot.remove()
                    throw BackupRestoreError.recovered(error)
                } catch let restoreError as BackupRestoreError {
                    throw restoreError
                } catch {
                    context.rollback()
                    throw BackupRestoreError.unrecovered(error, snapshotURL: snapshot.url)
                }
            }
        }
    }

    private func applyExactly(_ file: MacroBackupFile) async throws -> BackupRestoreSummary {
        let photos = PendingBackupPhotos()
        let summary = apply(file.backup, exact: true, photos: photos)
        try context.save()
        try await attach(photos, from: file)
        return summary
    }

    private func attach(_ photos: PendingBackupPhotos, from file: MacroBackupFile) async throws {
        let jobs = photos.jobs
        guard !jobs.isEmpty else { return }
        let container = context.container
        try await Task.detached(priority: .userInitiated) {
            try file.attachPhotos(jobs, container: container)
        }.value
    }

    private func writeSnapshot() async throws -> MacroBackupFile {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Macro Pre-Restore \(UUID().uuidString).macrobackup")
        return try await MacroBackupFile.create(from: context, at: url)
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

    private func apply(
        _ backup: MacroBackup,
        exact: Bool,
        photos: PendingBackupPhotos
    ) -> BackupRestoreSummary {
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
        let savedLocationsByID = restoreSavedLocations(backup, exact: exact)
        restoreRecentLocations(backup, savedLocationsByID: savedLocationsByID)

        let relationships = RecordRelationships(
            food: { foodsByID[$0] },
            source: sourceFor,
            category: categoryFor,
            foodGroup: foodGroupFor,
            unit: unitFor,
            savedLocation: { $0.flatMap { savedLocationsByID[$0] } }
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
            record.insert(relationships: relationships, photos: photos, in: context)
            summary.logs += 1
            summary.photos += record.photoCount
        }

        let existingDraftIDs = Set(
            ((try? context.fetch(FetchDescriptor<EntryDraft>())) ?? []).map(\.id)
        )
        for record in backup.drafts where !existingDraftIDs.contains(record.id) {
            let food = record.foodItemID.flatMap { foodsByID[$0] }
            guard record.insert(foodItem: food, photos: photos, in: context) != nil else { continue }
            summary.photos += record.photos.count
            summary.drafts += 1
        }

        return summary
    }

    private func restoreSavedLocations(
        _ backup: MacroBackup,
        exact: Bool
    ) -> [UUID: SavedLocation] {
        let existing = (try? context.fetch(FetchDescriptor<SavedLocation>())) ?? []
        var byID = Dictionary(
            existing.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var nextOrder = (existing.map(\.displayOrder).max() ?? -1) + 1

        let records = backup.savedLocations.sorted { $0.displayOrder < $1.displayOrder }
        for record in records where byID[record.id] == nil {
            let recordLocation = EntryLocation(
                name: record.name,
                latitude: record.latitude,
                longitude: record.longitude,
                mapItemID: record.mapItemID
            )
            if let match = SavedLocation.matching(recordLocation, in: existing) {
                byID[record.id] = match
                continue
            }
            let location = SavedLocation(
                id: record.id,
                name: record.name,
                address: record.address,
                latitude: record.latitude,
                longitude: record.longitude,
                mapItemID: record.mapItemID,
                isFavorite: record.isFavorite,
                mapName: record.mapName,
                displayOrder: exact ? record.displayOrder : nextOrder,
                createdAt: record.createdAt
            )
            context.insert(location)
            byID[record.id] = location
            nextOrder += 1
        }
        return byID
    }

    private func restoreRecentLocations(
        _ backup: MacroBackup,
        savedLocationsByID: [UUID: SavedLocation]
    ) {
        let uses = backup.recentLocations.map { record in
            var location = record.location
            location.savedLocationID = location.savedLocationID
                .flatMap { savedLocationsByID[$0]?.id }
            return (location: Optional(location), date: record.lastUsed)
        }
        RecentLocationStore.record(uses, in: context)
    }

    private func restoreDayCircles(
        from record: MacroBackup.UserRecord?,
        to user: User
    ) {
        if let mode = record?.dayCircleMode.flatMap(DayCircleMode.init(rawValue:)) {
            user.dayCircleMode = mode
        }
        if let goal = record?.dayCircleGoal.flatMap(DayCircleGoal.init(rawValue:)) {
            user.dayCircleGoal = goal
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
            restoreDayCircles(from: backup.user, to: user)
            context.insert(user)
        }

        if exact, let record = backup.user {
            user.name = record.name
            user.onboardingComplete = record.onboardingComplete
            user.dayStartMinutes = record.dayStartMinutes
            restoreDayCircles(from: record, to: user)
        }

        let existingGoalIDs = Set((user.goalsHistory ?? []).map(\.id))
        let deviceStart = exact ? nil : user.goalTimeline.periods.first?.startDay
        var insertedGoalIDs: Set<UUID> = []
        for record in backup.goals {
            let isBeforeDeviceHistory = deviceStart.map {
                Calendar.current.logicalDay(
                    for: record.date,
                    dayStartMinutes: user.dayStartMinutes
                ) < $0
            } ?? true
            guard !existingGoalIDs.contains(record.id) else {
                summary.skippedExisting += 1
                continue
            }
            guard isBeforeDeviceHistory else { continue }
            let goal = UserGoals(record.targets, id: record.id, date: record.date, owner: user)
            context.insert(goal)
            insertedGoalIDs.insert(goal.id)
        }

        if !exact {
            GoalHistoryStore.normalize(user, in: context)
        }
        summary.goals += (user.goalsHistory ?? []).filter {
            !$0.isDeleted && insertedGoalIDs.contains($0.id)
        }.count
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
    var savedLocation: (UUID?) -> SavedLocation?

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
            },
            savedLocation: { SavedLocation.find(id: $0, in: context) }
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
            defaultLocation: linkedDefaultLocation(relationships),
            stickyNote: note.map { Note(text: $0.text, lastUpdated: $0.lastUpdated) },
            dateAdded: dateAdded
        )
        context.insert(food)
        return food
    }

    @MainActor
    private func linkedDefaultLocation(_ relationships: RecordRelationships) -> EntryLocation? {
        guard var location = defaultLocation, let id = location.savedLocationID else {
            return defaultLocation
        }
        location.savedLocationID = relationships.savedLocation(id)?.id
        return location
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
        food.defaultLocation = linkedDefaultLocation(relationships)
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
            ingredient.dateAdded = record.dateAdded ?? recipe.dateAdded
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
        photos pending: PendingBackupPhotos? = nil,
        in context: ModelContext
    ) -> LoggedEntry {
        let savedLocation = relationships.savedLocation(self.location?.savedLocationID)
        var location = self.location
        location?.savedLocationID = savedLocation?.id

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
            savedLocation: savedLocation,
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
        log.photos = photos.compactMap { $0.makePhoto() }
        context.insert(log)
        pending?.add(log, isDraft: false, photos: photos)

        for child in children {
            child.insert(parent: log, relationships: relationships, photos: pending, in: context)
        }
        return log
    }
}

extension MacroBackup.DraftRecord {
    @MainActor
    @discardableResult
    func insert(
        foodItem: FoodItem?,
        photos pending: PendingBackupPhotos? = nil,
        in context: ModelContext
    ) -> EntryDraft? {
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
        draft.photos = photos.compactMap { $0.makePhoto() }
        context.insert(draft)
        pending?.add(draft, isDraft: true, photos: photos)
        return draft
    }
}

extension MacroBackup.PhotoRecord {
    func makePhoto() -> EntryPhoto? {
        guard let imageData else { return nil }
        return EntryPhoto(
            imageData: imageData,
            scale: scale,
            offsetX: offsetX,
            offsetY: offsetY,
            displayOrder: displayOrder
        )
    }
}
