//
//  LibraryListStore.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/2/26.
//

import Foundation
import SwiftData

enum LibraryListKind: String, CaseIterable, Identifiable, Hashable {
    case sources, categories, foodGroups

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sources: return "Sources"
        case .categories: return "Categories"
        case .foodGroups: return "Food Groups"
        }
    }

    var itemName: String {
        switch self {
        case .sources: return "Source"
        case .categories: return "Category"
        case .foodGroups: return "Food Group"
        }
    }

    var defaultNames: [String] {
        switch self {
        case .sources: return AppSeeder.defaultEntrySources
        case .categories: return AppSeeder.defaultCategorySources
        case .foodGroups: return AppSeeder.defaultFoodGroupSources
        }
    }

    var symbol: String {
        switch self {
        case .sources: return "storefront"
        case .categories: return "tag"
        case .foodGroups: return "leaf"
        }
    }
}

protocol LibraryListOption {
    var optionName: String { get }
    var isHidden: Bool { get }
}

extension EntrySource: LibraryListOption {
    var optionName: String { source }
}

extension CategorySource: LibraryListOption {
    var optionName: String { category }
}

extension FoodGroupSource: LibraryListOption {
    var optionName: String { foodGroup }
}

extension Sequence where Element: LibraryListOption {
    func visibleNames(keeping selection: String? = nil) -> [String] {
        filter { !$0.isHidden || $0.optionName == selection }
            .map(\.optionName)
    }
}

struct LibraryListItem: Identifiable, Equatable {
    let id: PersistentIdentifier
    let name: String
    let displayOrder: Int
    let isDefault: Bool
    let isHidden: Bool

    static func items(
        for kind: LibraryListKind,
        sources: [EntrySource],
        categories: [CategorySource],
        foodGroups: [FoodGroupSource]
    ) -> [LibraryListItem] {
        switch kind {
        case .sources:
            return sources.map {
                LibraryListItem(
                    id: $0.persistentModelID,
                    name: $0.source,
                    displayOrder: $0.displayOrder,
                    isDefault: $0.isDefault,
                    isHidden: $0.isHidden
                )
            }
        case .categories:
            return categories.map {
                LibraryListItem(
                    id: $0.persistentModelID,
                    name: $0.category,
                    displayOrder: $0.displayOrder,
                    isDefault: $0.isDefault,
                    isHidden: $0.isHidden
                )
            }
        case .foodGroups:
            return foodGroups.map {
                LibraryListItem(
                    id: $0.persistentModelID,
                    name: $0.foodGroup,
                    displayOrder: $0.displayOrder,
                    isDefault: $0.isDefault,
                    isHidden: $0.isHidden
                )
            }
        }
    }
}

struct LibraryListUsage {
    var foodCount: Int
    var logCount: Int

    var isUsed: Bool { foodCount > 0 || logCount > 0 }
}

struct DeletedListItemRecord {
    let kind: LibraryListKind
    let name: String
    let isDefault: Bool
    let isHidden: Bool
    let displayOrder: Int
    let foodIDs: [UUID]
    let logIDs: [UUID]
    let draftIDs: [UUID]
}

@MainActor
enum LibraryListStore {
    static func add(
        _ name: String,
        to kind: LibraryListKind,
        displayOrder: Int,
        in context: ModelContext
    ) throws {
        insert(
            name,
            isDefault: isDefaultName(name, in: kind),
            kind: kind,
            displayOrder: displayOrder,
            in: context
        )
        try save(context)
    }

    private static func isDefaultName(
        _ name: String,
        in kind: LibraryListKind
    ) -> Bool {
        kind.defaultNames.contains {
            $0.caseInsensitiveCompare(name) == .orderedSame
        }
    }

    static func missingDefaults(
        for kind: LibraryListKind,
        existing items: [LibraryListItem]
    ) -> [String] {
        kind.defaultNames.filter { name in
            !items.contains {
                $0.name.caseInsensitiveCompare(name) == .orderedSame
            }
        }
    }

    static func restoreDefaults(
        for kind: LibraryListKind,
        existing items: [LibraryListItem],
        in context: ModelContext
    ) throws {
        var nextOrder = (items.map(\.displayOrder).max() ?? -1) + 1
        for name in missingDefaults(for: kind, existing: items) {
            insert(name, isDefault: true, kind: kind, displayOrder: nextOrder, in: context)
            nextOrder += 1
        }
        try save(context)
    }

    @discardableResult
    private static func insert(
        _ name: String,
        isDefault: Bool,
        isHidden: Bool = false,
        kind: LibraryListKind,
        displayOrder: Int,
        in context: ModelContext
    ) -> any PersistentModel {
        let model: any PersistentModel =
            switch kind {
            case .sources:
                EntrySource(
                    source: name,
                    isDefault: isDefault,
                    displayOrder: displayOrder,
                    isHidden: isHidden
                )
            case .categories:
                CategorySource(
                    category: name,
                    isDefault: isDefault,
                    displayOrder: displayOrder,
                    isHidden: isHidden
                )
            case .foodGroups:
                FoodGroupSource(
                    foodGroup: name,
                    isDefault: isDefault,
                    displayOrder: displayOrder,
                    isHidden: isHidden
                )
            }
        context.insert(model)
        return model
    }

