//
//  FoodActions.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/2/26.
//

import SwiftData
import SwiftUI

struct FoodActionMenuItems: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.toastCenter) private var toastCenter

    let food: FoodItem
    var onLog: (() -> Void)? = nil
    var onEdit: () -> Void
    var onDelete: () -> Void

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

        Button {
            EntryActions.toggleFavorite(food, in: modelContext, toastCenter: toastCenter)
        } label: {
            Label(
                isFavorited ? "Unfavorite" : "Favorite",
                systemImage: isFavorited ? "star.slash" : "star"
            )
        }

        Divider()

        Button(role: .destructive, action: onDelete) {
            Label("Delete \(typeName)", systemImage: "trash")
        }
    }
}

struct LogFoodSheet: View {
    let food: FoodItem
    var draft: EntryDraft? = nil

    var body: some View {
        Group {
            if food.type == .recipe {
                LogRecipeView(recipe: food, draft: draft, isPushedView: false)
            } else {
                LogEntryView(food: food, draft: draft, isPushedView: false)
            }
        }
        .environment(\.rootDismiss, nil)
    }
}
