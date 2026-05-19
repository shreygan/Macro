//
//  IngredientSelectionSheetView.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/17/26.
//

import SwiftData
import SwiftUI

struct IngredientSelectionSheetView: View {
    @Environment(\.dismiss) var dismiss

    var onSelect: (FoodItem) -> Void

    @State private var searchText = ""

    @State private var activeSheet: ActiveSheet?
    enum ActiveSheet: Identifiable {
        case newIngredient, newFood, newRecipe
        var id: Int { hashValue }
    }

    // Querying items. You can refine this predicate if your SwiftData setup allows,
    // but filtering in memory handles the search text easily.
    @Query(sort: \FoodItem.dateAdded, order: .reverse) var allItems: [FoodItem]

    var filteredIngredients: [FoodItem] {
        allItems.filter { item in
            guard item.type == .ingredient else { return false }

            if searchText.isEmpty {
                return true
            } else {
                return item.name.localizedStandardContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()

                ScrollView {

                    Card("New Entry") {
                        RowGroup(.divider) {
                            ButtonRow(
                                icon: .appSymbol(.ingredient),
                                title: "Add New Ingredient",
                                bottomPadding: 2
                            ) {
                                activeSheet = .newIngredient
                            }

                            ButtonRow(
                                icon: .appSymbol(.food),
                                title: "Add New Food"
                            ) {
                                activeSheet = .newFood
                            }
                        }
                    }
                    .padding([.top, .leading, .trailing])

                    Card("Library") {
                        RowGroup(.divider) {
                            NavigationLink(
                                destination: LibrarySheetView(onSelect: {
                                    selectedFood in
                                    onSelect(selectedFood)
                                    dismiss()
                                })
                            ) {
                                NavigationRow(
                                    icon: .appSymbol(.food),
                                    title: "Foods"
                                )
                            }
                            .buttonStyle(.plain)

                            NavigationLink(
                                destination: LibrarySheetView(onSelect: {
                                    selectedRecipe in
                                    onSelect(selectedRecipe)
                                    dismiss()
                                })
                            ) {
                                NavigationRow(
                                    icon: .appSymbol(.recipe),
                                    title: "Recipes"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding([.top, .leading, .trailing])

                    if !filteredIngredients.isEmpty {
                        Card("Ingredients") {
                            RowGroup(.divider) {
                                ForEach(filteredIngredients) { ingredient in
                                    Button {
                                        onSelect(ingredient)
                                        dismiss()
                                    } label: {
                                        MealRow(
                                            name: ingredient.name,
                                            source: ingredient.source?
                                                .source ?? "None",
                                            isCustomDefaultServing:
                                                ingredient
                                                .isCustomDefaultServing,
                                            customServingSize:
                                                EntryHelper.format(
                                                    ingredient
                                                        .customServingSize
                                                ),
                                            servingSize: EntryHelper.format(
                                                ingredient.servingSize
                                            ),
                                            servingSizeUnit: ingredient
                                                .servingUnit?.unit
                                                ?? "serving",
                                            servingWeight:
                                                EntryHelper.format(
                                                    ingredient.servingWeight
                                                ),
                                            servingWeightUnit: ingredient
                                                .servingWeightUnit,
                                            servingUnits: [],
                                            calorie: EntryHelper.format(
                                                ingredient.calories
                                            ),
                                            protein: EntryHelper.format(
                                                ingredient.protein
                                            ),
                                            carbs: EntryHelper.format(
                                                ingredient.carbs
                                            ),
                                            fat: EntryHelper.format(
                                                ingredient.fat
                                            ),
                                            fiber: EntryHelper.format(
                                                ingredient.fiber
                                            )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding([.top, .leading, .trailing, .bottom])
                    } else if !searchText.isEmpty {
                        Text("No ingredients found for '\(searchText)'")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 20)
                    }
                }
            }
            .navigationTitle("Add Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search ingredients...")
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark").foregroundStyle(.primary)
                    }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .newIngredient:
                    AddEntrySheetView(entryType: .ingredient) {
                        newIngredient in
                        onSelect(newIngredient)
                        dismiss()
                    }
                case .newFood:
                    AddEntrySheetView(entryType: .food) { newFood in
                        onSelect(newFood)
                        dismiss()
                    }
                case .newRecipe:
                    AddRecipeSheetView { newRecipe in
                        onSelect(newRecipe)
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    do {
        // 1. Create a temporary, in-memory database just for the preview
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        // Note: Add any other models to this array if SwiftData complains,
        // e.g., EntrySource.self, CategorySource.self
        let container = try ModelContainer(
            for: FoodItem.self,
            configurations: config
        )

        // 2. Create Mock Ingredients
        let mockApple = FoodItem(
            name: "Honeycrisp Apple",
            type: .ingredient,
            servingSize: 1,
            servingWeight: 150,
            servingWeightUnit: "g",
            isAIEstimated: false,
            calories: 80,
            protein: 0.3,
            carbs: 22,
            fat: 0.2,
            fiber: 4.5,
            isCustomDefaultServing: false
        )

        let mockChicken = FoodItem(
            name: "Chicken Breast (Raw)",
            type: .ingredient,
            servingSize: 1,
            servingWeight: 112,
            servingWeightUnit: "g",
            isAIEstimated: false,
            calories: 120,
            protein: 26,
            carbs: 0,
            fat: 2,
            fiber: 0,
            isCustomDefaultServing: false
        )

        // 3. Create a Mock Food (To prove your filter works and hides it!)
        let mockProteinBar = FoodItem(
            name: "Quest Bar",
            type: .food,  // This is a food, so it shouldn't show up in the bottom list!
            servingSize: 1,
            servingWeight: 60,
            servingWeightUnit: "g",
            isAIEstimated: false,
            calories: 200,
            protein: 21,
            carbs: 22,
            fat: 8,
            fiber: 14,
            isCustomDefaultServing: false
        )

        // 4. Insert them into the preview context
        container.mainContext.insert(mockApple)
        container.mainContext.insert(mockChicken)
        container.mainContext.insert(mockProteinBar)

        // 5. Render the view with a simple print statement for the closure
        return IngredientSelectionSheetView { selectedItem in
            print("Preview User Selected: \(selectedItem.name)")
        }
        .modelContainer(container)  // Inject the mock database into the view

    } catch {
        return Text(
            "Failed to create preview database: \(error.localizedDescription)"
        )
    }
}
