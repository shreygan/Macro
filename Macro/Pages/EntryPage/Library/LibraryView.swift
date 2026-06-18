//
//  LibraryView.swift
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

nonisolated enum SwipeAction: Hashable, Sendable {
    case edit, delete, favorite
}

struct LibraryView<Header: View>: View {
    @Environment(\.modelContext) private var modelContext

    var title: String
    var searchPrompt: String
    var swipeActions: Set<SwipeAction>
    var onSelect: ((FoodItem) -> Void)? = nil
    var defaultType: LibraryFilterType
    let headerContent: Header

    @Query(sort: \FoodItem.dateAdded, order: .reverse) var savedMeals:
        [FoodItem]
    @Query(sort: \ServingSizeUnit.displayOrder) var portionUnitOptions:
        [ServingSizeUnit]

    @State private var selectedFood: FoodItem?
    @State private var searchText = ""

    @State private var sortOption: FoodSortOption = .dateAdded
    @State private var sortDescending: Bool = true

    @State private var showFilterSheet = false
    @State private var selectedTypes: Set<String>
    @State private var selectedSources: Set<String> = []
    @State private var selectedCategories: Set<String> = []

    @State private var showDeleteAlert = false
    @State private var foodToDelete: FoodItem?

    @State private var showEditSheet = false
    @State private var foodToEdit: FoodItem?

    private var dynamicTitle: String {
        if selectedTypes.count == 1, let singleType = selectedTypes.first {
            return "\(singleType)s"
        }
        return title
    }

