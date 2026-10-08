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

@MainActor
enum LibraryListStore {
    static func add(
        _ name: String,
        to kind: LibraryListKind,
        displayOrder: Int,
        in context: ModelContext
    ) {
        insert(
            name,
            isDefault: isDefaultName(name, in: kind),
            kind: kind,
            displayOrder: displayOrder,
            in: context
        )
        save(context)
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
    ) {
        var nextOrder = (items.map(\.displayOrder).max() ?? -1) + 1
        for name in missingDefaults(for: kind, existing: items) {
            insert(name, isDefault: true, kind: kind, displayOrder: nextOrder, in: context)
            nextOrder += 1
        }
        save(context)
    }

    private static func insert(
        _ name: String,
        isDefault: Bool,
        kind: LibraryListKind,
        displayOrder: Int,
        in context: ModelContext
    ) {
        switch kind {
        case .sources:
            context.insert(
                EntrySource(
                    source: name,
                    isDefault: isDefault,
                    displayOrder: displayOrder
                )
            )
        case .categories:
            context.insert(
                CategorySource(
                    category: name,
                    isDefault: isDefault,
                    displayOrder: displayOrder
                )
            )
        case .foodGroups:
            context.insert(
                FoodGroupSource(
                    foodGroup: name,
                    isDefault: isDefault,
                    displayOrder: displayOrder
                )
            )
        }
    }

    static func rename(
        _ id: PersistentIdentifier,
        to name: String,
        in kind: LibraryListKind,
        context: ModelContext
    ) {
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
        save(context)
    }

    static func setHidden(
        _ id: PersistentIdentifier,
        _ isHidden: Bool,
        in context: ModelContext
    ) {
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
        save(context)
    }

    static func reorder(_ ids: [PersistentIdentifier], in context: ModelContext) {
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
        save(context)
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

    static func delete(_ id: PersistentIdentifier, in context: ModelContext) {
        let model = context.model(for: id)

        switch model {
        case let source as EntrySource:
            let descriptors = (
                foodsDescriptor(source.source, .sources),
                logsDescriptor(source.source, .sources)
            )
            fetch(descriptors.0, in: context).forEach { $0.source = nil }
            fetch(descriptors.1, in: context).forEach { $0.source = nil }
            updateDrafts(.sources, replacing: source.source, with: "", in: context)
        case let category as CategorySource:
            let descriptors = (
                foodsDescriptor(category.category, .categories),
                logsDescriptor(category.category, .categories)
            )
            fetch(descriptors.0, in: context).forEach { $0.category = nil }
            fetch(descriptors.1, in: context).forEach { $0.category = nil }
            updateDrafts(.categories, replacing: category.category, with: "", in: context)
        case let foodGroup as FoodGroupSource:
            let descriptors = (
                foodsDescriptor(foodGroup.foodGroup, .foodGroups),
                logsDescriptor(foodGroup.foodGroup, .foodGroups)
            )
            fetch(descriptors.0, in: context).forEach { $0.foodGroup = nil }
            fetch(descriptors.1, in: context).forEach { $0.foodGroup = nil }
            updateDrafts(.foodGroups, replacing: foodGroup.foodGroup, with: "", in: context)
        default:
            return
        }

        context.delete(model)
        save(context)
    }

    private static func updateDrafts(
        _ kind: LibraryListKind,
        replacing oldName: String,
        with newName: String,
        in context: ModelContext
    ) {
        for draft in fetch(FetchDescriptor<EntryDraft>(), in: context) {
            switch draft.kind {
            case .logFood:
                let keyPath: WritableKeyPath<LogEntryDraftState, String> =
                    switch kind {
                    case .sources: \.sourceSelection
                    case .categories: \.categorySelection
                    case .foodGroups: \.foodGroupSelection
                    }
                replace(keyPath, in: draft, from: oldName, to: newName)
            case .logRecipe:
                let keyPath: WritableKeyPath<LogRecipeDraftState, String>? =
                    switch kind {
                    case .sources: \.sourceSelection
                    case .categories: \.categorySelection
                    case .foodGroups: nil
                    }
                replace(keyPath, in: draft, from: oldName, to: newName)
            case .addFood:
                let keyPath: WritableKeyPath<AddEntryDraftState, String> =
                    switch kind {
                    case .sources: \.source
                    case .categories: \.category
                    case .foodGroups: \.foodGroup
                    }
                replace(keyPath, in: draft, from: oldName, to: newName)
            case .addRecipe:
                let keyPath: WritableKeyPath<AddRecipeDraftState, String>? =
                    switch kind {
                    case .sources: \.source
                    case .categories: \.category
                    case .foodGroups: nil
                    }
                replace(keyPath, in: draft, from: oldName, to: newName)
            case nil:
                continue
            }
        }
    }

    private static func replace<State: Codable>(
        _ keyPath: WritableKeyPath<State, String>?,
        in draft: EntryDraft,
        from oldName: String,
        to newName: String
    ) {
        guard let keyPath, var state = draft.decodeState(State.self),
            state[keyPath: keyPath] == oldName
        else { return }

        state[keyPath: keyPath] = newName
        if let data = try? JSONEncoder().encode(state) {
            draft.payload = data
        }
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

    private static func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            context.rollback()
            print("Failed to update list: \(error.localizedDescription)")
        }
    }
}
