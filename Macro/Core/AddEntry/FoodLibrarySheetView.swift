//
//  FoodLibrarySheetView.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/12/26.
//

import SwiftData
import SwiftUI

enum FoodSortOption {
    case name
    case dateAdded
    case calories
    case protein
    case carbs
    case fat
    case fiber
}

struct FoodLibrarySheetView: View {
    @Environment(\.dismiss) var dismiss

    @Query(sort: \FoodItem.dateAdded, order: .reverse) var savedMeals:
        [FoodItem]

    @Query(sort: \ServingSizeUnit.displayOrder) var portionUnitOptions:
        [ServingSizeUnit]

    @State private var selectedFood: FoodItem?
    @State private var searchText = ""

    @State private var sortOption: FoodSortOption = .name
    @State private var sortDescending: Bool = true

    @State private var showFilterSheet = false
    @State private var selectedSources: Set<String> = []
    @State private var selectedCategories: Set<String> = []

    var filteredMeals: [FoodItem] {
        // 1. Filter by search text
        var result =
            searchText.isEmpty
            ? savedMeals
            : savedMeals.filter { food in
                food.name.localizedStandardContains(searchText)
            }

        // 2. Filter by Source
        // If the set is empty, we assume no filter is applied (show all).
        if !selectedSources.isEmpty {
            result = result.filter { food in
                guard let sourceName = food.source?.source else { return false }
                return selectedSources.contains(sourceName)
            }
        }

        // 3. Filter by Category
        if !selectedCategories.isEmpty {
            result = result.filter { food in
                guard let categoryName = food.category?.category else {
                    return false
                }
                return selectedCategories.contains(categoryName)
            }
        }

        // 4. Sort the filtered results
        return result.sorted { lhs, rhs in
            switch sortOption {
            case .name:
                return lhs.name.localizedStandardCompare(rhs.name)
                    == .orderedAscending
            case .dateAdded:
                return sortDescending
                    ? lhs.dateAdded > rhs.dateAdded
                    : lhs.dateAdded < rhs.dateAdded
            case .calories:
                return sortDescending
                    ? lhs.calories > rhs.calories : lhs.calories < rhs.calories
            case .protein:
                return sortDescending
                    ? lhs.protein > rhs.protein : lhs.protein < rhs.protein
            case .carbs:
                return sortDescending
                    ? lhs.carbs > rhs.carbs : lhs.carbs < rhs.carbs
            case .fat:
                return sortDescending ? lhs.fat > rhs.fat : lhs.fat < rhs.fat
            case .fiber:
                return sortDescending
                    ? lhs.fiber > rhs.fiber : lhs.fiber < rhs.fiber
            }
        }
    }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            ScrollView {
                Card {
                    RowGroup(.divider) {
                        ForEach(filteredMeals) { food in

                            let displayPortion =
                                (food.isCustomDefaultServing
                                    && food.customServingSize != nil)
                                ? food.customServingSize!
                                : food.servingSize

                            let multiplier =
                                EntryHelper.calculateMultiplier(
                                    targetPortion: displayPortion,
                                    basePortion: food.servingSize
                                )

                            let baseCalStr = EntryHelper.format(
                                food.calories
                            )
                            let baseProStr = EntryHelper.format(
                                food.protein
                            )
                            let baseCarbsStr = EntryHelper.format(
                                food.carbs
                            )
                            let baseFatStr = EntryHelper.format(food.fat)
                            let baseFiberStr = EntryHelper.format(
                                food.fiber
                            )

                            MealRow(
                                name: food.name,
                                source: food.source?.source ?? "None",
                                isCustomDefaultServing: food
                                    .isCustomDefaultServing,
                                customServingSize: EntryHelper.format(
                                    food.customServingSize
                                ),
                                servingSize: EntryHelper.format(
                                    displayPortion
                                ),
                                servingSizeUnit: food.servingUnit?.unit
                                    ?? "serving",
                                servingWeight: EntryHelper.format(
                                    food.servingWeight
                                ),
                                servingWeightUnit: food.servingWeightUnit,
                                servingUnits: portionUnitOptions,

                                calorie: EntryHelper.scale(
                                    baseCalStr,
                                    by: multiplier
                                ),
                                protein: EntryHelper.scale(
                                    baseProStr,
                                    by: multiplier
                                ),
                                carbs: EntryHelper.scale(
                                    baseCarbsStr,
                                    by: multiplier
                                ),
                                fat: EntryHelper.scale(
                                    baseFatStr,
                                    by: multiplier
                                ),
                                fiber: EntryHelper.scale(
                                    baseFiberStr,
                                    by: multiplier
                                )
                            ) {
                                selectedFood = food
                            }
                        }
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Food Library")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                prompt: "What did you eat today?"
            )
            .searchDictationBehavior(.automatic)
            .searchPresentationToolbarBehavior(.avoidHidingContent)
            .sheet(item: $selectedFood) { foodToLog in
                LogFoodSheetView(food: foodToLog)
            }
            .sheet(isPresented: $showFilterSheet) {
                FoodFilterSheetView(
                    selectedSources: $selectedSources,
                    selectedCategories: $selectedCategories
                )
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {

                    Button {
                        showFilterSheet = true
                    } label: {
                        let hasFilters =
                            !selectedSources.isEmpty
                            || !selectedCategories.isEmpty
                        Image(
                            systemName: hasFilters
                                ? "line.3.horizontal.decrease.circle.fill"
                                : "line.3.horizontal.decrease.circle"
                        )
                        .tint(.primary)
                    }

                    Menu {
                        Picker("Sort By", selection: $sortOption) {
                            Text("Name").tag(FoodSortOption.name)
                            Text("Date Added").tag(FoodSortOption.dateAdded)
                            Text("Calories").tag(FoodSortOption.calories)
                            Text("Protein").tag(FoodSortOption.protein)
                            Text("Carbohydrates").tag(FoodSortOption.carbs)
                            Text("Fat").tag(FoodSortOption.fat)
                            Text("Fiber").tag(FoodSortOption.fiber)
                        }

                        if sortOption != .name {
                            Divider()

                            Picker("Order", selection: $sortDescending) {
                                if sortOption == .dateAdded {
                                    Text("Newest First").tag(true)
                                    Text("Oldest First").tag(false)
                                } else {
                                    Text("Highest First").tag(true)
                                    Text("Lowest First").tag(false)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
            }
        }
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)

        let container = try ModelContainer(
            for: FoodItem.self,
            ServingSizeUnit.self,
            configurations: config
        )

        let sampleFoods = [
            FoodItem(
                name: "Chicken Breast",
                servingSize: 1.0,
                servingWeight: 100,
                servingWeightUnit: "g",
                isIngredientBased: false,
                isAIEstimated: false,
                calories: 165,
                protein: 31,
                carbs: 0,
                fat: 3.6,
                fiber: 0.4,
                isCustomDefaultServing: false
            ),
            FoodItem(
                name: "Brown Rice",
                servingSize: 1.0,
                servingWeight: 195,
                servingWeightUnit: "g",
                isIngredientBased: false,
                isAIEstimated: false,
                calories: 216,
                protein: 5,
                carbs: 45,
                fat: 1.8,
                fiber: 3.5,
                isCustomDefaultServing: false
            ),
            FoodItem(
                name: "Avocado",
                servingSize: 0.5,
                servingWeight: 100,
                servingWeightUnit: "g",
                isIngredientBased: false,
                isAIEstimated: false,
                calories: 160,
                protein: 2,
                carbs: 8.5,
                fat: 14.7,
                fiber: 6.7,
                isCustomDefaultServing: false
            ),
            FoodItem(
                name: "Oatmeal",
                servingSize: 1.0,
                servingWeight: 234,
                servingWeightUnit: "g",
                isIngredientBased: false,
                isAIEstimated: false,
                calories: 158,
                protein: 6,
                carbs: 27,
                fat: 3.2,
                fiber: 4,
                isCustomDefaultServing: false
            ),
            FoodItem(
                name: "Scrambled Eggs",
                servingSize: 2.0,
                servingWeight: 122,
                servingWeightUnit: "g",
                isIngredientBased: true,
                isAIEstimated: true,
                calories: 199,
                protein: 14,
                carbs: 2,
                fat: 15,
                fiber: 0,
                isCustomDefaultServing: true,
                customServingSize: 2.0
            ),
        ]

        for food in sampleFoods {
            container.mainContext.insert(food)
        }

        return NavigationStack {
            FoodLibrarySheetView()
        }
        .modelContainer(container)

    } catch {
        return Text("Failed to load preview: \(error.localizedDescription)")
    }
}
