//
//  DeleteFoodAlert.swift
//  Macro
//
//  Created by Shrey Gangwar on 9/30/26.
//

import SwiftData
import SwiftUI

struct DeleteFoodAlert: ViewModifier {
    @Environment(\.modelContext) private var modelContext

    @Binding var isPresented: Bool
    @Binding var food: FoodItem?

    func body(content: Content) -> some View {
        let usage = food.map { FoodItemStore.usage(of: $0, in: modelContext) }

        content
            .alert(
                "Delete Food",
                isPresented: $isPresented,
                presenting: food
            ) { food in
                Button("Cancel", role: .cancel) { self.food = nil }
                if (usage?.logCount ?? 0) == 0 {
                    Button("Delete", role: .destructive) {
                        delete(food, deletingLogs: false)
                    }
                } else {
                    Button("Keep Logs") {
                        delete(food, deletingLogs: false)
                    }
                    Button("Delete Logs", role: .destructive) {
                        delete(food, deletingLogs: true)
                    }
                }
            } message: { food in
                message(
                    for: food,
                    usage: usage ?? FoodItemUsage(logCount: 0, recipeCount: 0)
                )
            }
    }

    private func message(for food: FoodItem, usage: FoodItemUsage) -> Text {
        switch (usage.logCount, usage.recipeCount) {
        case (0, 0):
            return Text("Are you sure you want to delete \(food.name)?")
        case (0, _):
            return Text(
                "\(food.name) is used in ^[\(usage.recipeCount) recipe](inflect: true), which will keep their current values. Are you sure you want to delete it?"
            )
        case (_, 0):
            return Text(
                "\(food.name) has been logged ^[\(usage.logCount) time](inflect: true). Do you want to keep or delete those logs?"
            )
        default:
            return Text(
                "\(food.name) has been logged ^[\(usage.logCount) time](inflect: true) and is used in ^[\(usage.recipeCount) recipe](inflect: true), which will keep their current values. Do you want to keep or delete those logs?"
            )
        }
    }

    private func delete(_ food: FoodItem, deletingLogs: Bool) {
        self.food = nil
        DispatchQueue.main.async {
            FoodItemStore.delete(
                food,
                deletingLogs: deletingLogs,
                in: modelContext
            )
        }
    }
}

extension View {
    func deleteFoodAlert(
        isPresented: Binding<Bool>,
        food: Binding<FoodItem?>
    ) -> some View {
        modifier(DeleteFoodAlert(isPresented: isPresented, food: food))
    }
}