    static func rename(
        _ id: PersistentIdentifier,
        to name: String,
        in kind: LibraryListKind,
        context: ModelContext
    ) throws {
        let isDefault = isDefaultName(name, in: kind)
        let oldName: String

        switch context.model(for: id) {
        case let source as EntrySource:
            oldName = source.source
            source.source = name
            source.isDefault = isDefault
        case let category as CategorySource:
            oldName = category.category
            category.category = name
            category.isDefault = isDefault
        case let foodGroup as FoodGroupSource:
            oldName = foodGroup.foodGroup
            foodGroup.foodGroup = name
            foodGroup.isDefault = isDefault
        default:
            return
        }
        updateDrafts(kind, replacing: oldName, with: name, in: context)
        try save(context)
    }

    static func setHidden(
        _ id: PersistentIdentifier,
        _ isHidden: Bool,
        in context: ModelContext
    ) throws {
        switch context.model(for: id) {
        case let source as EntrySource:
            source.isHidden = isHidden
        case let category as CategorySource:
            category.isHidden = isHidden
        case let foodGroup as FoodGroupSource:
            foodGroup.isHidden = isHidden
        default:
            return
        }
        try save(context)
    }

    static func reorder(_ ids: [PersistentIdentifier], in context: ModelContext) throws {
        for (index, id) in ids.enumerated() {
            switch context.model(for: id) {
            case let source as EntrySource:
                source.displayOrder = index
            case let category as CategorySource:
                category.displayOrder = index
            case let foodGroup as FoodGroupSource:
                foodGroup.displayOrder = index
            default:
                continue
            }
        }
        try save(context)
    }

    static func usage(
        of name: String,
        in kind: LibraryListKind,
        context: ModelContext
    ) -> LibraryListUsage {
        LibraryListUsage(
            foodCount: count(foodsDescriptor(name, kind), in: context),
            logCount: count(logsDescriptor(name, kind), in: context)
        )
    }

    @discardableResult
    static func delete(
        _ id: PersistentIdentifier,
        in context: ModelContext
    ) throws -> DeletedListItemRecord? {
        let model = context.model(for: id)
        guard !model.isDeleted else { return nil }

        let kind: LibraryListKind
        let item: any LibraryListOption
        let isDefault: Bool
        let displayOrder: Int

        switch model {
        case let source as EntrySource:
            (kind, item, isDefault, displayOrder) =
                (.sources, source, source.isDefault, source.displayOrder)
        case let category as CategorySource:
            (kind, item, isDefault, displayOrder) =
                (.categories, category, category.isDefault, category.displayOrder)
        case let foodGroup as FoodGroupSource:
            (kind, item, isDefault, displayOrder) =
                (.foodGroups, foodGroup, foodGroup.isDefault, foodGroup.displayOrder)
        default:
            return nil
        }

        let name = item.optionName
        let foods = fetch(foodsDescriptor(name, kind), in: context)
        let logs = fetch(logsDescriptor(name, kind), in: context)
        assign(nil, as: kind, foods: foods, logs: logs)
        let draftIDs = updateDrafts(kind, replacing: name, with: "", in: context)

        context.delete(model)

        do {
            try context.save()
            return DeletedListItemRecord(
                kind: kind,
                name: name,
                isDefault: isDefault,
                isHidden: item.isHidden,
                displayOrder: displayOrder,
                foodIDs: foods.map(\.id),
                logIDs: logs.map(\.id),
                draftIDs: draftIDs
            )
        } catch {
            context.rollback()
            throw error
        }
    }

