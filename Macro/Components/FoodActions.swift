//
//  FoodActions.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/2/26.
//

import SwiftData
import SwiftUI

extension FoodItem {
    var viewActionTitle: String {
        isInLibrary
            ? String(localized: "View in Library")
            : String(localized: "View \(type.rawValue.capitalized)")
    }
}

struct FoodActionMenuItems: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.toastCenter) private var toastCenter
    @Environment(\.tracksHydration) private var tracksHydration

    let food: FoodItem
    var onLog: (() -> Void)? = nil
    var onEdit: () -> Void
    var onDuplicate: (() -> Void)? = nil
    var onMerge: (() -> Void)? = nil
    var onDelete: () -> Void

    private func togglePin() {
        if food.hydrationOrder == nil {
            FoodItem.pinToLogDrink(food, in: modelContext)
        } else {
            food.hydrationOrder = nil
        }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            toastCenter?.show(.failure(String(localized: "Couldn't Save Changes")))
        }
    }

    var body: some View {
        let typeName = food.type.rawValue.capitalized
        let isFavorited = food.favoriteEntry != nil

        if let onLog {
            Button(action: onLog) {
                Label("Log \(typeName)", systemImage: "plus")
            }
        }

        Button(action: onEdit) {
            Label("Edit \(typeName)", systemImage: "pencil")
        }

        if let onDuplicate {
            Button(action: onDuplicate) {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
        }

        Button {
            EntryActions.toggleFavorite(food, in: modelContext, toastCenter: toastCenter)
        } label: {
            Label(
                isFavorited ? "Unfavorite" : "Favorite",
                systemImage: isFavorited ? "star.slash" : "star"
            )
        }

        if food.seedKey != nil {
            Button {
                EntryActions.setInLibrary(
                    !food.isInLibrary,
                    for: food,
                    in: modelContext,
                    toastCenter: toastCenter
                )
            } label: {
                Label(
                    food.isInLibrary ? "Remove from Library" : "Add to Library",
                    systemImage: food.isInLibrary ? "minus.circle" : "plus.circle"
                )
            }
        }

        if tracksHydration, food.isLoggableDrink {
            let isPinned = food.hydrationOrder != nil
            Button(action: togglePin) {
                Label(
                    isPinned ? "Unpin Drink" : "Pin Drink",
                    systemImage: isPinned ? "pin.slash" : "pin"
                )
            }
        }

        if let onMerge, food.type != .recipe {
            Button(action: onMerge) {
                Label("Merge…", systemImage: "arrow.triangle.merge")
            }
        }

        Divider()

        Button(role: .destructive, action: onDelete) {
            Label("Delete \(typeName)", systemImage: "trash")
        }
    }
}

struct BuiltInMenuItems: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.toastCenter) private var toastCenter
    @Environment(\.tracksHydration) private var tracksHydration

    let food: FoodItem
    var onLog: () -> Void
    var onEdit: () -> Void

    private func storedFood() -> FoodItem? {
        do {
            return try BuiltInCatalog.stored(food, in: modelContext)
        } catch {
            toastCenter?.show(.failure(String(localized: "Couldn't Save Changes"), message: food.name))
            return nil
        }
    }

    private func togglePin() {
        guard let stored = storedFood() else { return }
        if stored.hydrationOrder == nil {
            FoodItem.pinToLogDrink(stored, in: modelContext)
        } else {
            stored.hydrationOrder = nil
        }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            toastCenter?.show(.failure(String(localized: "Couldn't Save Changes")))
        }
    }

    var body: some View {
        let typeName = food.type.rawValue.capitalized

        Button(action: onLog) {
            Label("Log \(typeName)", systemImage: "plus")
        }

        Button(action: onEdit) {
            Label("Edit \(typeName)", systemImage: "pencil")
        }

        Button {
            guard let stored = storedFood() else { return }
            EntryActions.toggleFavorite(stored, in: modelContext, toastCenter: toastCenter)
        } label: {
            Label("Favorite", systemImage: "star")
        }

        Button {
            EntryActions.addBuiltInToLibrary(food, in: modelContext, toastCenter: toastCenter)
        } label: {
            Label("Add to Library", systemImage: "plus.circle")
        }

        if tracksHydration, food.isLoggableDrink {
            let isPinned = food.hydrationOrder != nil
            Button(action: togglePin) {
                Label(
                    isPinned ? "Unpin Drink" : "Pin Drink",
                    systemImage: isPinned ? "pin.slash" : "pin"
                )
            }
        }
    }
}

struct LogFoodSheet: View {
    @Environment(\.tracksHydration) private var tracksHydration
    @Query private var users: [User]

    let food: FoodItem
    var draft: EntryDraft? = nil

    var body: some View {
        Group {
            if food.type == .recipe {
                LogRecipeView(recipe: food, draft: draft)
            } else if draft == nil, tracksHydration, food.isLoggableDrink {
                let dayStartMinutes = users.first?.dayStartMinutes ?? 0
                let today = Calendar.current.logicalDay(for: .now, dayStartMinutes: dayStartMinutes)
                LogDrinkSheet(
                    day: today,
                    dayStartMinutes: dayStartMinutes,
                    logicalToday: today,
                    drink: food,
                    focusesAmount: false
                )
            } else {
                LogEntryView(food: food, draft: draft)
            }
        }
        .environment(\.rootDismiss, nil)
    }
}

struct DuplicateFoodSheet: View {
    @Environment(\.volumeUnit) private var volumeUnit

    let food: FoodItem
    var offersLogNow = true
    var pinsDrink = false

    var body: some View {
        Group {
            if food.type == .recipe {
                AddRecipeView(
                    offersLogNow: offersLogNow,
                    prefill: food.duplicateRecipePrefill,
                    duplicateOf: food.id
                )
            } else {
                AddEntryView(
                    entryType: food.type,
                    offersLogNow: offersLogNow,
                    prefill: food.duplicatePrefill(
                        unit: volumeUnit,
                        pinsDrink: pinsDrink
                    ),
                    duplicateOf: food.id
                )
            }
        }
        .environment(\.rootDismiss, nil)
    }
}
