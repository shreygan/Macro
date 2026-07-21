//
//  ReorderFavoritesView.swift
//  Macro
//
//  Created by Shrey Gangwar on 7/20/26.
//

import SwiftData
import SwiftUI

struct ReorderFavoritesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \FavoriteEntry.orderIndex) private var favoriteEntries:
        [FavoriteEntry]

    @State private var editMode: EditMode = .active

    var body: some View {
        NavigationStack {
            List {
                ForEach(favoriteEntries) { entry in
                    if let food = entry.foodItem {
                        VStack(alignment: .leading) {
                            Text(food.name)
                                .font(.headline)
                            Text(food.source?.source ?? "None")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onMove(perform: moveItems)
                .onDelete(perform: deleteItems)
            }
            .listStyle(.automatic)
            .contentMargins(.top, 0)
            .environment(\.editMode, $editMode)
            .navigationTitle("Reorder Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        var orderedEntries = favoriteEntries
        orderedEntries.move(fromOffsets: source, toOffset: destination)

        for (index, entry) in orderedEntries.enumerated() {
            entry.orderIndex = index
        }

        try? modelContext.save()
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(favoriteEntries[index])
        }

        var orderedEntries = favoriteEntries
        orderedEntries.remove(atOffsets: offsets)
        for (index, entry) in orderedEntries.enumerated() {
            entry.orderIndex = index
        }

        try? modelContext.save()
    }
}

#Preview {
    let schema = Schema([FoodItem.self, FavoriteEntry.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    
    let context = container.mainContext
    
    let food1 = FoodItem(
        name: "Double Chicken Bowl",
        servingSize: 1.0,
        servingWeightUnit: "g",
        isAIEstimated: false,
        calories: 1050,
        protein: 85.0,
        carbs: 80.0,
        fat: 42.0,
        fiber: 15.0,
        isCustomDefaultServing: false
    )
    
    let food2 = FoodItem(
        name: "Protein Shake",
        servingSize: 1.0,
        servingWeightUnit: "g",
        isAIEstimated: false,
        calories: 160,
        protein: 30.0,
        carbs: 4.0,
        fat: 2.0,
        fiber: 1.0,
        isCustomDefaultServing: false
    )
    
    let food3 = FoodItem(
        name: "Paneer Paratha",
        servingSize: 1.0,
        servingWeightUnit: "g",
        isAIEstimated: false,
        calories: 350,
        protein: 12.0,
        carbs: 40.0,
        fat: 15.0,
        fiber: 4.0,
        isCustomDefaultServing: false
    )
    
    context.insert(food1)
    context.insert(food2)
    context.insert(food3)
    
    context.insert(FavoriteEntry(orderIndex: 0, foodItem: food1))
    context.insert(FavoriteEntry(orderIndex: 1, foodItem: food2))
    context.insert(FavoriteEntry(orderIndex: 2, foodItem: food3))
    
    return ReorderFavoritesView()
        .modelContainer(container)
}
