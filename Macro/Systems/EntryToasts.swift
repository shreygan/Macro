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
        in context: ModelContext,
        presenter: ToastCenter?
    ) -> Toast {
        Toast(
            group: entryGroup,
            kind: .success,
            symbol: "arrow.triangle.merge",
            tint: .accentColor,
            title: String(localized: "Foods Merged"),
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
        return Toast(
            group: entryGroup,
            kind: .success,
            symbol: "checkmark",
            title: title,
            message: entry.name,
            messageDetail: String(localized: "\(EntryHelper.formatMacro(entry.calories)) kcal"),
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
                    .modelContext(context)
                    .textInputAutocapitalization(.never)
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

    static func favoriteToggled(
        _ food: FoodItem,
        previousOrder: Int?,
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
                        try FoodItemStore.toggleFavorite(food, in: context, at: previousOrder)
                    }
                } catch {
                    presenter?.show(
                        .failure(String(localized: "Couldn't Update Favorites"), message: food.name)
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
                presenter?.presentSheet(
                    LogFoodSheet(food: food)
                        .modelContext(context)
                        .textInputAutocapitalization(.never)
                )
            }
        )
    }
}

@MainActor
enum EntryActions {
    static func toggleFavorite(
        _ food: FoodItem,
        in context: ModelContext,
        toastCenter: ToastCenter?
    ) {
        do {
            let previousOrder = try FoodItemStore.toggleFavorite(food, in: context)
            toastCenter?.show(
                .favoriteToggled(
                    food,
                    previousOrder: previousOrder,
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

    static func delete(
        _ entry: LoggedEntry,
        in context: ModelContext,
        toastCenter: ToastCenter?
    ) {
        do {
            let record = try withAnimation {
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
            toastCenter?.show(.foodsMerged(record, in: context, presenter: toastCenter))
            return true
        } catch {
            toastCenter?.show(
                .failure(String(localized: "Couldn't Merge Foods"), message: plan.trimmedName)
            )
            return false
        }
    }

    static func delete(
        _ draft: EntryDraft,
        in context: ModelContext,
        toastCenter: ToastCenter?
    ) {
        do {
            let record = try withAnimation {
                try EntryDeleter.delete(draft, in: context)
            }
            guard let record else { return }
            toastCenter?.show(.draftDeleted(record, in: context, presenter: toastCenter))
        } catch {
            toastCenter?.show(.failure(String(localized: "Couldn't Delete Draft")))
        }
    }
}
