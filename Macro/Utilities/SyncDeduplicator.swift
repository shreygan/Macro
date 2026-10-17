//
//  SyncDeduplicator.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/16/26.
//

import CoreData
import Foundation
import SwiftData

@MainActor
enum SyncDeduplicator {
    private static let locallyCreatedUserKey = "SyncDeduplicator.locallyCreatedUser"

    static func noteLocallyCreated(_ user: User) {
        UserDefaults.standard.set(user.id.uuidString, forKey: locallyCreatedUserKey)
    }

    static func watch(in context: ModelContext, onReplacedLocalGoals: () -> Void) async {
        if run(in: context) { onReplacedLocalGoals() }

        let events = NotificationCenter.default.notifications(
            named: NSPersistentCloudKitContainer.eventChangedNotification
        )
        for await notification in events {
            guard
                let event = notification.userInfo?[
                    NSPersistentCloudKitContainer.eventNotificationUserInfoKey
                ] as? NSPersistentCloudKitContainer.Event,
                event.type == .import,
                event.endDate != nil,
                event.succeeded
            else { continue }
            if run(in: context) { onReplacedLocalGoals() }
        }
    }

    @discardableResult
    static func run(in context: ModelContext) -> Bool {
        mergeLists(in: context)
        let replacedLocalGoals = mergeUsers(in: context)
        mergeRecentLocations(in: context)
        mergeFavorites(in: context)
        mergeNotes(in: context)
        resolveOrderCollisions(in: context)

        guard context.hasChanges else { return false }
        do {
            try context.save()
            if replacedLocalGoals {
                UserDefaults.standard.removeObject(forKey: locallyCreatedUserKey)
            }
            return replacedLocalGoals
        } catch {
            context.rollback()
            return false
        }
    }

    private static func merge<Model: PersistentModel>(
        _ type: Model.Type,
        groupedBy key: (Model) -> String,
        id: (Model) -> UUID,
        in context: ModelContext,
        absorb: (_ survivor: Model, _ duplicate: Model) -> Void
    ) {
        let groups = Dictionary(grouping: live(type, in: context), by: key)
        for group in groups.values where group.count > 1 {
            let sorted = group.sorted { id($0).uuidString < id($1).uuidString }
            for duplicate in sorted.dropFirst() {
                absorb(sorted[0], duplicate)
                context.delete(duplicate)
            }
        }
    }

    private static func mergeLists(in context: ModelContext) {
        merge(EntrySource.self, groupedBy: \.source, id: \.id, in: context) { survivor, duplicate in
            for food in duplicate.foods ?? [] { food.source = survivor }
            for log in duplicate.logs ?? [] { log.source = survivor }
            duplicate.foods = []
            duplicate.logs = []
            survivor.isHidden = survivor.isHidden || duplicate.isHidden
        }
        merge(CategorySource.self, groupedBy: \.category, id: \.id, in: context) { survivor, duplicate in
            for food in duplicate.foods ?? [] { food.category = survivor }
            for log in duplicate.logs ?? [] { log.category = survivor }
            duplicate.foods = []
            duplicate.logs = []
            survivor.isHidden = survivor.isHidden || duplicate.isHidden
        }
        merge(FoodGroupSource.self, groupedBy: \.foodGroup, id: \.id, in: context) { survivor, duplicate in
            for food in duplicate.foods ?? [] { food.foodGroup = survivor }
            for log in duplicate.logs ?? [] { log.foodGroup = survivor }
            duplicate.foods = []
            duplicate.logs = []
            survivor.isHidden = survivor.isHidden || duplicate.isHidden
        }
        merge(ServingSizeUnit.self, groupedBy: \.unit, id: \.id, in: context) { survivor, duplicate in
            for food in duplicate.foods ?? [] { food.servingUnit = survivor }
            duplicate.foods = []
            if survivor.pluralVariant == nil {
                survivor.pluralVariant = duplicate.pluralVariant
            }
        }
    }

    private static func mergeUsers(in context: ModelContext) -> Bool {
        let users = live(User.self, in: context)
        guard users.count > 1 else { return false }

        let sorted = users.sorted { lhs, rhs in
            if lhs.onboardingComplete != rhs.onboardingComplete {
                return lhs.onboardingComplete
            }
            let lhsStart = firstGoalDate(of: lhs)
            let rhsStart = firstGoalDate(of: rhs)
            if lhsStart != rhsStart { return lhsStart < rhsStart }
            return lhs.id.uuidString < rhs.id.uuidString
        }
        let survivor = sorted[0]
        let locallyCreatedID = UserDefaults.standard.string(forKey: locallyCreatedUserKey)
        var replacedLocalGoals = false

        for duplicate in sorted.dropFirst() {
            if duplicate.id.uuidString == locallyCreatedID,
                !(duplicate.goalsHistory ?? []).isEmpty,
                !(survivor.goalsHistory ?? []).isEmpty
            {
                replacedLocalGoals = true
            }
            if (survivor.goalsHistory ?? []).isEmpty {
                for goals in duplicate.goalsHistory ?? [] { goals.owner = survivor }
                duplicate.goalsHistory = []
            }
            survivor.onboardingComplete = survivor.onboardingComplete || duplicate.onboardingComplete
            if survivor.name == nil { survivor.name = duplicate.name }
            context.delete(duplicate)
        }
        return replacedLocalGoals
    }

