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
            FoodItemStore.toggleFavorite(food, in: modelContext)
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

    var body: some View {
        Group {
            if food.type == .recipe {
                LogRecipeView(recipe: food, isPushedView: false)
            } else {
                LogEntryView(food: food, isPushedView: false)
            }
        }
        .environment(\.rootDismiss, nil)
    }
}
