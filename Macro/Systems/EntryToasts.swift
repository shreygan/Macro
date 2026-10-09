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
            message: String(
                localized: "\(record.name) · \(EntryHelper.formatMacro(record.calories)) kcal"
            ),
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
            message: String(
                localized: "\(entry.name) · \(EntryHelper.formatMacro(entry.calories)) kcal"
            ),
            action: Toast.Action(title: String(localized: "Edit")) { [weak presenter] in
                guard !entry.isDeleted, entry.modelContext != nil else { return }
                presenter?.presentSheet(
                    NavigationStack {
                        LoggedEntryDetailView(entry: entry, isPushedView: false)
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
