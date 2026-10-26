//
//  EntryToasts.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/8/26.
//

import SwiftData
import SwiftUI

extension Toast {
    static let entryGroup = "entry"

    static func failure(_ title: String, message: String? = nil) -> Toast {
        Toast(
            group: entryGroup,
            kind: .error,
            symbol: "xmark",
            tint: .red,
            title: title,
            message: message
        )
    }

    static func info(
        _ title: String,
        message: String? = nil,
        symbol: String = "info"
    ) -> Toast {
        Toast(
            group: entryGroup,
            kind: .info,
            symbol: symbol,
            tint: .secondary,
            title: title,
            message: message
        )
    }

    static func entryDeleted(
        _ record: MacroBackup.LogRecord,
        in context: ModelContext,
        presenter: ToastCenter?
    ) -> Toast {
        Toast(
            group: entryGroup,
            symbol: "trash",
            tint: .red,
            title: String(localized: "Entry Deleted"),
            message: record.name,
            messageDetail: String(localized: "\(EntryHelper.formatMacro(record.calories)) kcal"),
            action: Toast.Action(title: String(localized: "Undo")) { [weak presenter] in
                do {
                    try withAnimation {
                        try EntryDeleter.restore(record, in: context)
                    }
                } catch {
                    presenter?.show(
                        .failure(String(localized: "Couldn't Restore Entry"), message: record.name)
                    )
                }
            }
        )
    }

    static func draftDeleted(
        _ record: MacroBackup.DraftRecord,
        in context: ModelContext,
        presenter: ToastCenter?
    ) -> Toast {
        let typeName = EntryType(rawValue: record.typeRawValue)?.rawValue.capitalized ?? "Entry"
        let name = record.name.isEmpty ? String(localized: "New \(typeName)") : record.name
        return Toast(
            group: entryGroup,
            symbol: "trash",
            tint: .red,
            title: String(localized: "Draft Deleted"),
            message: name,
            action: Toast.Action(title: String(localized: "Undo")) { [weak presenter] in
                do {
                    try withAnimation {
                        try EntryDeleter.restore(record, in: context)
                    }
                } catch {
                    presenter?.show(
                        .failure(String(localized: "Couldn't Restore Draft"), message: name)
                    )
                }
            }
        )
    }

    static func draftSaved(
        id: UUID,
        name: String,
        in context: ModelContext,
        presenter: ToastCenter?
    ) -> Toast {
        Toast(
            group: entryGroup,
            symbol: "square.and.arrow.down",
            tint: .secondary,
            title: String(localized: "Draft Saved"),
            message: name,
            action: Toast.Action(title: String(localized: "Discard")) { [weak presenter] in
                do {
                    let record = try withAnimation {
                        try EntryDeleter.deleteDraft(id: id, in: context)
                    }
                    guard let record else { return }
                    presenter?.show(.draftDeleted(record, in: context, presenter: presenter))
                } catch {
                    presenter?.show(.failure(String(localized: "Couldn't Delete Draft")))
                }
            }
        )
    }

    static func foodDeleted(
        _ record: DeletedFoodRecord,
        in context: ModelContext,
        presenter: ToastCenter?
    ) -> Toast {
        Toast(
            group: entryGroup,
            symbol: "trash",
            tint: .red,
            title: String(localized: "Deleted from Library"),
            message: record.food.name,
            action: Toast.Action(title: String(localized: "Undo")) { [weak presenter] in
                do {
                    try withAnimation {
                        try EntryDeleter.restore(record, in: context)
                    }
                } catch {
                    presenter?.show(
                        .failure(String(localized: "Couldn't Restore Food"), message: record.food.name)
                    )
                }
            }
        )
    }

    static func foodsMerged(
        _ record: FoodMergeRecord,
        title: String = String(localized: "Foods Merged"),
        in context: ModelContext,
        presenter: ToastCenter?
    ) -> Toast {
        Toast(
            group: entryGroup,
            kind: .success,
            symbol: "arrow.triangle.merge",
            tint: .accentColor,
            title: title,
            message: record.mergedName,
            action: Toast.Action(title: String(localized: "Undo")) { [weak presenter] in
                do {
                    try withAnimation {
                        try FoodMerger.restore(record, in: context)
                    }
                } catch {
                    presenter?.show(
                        .failure(String(localized: "Couldn't Undo Merge"), message: record.mergedName)
                    )
                }
            }
        )
    }

