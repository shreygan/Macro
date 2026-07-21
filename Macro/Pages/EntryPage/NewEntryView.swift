//
//  NewEntryView.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/3/26.
//

import SwiftData
import SwiftUI

struct NewEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss

    @Query(sort: \FavoriteEntry.orderIndex) private var favoriteEntries:
        [FavoriteEntry]
    @Query(sort: \ServingSizeUnit.displayOrder) private var portionUnitOptions:
        [ServingSizeUnit]

    @State private var searchText = ""

    @State private var showAddIngredientSheet = false
    @State private var showAddFoodSheet = false
    @State private var showAddRecipeSheet = false
    @State private var foodToLog: FoodItem? = nil
    @State private var recipeToLog: FoodItem? = nil

    @State private var showDeleteAlert = false
    @State private var foodToDelete: FoodItem?
    @State private var showEditSheet = false
    @State private var foodToEdit: FoodItem?
    
    @State private var showReorderFavoritesSheet = false

    @ViewBuilder
    private func foodRow(for food: FoodItem) -> some View {
        let displayPortion =
            (food.isCustomDefaultServing && food.customServingSize != nil)
            ? food.customServingSize! : food.servingSize
        let multiplier = EntryHelper.calculateMultiplier(
            targetPortion: displayPortion,
            basePortion: food.servingSize
        )

        MealRow(
            name: food.name,
            source: food.source?.source ?? "None",
            isCustomDefaultServing: food.isCustomDefaultServing,
            customServingSize: EntryHelper.format(food.customServingSize),
            servingSize: EntryHelper.format(displayPortion),
            servingSizeUnit: food.servingUnit?.unit ?? "serving",
            servingWeight: EntryHelper.format(food.servingWeight),
            servingWeightUnit: food.servingWeightUnit,
            servingUnits: portionUnitOptions,
            calorie: EntryHelper.scale(
                EntryHelper.format(food.calories),
                by: multiplier
            ),
            protein: EntryHelper.scale(
                EntryHelper.format(food.protein),
                by: multiplier
            ),
            carbs: EntryHelper.scale(
                EntryHelper.format(food.carbs),
                by: multiplier
            ),
            fat: EntryHelper.scale(
                EntryHelper.format(food.fat),
                by: multiplier
            ),
            fiber: EntryHelper.scale(
                EntryHelper.format(food.fiber),
                by: multiplier
            ),
            icon: food.type.appSymbol
        ) {
            if food.type == .recipe {
                recipeToLog = food
            } else {
                foodToLog = food
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()

                ScrollView {
                    VStack {
                        Card("New Entry") {
                            ButtonRow(
                                icon: .appSymbol(.ingredient),
                                title: "Add Ingredient",
                                bottomPadding: 2
                            ) {
                                showAddIngredientSheet = true
                            }
                            ButtonRow(
                                icon: .appSymbol(.food),
                                title: "Add Food",
                                bottomPadding: 2
                            ) {
                                showAddFoodSheet = true
                            }
                            ButtonRow(
                                icon: .appSymbol(.recipe),
                                title: "Add Recipe",
                            ) {
                                showAddRecipeSheet = true
                            }
                        }
                        .padding([.leading, .trailing])

                        Card("Library") {
                            RowGroup(.divider) {
                                NavigationLink(
                                    destination: LibraryView(
                                        defaultType: .all
                                    )
                                ) {
                                    NavigationRow(
                                        icon: .appSymbol(.all),
                                        title: "All Entries"
                                    )
                                }
                                .buttonStyle(.plain)

                                NavigationLink(
                                    destination: LibraryView(
                                        defaultType: .specific(.ingredient)
                                    )
                                ) {
                                    NavigationRow(
                                        icon: .appSymbol(.ingredient),
                                        title: "Ingredients"
                                    )
                                }
                                .buttonStyle(.plain)

                                NavigationLink(
                                    destination: LibraryView(
                                        defaultType: .specific(.food)
                                    )
                                ) {
                                    NavigationRow(
                                        icon: .appSymbol(.food),
                                        title: "Foods"
                                    )
                                }
                                .buttonStyle(.plain)

                                NavigationLink(
                                    destination: LibraryView(
                                        defaultType: .specific(.recipe)
                                    )
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

                        Card("Favorites", titleBottomPadding: -4) {
                            let favoritedFoods = favoriteEntries.compactMap {
                                $0.foodItem
                            }

                            if favoritedFoods.isEmpty {
                                Text("No favorites yet.")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .padding()
                            } else {
                                EntryList(
                                    items: favoritedFoods,
                                    allowSwipeActions: true,
                                    showCard: false,
                                    rowContent: { food in
                                        foodRow(for: food)
                                    },
                                    onEdit: { food in
                                        foodToEdit = food
                                        showEditSheet = true
                                    },
                                    onFavorite: { food in
                                        if let entry = food.favoriteEntry {
                                            modelContext.delete(entry)
                                            try? modelContext.save()
                                        }
                                    },
                                    isFavorited: { food in
                                        food.favoriteEntry != nil
                                    }
                                )
                            }
                        } menuItems: {
                            Button {
                                showReorderFavoritesSheet = true
                            } label: {
                                Label("Reorder Favorites", systemImage: "arrow.up.arrow.down")
                            }
                        }
                        .padding([.top, .leading, .trailing])

                        Spacer()
                    }
                }
                .navigationTitle("New Entry")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(
                    text: $searchText,
                    prompt: "What did you eat today?"
                )
                .searchDictationBehavior(.automatic)
                .searchPresentationToolbarBehavior(.avoidHidingContent)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddIngredientSheet) {
            AddEntryView(
                entryType: .ingredient,
                onLogInstantly: { savedFood in
                    self.foodToLog = savedFood
                }
            )
        }
        .sheet(isPresented: $showAddFoodSheet) {
            AddEntryView(
                entryType: .food,
                onLogInstantly: { savedFood in
                    self.foodToLog = savedFood
                }
            )
        }
        .sheet(isPresented: $showAddRecipeSheet) {
            AddRecipeView(onLogInstantly: { savedRecipe in
                self.recipeToLog = savedRecipe

            })
        }
        .sheet(item: $foodToLog) { food in
            LogEntryView(food: food, isPushedView: false)
        }
        .sheet(item: $recipeToLog) { recipe in
            LogRecipeView(recipe: recipe, isPushedView: false)
        }
        .sheet(item: $foodToEdit) { food in
            if food.type == .recipe {
                EditRecipeView(recipe: food)
            } else {
                EditEntryView(foodItem: food)
            }
        }
        .sheet(isPresented: $showReorderFavoritesSheet) {
            ReorderFavoritesView()
        }
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: FoodItem.self,
            FavoriteEntry.self,
            ServingSizeUnit.self,
            configurations: config
        )
        let context = container.mainContext

        let food1 = FoodItem(
            name: "Oatmeal",
            servingSize: 1.0,
            servingWeight: 40.0,
            servingWeightUnit: "g",
            isAIEstimated: false,
            calories: 150.0,
            protein: 5.0,
            carbs: 27.0,
            fat: 2.5,
            fiber: 4.0,
            isCustomDefaultServing: false
        )

        let food2 = FoodItem(
            name: "Scrambled Eggs",
            servingSize: 2.0,
            servingWeight: 100.0,
            servingWeightUnit: "g",
            isAIEstimated: false,
            calories: 140.0,
            protein: 12.0,
            carbs: 1.0,
            fat: 10.0,
            fiber: 0.0,
            isCustomDefaultServing: false
        )

        context.insert(food1)
        context.insert(food2)

        let favorite1 = FavoriteEntry(orderIndex: 0, foodItem: food1)
        let favorite2 = FavoriteEntry(orderIndex: 1, foodItem: food2)

        food1.favoriteEntry = favorite1
        food2.favoriteEntry = favorite2

        context.insert(favorite1)
        context.insert(favorite2)

        return NavigationStack {
            NewEntryView()
        }
        .modelContainer(container)

    } catch {
        return Text(
            "Failed to create preview container: \(error.localizedDescription)"
        )
    }
}