    var filteredFoods: [FoodItem] {
        // 1. Search text filter
        var result =
            searchText.isEmpty
            ? savedMeals
            : savedMeals.filter { food in
                food.name.localizedStandardContains(searchText)
            }

        // 2. Type filter
        if !selectedTypes.isEmpty {
            result = result.filter { food in
                return selectedTypes.contains(food.type.rawValue.capitalized)
            }
        }

        // 3. Source filter
        if !selectedSources.isEmpty {
            result = result.filter { food in
                guard let sourceName = food.source?.source else { return false }
                return selectedSources.contains(sourceName)
            }
        }

        // 4. Category filter
        if !selectedCategories.isEmpty {
            result = result.filter { food in
                guard let categoryName = food.category?.category else {
                    return false
                }
                return selectedCategories.contains(categoryName)
            }
        }

        // 5. Sort filtered results
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

    init(
        title: String = "Library",
        searchPrompt: String = "What did you eat today?",
        defaultType: LibraryFilterType = .all,
        swipeActions: Set<SwipeAction> = [.edit, .delete, .favorite],
        onSelect: ((FoodItem) -> Void)? = nil,
        @ViewBuilder headerContent: () -> Header = { EmptyView() }
    ) {
        self.title = title
        self.searchPrompt = searchPrompt
        self.defaultType = defaultType
        self.swipeActions = swipeActions
        self.onSelect = onSelect
        self.headerContent = headerContent()

        let initialTypes: Set<String> =
            defaultType == .all ? [] : [defaultType.displayName]
        self._selectedTypes = State(initialValue: initialTypes)
    }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            if filteredFoods.isEmpty {
                VStack(spacing: 0) {
                    headerContent
                        .padding([.horizontal, .bottom])

                    Spacer()

                    emptyStateView

                    Spacer()
                }
                .transition(.opacity)
                .zIndex(1)

            } else {
                ScrollView {
                    VStack {
                        headerContent
                            .padding([.horizontal, .bottom])

                        EntryList(
                            items: filteredFoods,
                            allowSwipeActions: !swipeActions.isEmpty,
                            rowContent: { food in
                                foodRow(for: food)
                            },
                            onDelete: swipeActions.contains(.delete)
                                ? { food in
                                    foodToDelete = food
                                    showDeleteAlert = true
                                } : nil,
                            onEdit: swipeActions.contains(.edit)
                                ? { food in
                                    foodToEdit = food
                                    showEditSheet = true
                                } : nil,
                            onFavorite: swipeActions.contains(.favorite)
                                ? { food in
                                    print("Favorited \(food.name)")
                                } : nil
                        )
                        .padding([.horizontal, .bottom])
                    }
                }
                .transition(.opacity)
                .zIndex(2)
            }
        }
        .withGlobalSwipeDismissal()
        .animation(.easeInOut(duration: 0.25), value: filteredFoods.isEmpty)
        .navigationTitle(dynamicTitle)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.immediately)
        .searchable(text: $searchText, prompt: searchPrompt)
        .searchDictationBehavior(.automatic)
        .searchPresentationToolbarBehavior(.avoidHidingContent)
        .navigationDestination(item: $selectedFood) { foodToLog in
            if foodToLog.type == .recipe {
                LogRecipeView(recipe: foodToLog)
            } else {
                LogEntryView(food: foodToLog)
            }
        }
        .sheet(item: $foodToEdit) { food in
            if food.type == .recipe {
                EditRecipeView(recipe: food)
            } else {
                EditEntryView(foodItem: food)
            }
        }
        .sheet(isPresented: $showFilterSheet) {
            FilterView(
                selectedTypes: $selectedTypes,
                selectedSources: $selectedSources,
                selectedCategories: $selectedCategories,
                defaultType: defaultType
            )
            .presentationDetents([.height(350)])
            .presentationDragIndicator(.visible)
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                filterButton
                sortMenu
            }
        }
        .alert(
            "Delete Food",
            isPresented: $showDeleteAlert,
            presenting: foodToDelete
        ) { food in
            Button("Cancel", role: .cancel) { foodToDelete = nil }
            Button("Delete", role: .destructive) {
                let item = food
                foodToDelete = nil
                DispatchQueue.main.async {
                    modelContext.delete(item)
                    try? modelContext.save()
                }
            }
        } message: { food in
            Text("Are you sure you want to delete \(food.name)?")
        }
    }

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
            icon: selectedTypes.count != 1 ? food.type.appSymbol : nil
        ) {
            handleSelect(food)
        }
    }

    private func handleSelect(_ food: FoodItem) {
        if let onSelect = onSelect {
            onSelect(food)
        } else {
            selectedFood = food
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            let singleType =
                selectedTypes.count == 1 ? selectedTypes.first : nil
            let itemName = singleType?.lowercased() ?? "item"

            if let type = singleType, let symbol = AppSymbols.from(type) {
                Image(systemName: symbol.rawValue).font(.largeTitle)
                    .foregroundColor(.gray)
            } else {
                Image(systemName: "magnifyingglass").font(.largeTitle)
                    .foregroundColor(.gray)
            }

            if searchText.isEmpty {
                if let type = singleType {
                    Text("No \(type)s").font(.title3.bold())
                    Text(
                        LocalizedStringKey(
                            "\(type.lowercased())" + "_description"
                        )
                    )
                    .font(.subheadline).foregroundColor(.secondary)
                    .multilineTextAlignment(.center).padding(
                        .horizontal,
                        32
                    )
                    Button("Add \(type)") { /* TODO: Implement */  }
                        .font(.subheadline).foregroundColor(.accentColor)
                        .padding(.top, 8)
                } else {
                    Text("Library is Empty").font(.title3.bold())
                    Text("Add some items to your library to get started.")
                        .font(.subheadline).foregroundColor(.secondary)
                    Button("Add Item") { /* TODO: Implement */  }
                        .font(.subheadline).foregroundColor(.accentColor)
                        .padding(.top, 8)
                }
            } else {
                if let type = singleType {
                    Text("No \(type)s match \"\(searchText)\"").font(
                        .title3.bold()
                    )
                } else {
                    Text("No Results for \"\(searchText)\"").font(
                        .title3.bold()
                    )
                }
                Text(
                    "Try a new search or [create a new \(itemName)](action:create)"
                )
                .font(.subheadline).foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 32).tint(
                    .blue
                )
                .environment(
                    \.openURL,
                    OpenURLAction { url in
                        if url.absoluteString == "action:create" {
                            return .handled
                        }
                        return .discarded
                    }
                )
            }
        }
    }

    private var filterButton: some View {
        Button {
            showFilterSheet = true
        } label: {
            let defaultTypesSet: Set<String> =
                defaultType == .all ? [] : [defaultType.displayName]
            let hasFilters =
                selectedTypes != defaultTypesSet || !selectedSources.isEmpty
                || !selectedCategories.isEmpty
            Image(
                systemName: hasFilters
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
            )
            .tint(.primary)
        }
    }

    private var sortMenu: some View {
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
            LibraryView(defaultType: .all, swipeActions: [.delete, .edit])
        }
        .modelContainer(container)

    } catch {
        return Text("Failed to load preview: \(error.localizedDescription)")
    }
}