    static func listItemDeleted(
        _ record: DeletedListItemRecord,
        in context: ModelContext,
        presenter: ToastCenter?
    ) -> Toast {
        Toast(
            group: entryGroup,
            symbol: "trash",
            tint: .red,
            title: String(localized: "\(record.kind.itemName) Deleted"),
            message: record.name,
            action: Toast.Action(title: String(localized: "Undo")) { [weak presenter] in
                do {
                    try withAnimation {
                        try LibraryListStore.restore(record, in: context)
                    }
                } catch {
                    presenter?.show(
                        .failure(
                            String(localized: "Couldn't Restore \(record.kind.itemName)"),
                            message: record.name
                        )
                    )
                }
            }
        )
    }

    static func savedLocationDeleted(
        _ record: DeletedSavedLocationRecord,
        in context: ModelContext,
        presenter: ToastCenter?
    ) -> Toast {
        Toast(
            group: entryGroup,
            symbol: "trash",
            tint: .red,
            title: String(localized: "Saved Location Deleted"),
            message: record.name,
            action: Toast.Action(title: String(localized: "Undo")) { [weak presenter] in
                do {
                    try withAnimation {
                        try SavedLocation.restore(record, in: context)
                    }
                } catch {
                    presenter?.show(
                        .failure(String(localized: "Couldn't Restore Location"), message: record.name)
                    )
                }
            }
        )
    }

    static func entryLogged(
        _ record: LogUndoRecord,
        title: String,
        in context: ModelContext,
        presenter: ToastCenter
    ) -> Toast {
        let entry = record.entry
        let name = entry.name
        let isDrink = entry.entryType == .drink && entry.volumeML > 0
        let unit = (try? context.fetch(FetchDescriptor<User>()))?.first?.volumeUnit ?? .localeDefault
        return Toast(
            group: entryGroup,
            kind: .success,
            symbol: "checkmark",
            title: title,
            message: isDrink ? [entry.name, entry.sizeName].compactMap(\.self).joined(separator: " · ") : entry.name,
            messageDetail: isDrink
                ? unit.formattedAmount(entry.volumeML)
                : String(localized: "\(EntryHelper.formatMacro(entry.calories)) kcal"),
            location: {
                guard !entry.isDeleted, entry.modelContext != nil, !entry.needsLocationName
                else { return nil }
                return entry.locationName
            },
            action: Toast.Action(title: String(localized: "Edit")) { [weak presenter] in
                guard !entry.isDeleted, entry.modelContext != nil else { return }
                presenter?.presentSheet(
                    NavigationStack {
                        LoggedEntryDetailView(
                            entry: entry,
                            isPushedView: false,
                            startsEditing: true
                        )
                    }
                    .textInputAutocapitalization(.never),
                    in: context
                )
            },
            secondaryAction: Toast.Action(title: String(localized: "Undo")) { [weak presenter] in
                do {
                    try withAnimation {
                        try QuickLogger.undo(record, in: context)
                    }
                } catch {
                    presenter?.show(
                        .failure(String(localized: "Couldn't Undo Log"), message: name)
                    )
                }
            }
        )
    }

    static func hydrationLogged(
        _ entry: LoggedEntry,
        originalDrink: MacroBackup.FoodRecord? = nil,
        title: String,
        unit: VolumeUnit,
        in context: ModelContext,
        presenter: ToastCenter
    ) -> Toast {
        let name = entry.name
        return Toast(
            group: entryGroup,
            kind: .success,
            symbol: "checkmark",
            title: title,
            message: [entry.name, entry.sizeName].compactMap(\.self).joined(separator: " · "),
            messageDetail: unit.formattedAmount(entry.volumeML),
            action: Toast.Action(title: String(localized: "Edit")) { [weak presenter] in
                guard !entry.isDeleted, entry.modelContext != nil else { return }
                presenter?.presentSheet(
                    LogDrinkSheet(editing: entry),
                    in: context,
                    detents: [.medium()]
                )
            },
            secondaryAction: Toast.Action(title: String(localized: "Undo")) { [weak presenter] in
                do {
                    try withAnimation {
                        try QuickLogger.undo(LogUndoRecord(entry: entry, originalFood: originalDrink), in: context)
                    }
                } catch {
                    presenter?.show(
                        .failure(String(localized: "Couldn't Undo Log"), message: name)
                    )
                }
            }
        )
    }

