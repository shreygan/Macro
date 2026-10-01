//
//  ImportResolver.swift
//  Macro
//
//  Created by Shrey Gangwar on 9/30/26.
//

import Foundation
import SwiftData

enum DuplicateStrategy: String, CaseIterable {
    case skip = "Skip"
    case replace = "Replace"
    case keepBoth = "Keep Both"
}

@MainActor
struct ImportResolver {
    let context: ModelContext

    func source(_ name: String) -> EntrySource? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }

        let descriptor = FetchDescriptor<EntrySource>(
            predicate: #Predicate { $0.source == name }
        )
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }

        let count = (try? context.fetchCount(FetchDescriptor<EntrySource>())) ?? 0
        let created = EntrySource(source: name, displayOrder: count)
        context.insert(created)
        return created
    }

    func category(_ name: String) -> CategorySource? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }

        let descriptor = FetchDescriptor<CategorySource>(
            predicate: #Predicate { $0.category == name }
        )
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }

        let count =
            (try? context.fetchCount(FetchDescriptor<CategorySource>())) ?? 0
        let created = CategorySource(category: name, displayOrder: count + 1)
        context.insert(created)
        return created
    }

    func foodGroup(_ name: String) -> FoodGroupSource? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }

        let descriptor = FetchDescriptor<FoodGroupSource>(
            predicate: #Predicate { $0.foodGroup == name }
        )
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }

        let count =
            (try? context.fetchCount(FetchDescriptor<FoodGroupSource>())) ?? 0
        let created = FoodGroupSource(foodGroup: name, displayOrder: count + 1)
        context.insert(created)
        return created
    }

    func unit(_ name: String, plural: String?) -> ServingSizeUnit {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = name.isEmpty ? "serving" : name

        let descriptor = FetchDescriptor<ServingSizeUnit>(
            predicate: #Predicate { $0.unit == resolvedName }
        )
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }

        let count =
            (try? context.fetchCount(FetchDescriptor<ServingSizeUnit>())) ?? 0
        let created = ServingSizeUnit(
            unit: resolvedName,
            pluralVariant: plural.map { $0.isEmpty ? nil : $0 }
                ?? resolvedName + "s",
            displayOrder: count
        )
        context.insert(created)
        return created
    }

    func matchFood(
        id: UUID?,
        name: String,
        source: String,
        in library: [FoodItem]
    ) -> FoodItem? {
        if let id, let match = library.first(where: { $0.id == id }) {
            return match
        }

        let name = LibraryCSV.normalized(name)
        let source = LibraryCSV.normalized(source)
        let nameMatches = library.filter {
            LibraryCSV.normalized($0.name) == name
        }

        return nameMatches.first {
            LibraryCSV.normalized($0.source?.source ?? "") == source
        } ?? (source.isEmpty ? nameMatches.first : nil)
    }
}