    private static func firstGoalDate(of user: User) -> Date {
        (user.goalsHistory ?? []).filter { !$0.isDeleted }.map(\.date).min() ?? .distantFuture
    }

    private static func mergeRecentLocations(in context: ModelContext) {
        let recents = live(RecentLocation.self, in: context).sorted {
            ($0.lastUsed, $1.id.uuidString) > ($1.lastUsed, $0.id.uuidString)
        }
        var kept: [RecentLocation] = []
        for recent in recents {
            if kept.contains(where: { RecentLocationStore.isSamePlace($0.location, recent.location) }) {
                context.delete(recent)
            } else {
                kept.append(recent)
            }
        }
    }

    private static func mergeFavorites(in context: ModelContext) {
        let favorites = live(FavoriteEntry.self, in: context).compactMap { favorite in
            favorite.foodItem.map { (food: $0.persistentModelID, favorite: favorite) }
        }
        let groups = Dictionary(grouping: favorites, by: \.food).mapValues { $0.map(\.favorite) }
        for group in groups.values where group.count > 1 {
            let sorted = group.sorted {
                ($0.orderIndex, $0.id.uuidString) < ($1.orderIndex, $1.id.uuidString)
            }
            guard let food = sorted[0].foodItem else { continue }
            for duplicate in sorted.dropFirst() {
                duplicate.foodItem = nil
                context.delete(duplicate)
            }
            sorted[0].foodItem = food
            food.favoriteEntry = sorted[0]
        }
    }

    private static func mergeNotes(in context: ModelContext) {
        let notes = live(Note.self, in: context).compactMap { note in
            note.foodItem.map { (food: $0.persistentModelID, note: note) }
        }
        let groups = Dictionary(grouping: notes, by: \.food).mapValues { $0.map(\.note) }
        for group in groups.values where group.count > 1 {
            let ordered = group.sorted {
                ($0.lastUpdated, $0.id.uuidString) < ($1.lastUpdated, $1.id.uuidString)
            }
            guard let survivor = group.min(by: { $0.id.uuidString < $1.id.uuidString }),
                let food = survivor.foodItem
            else { continue }

            var texts: [String] = []
            for note in ordered {
                let text = note.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty, !texts.contains(text) { texts.append(text) }
            }

            survivor.text = texts.joined(separator: "\n\n")
            survivor.lastUpdated = ordered.map(\.lastUpdated).max() ?? survivor.lastUpdated
            for duplicate in group where duplicate !== survivor {
                duplicate.foodItem = nil
                context.delete(duplicate)
            }
            survivor.foodItem = food
            food.stickyNote = survivor
        }
    }

    private static func resolveOrderCollisions(in context: ModelContext) {
        renumber(live(EntrySource.self, in: context), order: \.displayOrder) {
            ($0.source, $0.id.uuidString) < ($1.source, $1.id.uuidString)
        }
        renumber(live(CategorySource.self, in: context), order: \.displayOrder) {
            ($0.category, $0.id.uuidString) < ($1.category, $1.id.uuidString)
        }
        renumber(live(FoodGroupSource.self, in: context), order: \.displayOrder) {
            ($0.foodGroup, $0.id.uuidString) < ($1.foodGroup, $1.id.uuidString)
        }
        renumber(live(ServingSizeUnit.self, in: context), order: \.displayOrder) {
            ($0.unit, $0.id.uuidString) < ($1.unit, $1.id.uuidString)
        }
        let favorites = live(FavoriteEntry.self, in: context).filter { $0.foodItem != nil }
        renumber(favorites, order: \.orderIndex) {
            $0.id.uuidString < $1.id.uuidString
        }
        renumber(live(SavedLocation.self, in: context), order: \.displayOrder) {
            ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString)
        }
    }

    private static func renumber<Model: PersistentModel>(
        _ models: [Model],
        order: ReferenceWritableKeyPath<Model, Int>,
        tieBreak: (Model, Model) -> Bool
    ) {
        guard Set(models.map { $0[keyPath: order] }).count < models.count else { return }
        let sorted = models.sorted {
            $0[keyPath: order] != $1[keyPath: order]
                ? $0[keyPath: order] < $1[keyPath: order]
                : tieBreak($0, $1)
        }
        for (index, model) in sorted.enumerated() where model[keyPath: order] != index {
            model[keyPath: order] = index
        }
    }

    private static func live<Model: PersistentModel>(
        _ type: Model.Type,
        in context: ModelContext
    ) -> [Model] {
        ((try? context.fetch(FetchDescriptor<Model>())) ?? []).filter { !$0.isDeleted }
    }
}