    static func favoriteToggled(
        _ food: FoodItem,
        previousOrder: Int?,
        wasInLibrary: Bool = true,
        in context: ModelContext,
        presenter: ToastCenter?
    ) -> Toast {
        let isFavorited = food.favoriteEntry != nil
        return Toast(
            group: entryGroup,
            kind: isFavorited ? .success : .info,
            symbol: isFavorited ? "star.fill" : "star.slash",
            tint: .yellow,
            title: isFavorited
                ? String(localized: "Added to Favorites")
                : String(localized: "Removed from Favorites"),
            message: food.name,
            action: Toast.Action(title: String(localized: "Undo")) { [weak presenter] in
                guard !food.isDeleted, food.modelContext != nil,
                    (food.favoriteEntry != nil) == isFavorited
                else { return }
                do {
                    _ = try withAnimation {
                        food.isInLibrary = wasInLibrary
                        return try FoodItemStore.toggleFavorite(food, in: context, at: previousOrder)
                    }
                } catch {
                    presenter?.show(
                        .failure(String(localized: "Couldn't Update Favorites"), message: food.name)
                    )
                }
            }
        )
    }

    static func libraryMembershipChanged(
        _ food: FoodItem,
        previousFavoriteOrder: Int?,
        in context: ModelContext,
        presenter: ToastCenter?
    ) -> Toast {
        let isInLibrary = food.isInLibrary
        return Toast(
            group: entryGroup,
            kind: isInLibrary ? .success : .info,
            symbol: isInLibrary ? "plus.circle" : "minus.circle",
            title: isInLibrary
                ? String(localized: "Added to Library")
                : String(localized: "Removed from Library"),
            message: food.name,
            action: Toast.Action(title: String(localized: "Undo")) { [weak presenter] in
                guard !food.isDeleted, food.modelContext != nil,
                    food.isInLibrary == isInLibrary
                else { return }
                do {
                    _ = try withAnimation {
                        try FoodItemStore.setInLibrary(
                            !isInLibrary,
                            for: food,
                            restoringFavoriteAt: previousFavoriteOrder,
                            in: context
                        )
                    }
                } catch {
                    presenter?.show(
                        .failure(String(localized: "Couldn't Update Library"), message: food.name)
                    )
                }
            }
        )
    }

    static func foodSaved(
        _ food: FoodItem,
        title: String = String(localized: "Saved to Library"),
        in context: ModelContext,
        presenter: ToastCenter
    ) -> Toast {
        Toast(
            group: entryGroup,
            kind: .success,
            symbol: "checkmark",
            title: title,
            message: food.name,
            action: Toast.Action(title: String(localized: "Log Now")) { [weak presenter] in
                guard !food.isDeleted, food.modelContext != nil else { return }
                let tracksHydration = (try? context.fetch(FetchDescriptor<User>()))?.first?.tracksHydration ?? true
                presenter?.presentSheet(
                    LogFoodSheet(food: food)
                        .textInputAutocapitalization(.never),
                    in: context,
                    detents: tracksHydration && food.isLoggableDrink ? [.medium()] : nil
                )
            }
        )
    }
}

extension Transaction {
    @Entry var isMenuDelete = false
}

@MainActor
enum EntryActions {
    private static func deleteTransaction(fromMenu: Bool) -> Transaction {
        var transaction = Transaction(animation: .default)
        transaction.isMenuDelete = fromMenu
        return transaction
    }

    static func toggleFavorite(
        _ food: FoodItem,
        in context: ModelContext,
        toastCenter: ToastCenter?
    ) {
        let wasInLibrary = food.isInLibrary
        do {
            let previousOrder = try FoodItemStore.toggleFavorite(food, in: context)
            toastCenter?.show(
                .favoriteToggled(
                    food,
                    previousOrder: previousOrder,
                    wasInLibrary: wasInLibrary,
                    in: context,
                    presenter: toastCenter
                )
            )
        } catch {
            toastCenter?.show(
                .failure(String(localized: "Couldn't Update Favorites"), message: food.name)
            )
        }
    }

    static func addBuiltInToLibrary(
        _ food: FoodItem,
        in context: ModelContext,
        toastCenter: ToastCenter?
    ) {
        do {
            let stored = try BuiltInCatalog.stored(food, in: context)
            setInLibrary(true, for: stored, in: context, toastCenter: toastCenter)
        } catch {
            toastCenter?.show(
                .failure(String(localized: "Couldn't Update Library"), message: food.name)
            )
        }
    }

