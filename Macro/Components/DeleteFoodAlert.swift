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
    @Environment(\.toastCenter) private var toastCenter

    @Binding var food: FoodItem?
    var onWillDelete: (() -> Void)? = nil

    @State private var request: DeleteRequest?

    private struct DeleteRequest {
        let food: FoodItem
        let usage: FoodItemUsage
    }

    func body(content: Content) -> some View {
        content
            .alert(
                "Delete Food",
                isPresented: Binding(
                    get: { request != nil },
                    set: { presented in
                        guard !presented else { return }
                        request = nil
                        food = nil
                    }
                ),
                presenting: request
            ) { request in
                Button("Cancel", role: .cancel) {}
                if request.usage.logCount == 0 {
                    Button("Delete", role: .destructive) {
                        delete(request.food, deletingLogs: false)
                    }
                } else {
                    Button("Keep Logs") {
                        delete(request.food, deletingLogs: false)
                    }
                    Button("Delete Logs", role: .destructive) {
                        delete(request.food, deletingLogs: true)
                    }
                }
            } message: { request in
                message(for: request.food, usage: request.usage)
            }
            .onChange(of: food?.persistentModelID) {
                guard let food, request?.food !== food else { return }
                let usage = FoodItemStore.usage(of: food, in: modelContext)
                if usage.hasUses {
                    request = DeleteRequest(food: food, usage: usage)
                } else {
                    delete(food, deletingLogs: false)
                }
            }
    }

    private func message(for food: FoodItem, usage: FoodItemUsage) -> Text {
        var sentences: [AttributedString] = []

        switch (usage.logCount, usage.recipeCount) {
        case (0, 0):
            break
        case (0, _):
            sentences.append(
                AttributedString(
                    localized: "\(food.name) is used in ^[\(usage.recipeCount) recipe](inflect: true), which will keep their current values."
                )
            )
        case (_, 0):
            sentences.append(
                AttributedString(
                    localized: "\(food.name) has been logged ^[\(usage.logCount) time](inflect: true)."
                )
            )
        default:
            sentences.append(
                AttributedString(
                    localized: "\(food.name) has been logged ^[\(usage.logCount) time](inflect: true) and is used in ^[\(usage.recipeCount) recipe](inflect: true), which will keep their current values."
                )
            )
        }

        if usage.draftCount > 0 {
            if sentences.isEmpty {
                sentences.append(
                    AttributedString(
                        localized: "\(food.name) has ^[\(usage.draftCount) unfinished draft](inflect: true), which will be deleted with it."
                    )
                )
            } else if usage.logCount > 0 {
                sentences.append(
                    AttributedString(
                        localized: "Its ^[\(usage.draftCount) unfinished draft](inflect: true) will be deleted even if you keep its logs."
                    )
                )
            } else {
                sentences.append(
                    AttributedString(
                        localized: "Its ^[\(usage.draftCount) unfinished draft](inflect: true) will also be deleted."
                    )
                )
            }
        }

        sentences.append(
            usage.logCount > 0
                ? AttributedString(localized: "Do you want to keep or delete those logs?")
                : AttributedString(localized: "Are you sure you want to delete it?")
        )

        return Text(
            sentences.dropFirst().reduce(sentences[0]) { $0 + AttributedString(" ") + $1 }
        )
    }

    private func delete(_ food: FoodItem, deletingLogs: Bool) {
        self.food = nil
        onWillDelete?()
        DispatchQueue.main.async {
            do {
                guard
                    let record = try EntryDeleter.delete(
                        food,
                        deletingLogs: deletingLogs,
                        in: modelContext
                    )
                else { return }
                toastCenter?.show(.foodDeleted(record, in: modelContext, presenter: toastCenter))
            } catch {
                toastCenter?.show(
                    .failure(String(localized: "Couldn't Delete Food"), message: food.name)
                )
            }
        }
    }
}

extension View {
    func deleteFoodAlert(
        food: Binding<FoodItem?>,
        onWillDelete: (() -> Void)? = nil
    ) -> some View {
        modifier(
            DeleteFoodAlert(
                food: food,
                onWillDelete: onWillDelete
            )
        )
    }
}