    static func restore(_ record: DeletedListItemRecord, in context: ModelContext) throws {
        let model =
            existing(named: record.name, in: record.kind, context: context)
            ?? insert(
                record.name,
                isDefault: record.isDefault,
                isHidden: record.isHidden,
                kind: record.kind,
                displayOrder: record.displayOrder,
                in: context
            )

        let foodIDs = record.foodIDs
        let logIDs = record.logIDs
        assign(
            model,
            as: record.kind,
            foods: fetch(
                FetchDescriptor<FoodItem>(predicate: #Predicate { foodIDs.contains($0.id) }),
                in: context
            ),
            logs: fetch(
                FetchDescriptor<LoggedEntry>(predicate: #Predicate { logIDs.contains($0.id) }),
                in: context
            )
        )
        updateDrafts(
            record.kind,
            replacing: "",
            with: record.name,
            onlyIDs: Set(record.draftIDs),
            in: context
        )
        try save(context)
    }

    private static func existing(
        named name: String,
        in kind: LibraryListKind,
        context: ModelContext
    ) -> (any PersistentModel)? {
        switch kind {
        case .sources:
            fetch(
                FetchDescriptor<EntrySource>(predicate: #Predicate { $0.source == name }),
                in: context
            ).first
        case .categories:
            fetch(
                FetchDescriptor<CategorySource>(predicate: #Predicate { $0.category == name }),
                in: context
            ).first
        case .foodGroups:
            fetch(
                FetchDescriptor<FoodGroupSource>(predicate: #Predicate { $0.foodGroup == name }),
                in: context
            ).first
        }
    }

    private static func assign(
        _ model: (any PersistentModel)?,
        as kind: LibraryListKind,
        foods: [FoodItem],
        logs: [LoggedEntry]
    ) {
        switch kind {
        case .sources:
            let source = model as? EntrySource
            foods.forEach { $0.source = source }
            logs.forEach { $0.source = source }
        case .categories:
            let category = model as? CategorySource
            foods.forEach { $0.category = category }
            logs.forEach { $0.category = category }
        case .foodGroups:
            let foodGroup = model as? FoodGroupSource
            foods.forEach { $0.foodGroup = foodGroup }
            logs.forEach { $0.foodGroup = foodGroup }
        }
    }

    @discardableResult
    private static func updateDrafts(
        _ kind: LibraryListKind,
        replacing oldName: String,
        with newName: String,
        onlyIDs: Set<UUID>? = nil,
        in context: ModelContext
    ) -> [UUID] {
        var changedIDs: [UUID] = []
        for draft in fetch(FetchDescriptor<EntryDraft>(), in: context) {
            if let onlyIDs, !onlyIDs.contains(draft.id) { continue }
            let changed: Bool
            switch draft.kind {
            case .logFood:
                let keyPath: WritableKeyPath<LogEntryDraftState, String> =
                    switch kind {
                    case .sources: \.sourceSelection
                    case .categories: \.categorySelection
                    case .foodGroups: \.foodGroupSelection
                    }
                changed = replace(keyPath, in: draft, from: oldName, to: newName)
            case .logRecipe:
                let keyPath: WritableKeyPath<LogRecipeDraftState, String>? =
                    switch kind {
                    case .sources: \.sourceSelection
                    case .categories: \.categorySelection
                    case .foodGroups: nil
                    }
                changed = replace(keyPath, in: draft, from: oldName, to: newName)
            case .addFood:
                let keyPath: WritableKeyPath<AddEntryDraftState, String> =
                    switch kind {
                    case .sources: \.source
                    case .categories: \.category
                    case .foodGroups: \.foodGroup
                    }
                changed = replace(keyPath, in: draft, from: oldName, to: newName)
            case .addRecipe:
                let keyPath: WritableKeyPath<AddRecipeDraftState, String>? =
                    switch kind {
                    case .sources: \.source
                    case .categories: \.category
                    case .foodGroups: nil
                    }
                changed = replace(keyPath, in: draft, from: oldName, to: newName)
            case nil:
                continue
            }
            if changed {
                changedIDs.append(draft.id)
            }
        }
        return changedIDs
    }

    private static func replace<State: Codable>(
        _ keyPath: WritableKeyPath<State, String>?,
        in draft: EntryDraft,
        from oldName: String,
        to newName: String
    ) -> Bool {
        guard let keyPath, var state = draft.decodeState(State.self),
            state[keyPath: keyPath] == oldName
        else { return false }

        state[keyPath: keyPath] = newName
        guard let data = try? JSONEncoder().encode(state) else { return false }
        draft.payload = data
        return true
    }

    private static func foodsDescriptor(
        _ name: String,
        _ kind: LibraryListKind
    ) -> FetchDescriptor<FoodItem> {
        switch kind {
        case .sources:
            return FetchDescriptor(
                predicate: #Predicate { $0.source?.source == name }
            )
        case .categories:
            return FetchDescriptor(
                predicate: #Predicate { $0.category?.category == name }
            )
        case .foodGroups:
            return FetchDescriptor(
                predicate: #Predicate { $0.foodGroup?.foodGroup == name }
            )
        }
    }

    private static func logsDescriptor(
        _ name: String,
        _ kind: LibraryListKind
    ) -> FetchDescriptor<LoggedEntry> {
        switch kind {
        case .sources:
            return FetchDescriptor(
                predicate: #Predicate { $0.source?.source == name }
            )
        case .categories:
            return FetchDescriptor(
                predicate: #Predicate { $0.category?.category == name }
            )
        case .foodGroups:
            return FetchDescriptor(
                predicate: #Predicate { $0.foodGroup?.foodGroup == name }
            )
        }
    }

    private static func fetch<Model: PersistentModel>(
        _ descriptor: FetchDescriptor<Model>,
        in context: ModelContext
    ) -> [Model] {
        (try? context.fetch(descriptor)) ?? []
    }

    private static func count<Model: PersistentModel>(
        _ descriptor: FetchDescriptor<Model>,
        in context: ModelContext
    ) -> Int {
        (try? context.fetchCount(descriptor)) ?? 0
    }

    private static func save(_ context: ModelContext) throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