    static func setInLibrary(
        _ isInLibrary: Bool,
        for food: FoodItem,
        in context: ModelContext,
        toastCenter: ToastCenter?
    ) {
        do {
            let previousOrder = try withAnimation {
                try FoodItemStore.setInLibrary(isInLibrary, for: food, in: context)
            }
            toastCenter?.show(
                .libraryMembershipChanged(
                    food,
                    previousFavoriteOrder: previousOrder,
                    in: context,
                    presenter: toastCenter
                )
            )
        } catch {
            toastCenter?.show(
                .failure(String(localized: "Couldn't Update Library"), message: food.name)
            )
        }
    }

    static func delete(
        _ entry: LoggedEntry,
        in context: ModelContext,
        toastCenter: ToastCenter?,
        fromMenu: Bool = false
    ) {
        do {
            let record = try withTransaction(deleteTransaction(fromMenu: fromMenu)) {
                try EntryDeleter.delete(entry, in: context)
            }
            guard let record else { return }
            toastCenter?.show(.entryDeleted(record, in: context, presenter: toastCenter))
        } catch {
            toastCenter?.show(
                .failure(String(localized: "Couldn't Delete Entry"), message: entry.name)
            )
        }
    }

    static func opensAsHydrationLog(_ entry: LoggedEntry, tracksHydration: Bool) -> Bool {
        entry.isHydrationLog && tracksHydration
    }

    static func canLogAgain(_ entry: LoggedEntry, tracksHydration: Bool = true) -> Bool {
        guard let food = entry.originalFoodItem else { return false }
        return !opensAsHydrationLog(entry, tracksHydration: tracksHydration)
            || (food.isLoggableDrink && entry.volumeML > 0)
    }

    static func logHydrationAgain(
        _ entry: LoggedEntry,
        dayStartMinutes: Int,
        unit: VolumeUnit,
        in context: ModelContext,
        toastCenter: ToastCenter?
    ) {
        guard let drink = entry.originalFoodItem, drink.isLoggableDrink, entry.volumeML > 0 else { return }
        let timestamp = Date.now
        let today = Calendar.current.logicalDay(for: timestamp, dayStartMinutes: dayStartMinutes)
        let goalFeedback = WaterGoalFeedback(at: timestamp, in: context)
        do {
            let logged = try withAnimation {
                try HydrationLogger.log(
                    drink,
                    volumeML: entry.volumeML,
                    sizeName: HydrationLogger.sizeName(for: drink, volumeML: entry.volumeML),
                    at: timestamp,
                    in: context
                )
            }
            goalFeedback.playIfReached()
            if let toastCenter {
                toastCenter.show(
                    .hydrationLogged(
                        logged,
                        title: HydrationLogger.loggedTitle(forDay: today, logicalToday: today),
                        unit: unit,
                        in: context,
                        presenter: toastCenter
                    )
                )
            }
        } catch {
            toastCenter?.show(.failure(String(localized: "Couldn't Log Drink"), message: drink.name))
        }
    }

    @discardableResult
    static func merge(
        _ plan: FoodMergePlan,
        in context: ModelContext,
        toastCenter: ToastCenter?
    ) -> Bool {
        do {
            let record = try withAnimation {
                try FoodMerger.merge(plan, in: context)
            }
            guard let record else { return false }
            let title = plan.kept.type == .drink
                ? String(localized: "Drinks Merged") : String(localized: "Foods Merged")
            toastCenter?.show(.foodsMerged(record, title: title, in: context, presenter: toastCenter))
            return true
        } catch {
            toastCenter?.show(
                .failure(
                    plan.kept.type == .drink
                        ? String(localized: "Couldn't Merge Drinks") : String(localized: "Couldn't Merge Foods"),
                    message: plan.trimmedName
                )
            )
            return false
        }
    }

    static func delete(
        _ draft: EntryDraft,
        in context: ModelContext,
        toastCenter: ToastCenter?,
        fromMenu: Bool = false
    ) {
        do {
            let record = try withTransaction(deleteTransaction(fromMenu: fromMenu)) {
                try EntryDeleter.delete(draft, in: context)
            }
            guard let record else { return }
            toastCenter?.show(.draftDeleted(record, in: context, presenter: toastCenter))
        } catch {
            toastCenter?.show(.failure(String(localized: "Couldn't Delete Draft")))
        }
    }
}
