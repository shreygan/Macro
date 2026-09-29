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
    @Query(sort: \FoodItem.dateAdded, order: .reverse) private var allFoods:
        [FoodItem]
    @Query(sort: \EntryDraft.updatedAt, order: .reverse) private var drafts:
        [EntryDraft]
    @Query private var loggedEntries: [LoggedEntry]

    @State private var draftToResume: EntryDraft? = nil
    @State private var draftToDelete: EntryDraft? = nil
    @State private var showDraftDeleteAlert = false

    private var sortedDrafts: [EntryDraft] {
        func sortDate(_ draft: EntryDraft) -> Date {
            draft.kind?.isLog == true
                ? (draft.timestamp ?? draft.updatedAt) : draft.updatedAt
        }
        return drafts.sorted { sortDate($0) > sortDate($1) }
    }

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

    @State private var sortOption: FoodSortOption = .lastLogged
    @State private var sortDescending: Bool = true

    @State private var showFilterSheet = false
    @State private var selectedTypes: Set<String> = []
    @State private var selectedSources: Set<String> = []
    @State private var selectedCategories: Set<String> = []

    private var hasActiveFilters: Bool {
        !searchText.isEmpty || !selectedTypes.isEmpty
            || !selectedSources.isEmpty || !selectedCategories.isEmpty
    }

    private var lastLoggedDates: [UUID: Date] {
        var result: [UUID: Date] = [:]
        for entry in loggedEntries {
            guard let id = entry.originalFoodItem?.id else { continue }
            if let existing = result[id], existing > entry.timestamp {
                continue
            }
            result[id] = entry.timestamp
        }
        return result
    }

    private var filteredAllFoods: [FoodItem] {
        var result =
            searchText.isEmpty
            ? allFoods
            : allFoods.filter { food in
                food.name.localizedStandardContains(searchText)
                    || (food.source?.source.localizedStandardContains(
                        searchText
                    ) ?? false)
            }

        if !selectedTypes.isEmpty {
            result = result.filter { food in
                selectedTypes.contains(food.type.rawValue.capitalized)
            }
        }

        if !selectedSources.isEmpty {
            result = result.filter { food in
                guard let sourceName = food.source?.source else {
                    return false
                }
                return selectedSources.contains(sourceName)
            }
        }

        if !selectedCategories.isEmpty {
            result = result.filter { food in
                guard let categoryName = food.category?.category else {
                    return false
                }
                return selectedCategories.contains(categoryName)
            }
        }

        let lastLoggedDates = lastLoggedDates
        return result.sorted { lhs, rhs in
            switch sortOption {
            case .name:
                return lhs.name.localizedStandardCompare(rhs.name)
                    == .orderedAscending
            case .dateAdded:
                return sortDescending
                    ? lhs.dateAdded > rhs.dateAdded
                    : lhs.dateAdded < rhs.dateAdded
            case .lastLogged:
                let lhsDate = lastLoggedDates[lhs.id] ?? .distantPast
                let rhsDate = lastLoggedDates[rhs.id] ?? .distantPast
                return sortDescending
                    ? lhsDate > rhsDate : lhsDate < rhsDate
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

    private var filterButton: some View {
        Button {
            showFilterSheet = true
        } label: {
            Image(
                systemName: hasActiveFilters
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
                Text("Recently Logged").tag(FoodSortOption.lastLogged)
                Text("Calories").tag(FoodSortOption.calories)
                Text("Protein").tag(FoodSortOption.protein)
                Text("Carbohydrates").tag(FoodSortOption.carbs)
                Text("Fat").tag(FoodSortOption.fat)
                Text("Fiber").tag(FoodSortOption.fiber)
            }
            if sortOption != .name {
                Divider()
                Picker("Order", selection: $sortDescending) {
                    if sortOption == .dateAdded || sortOption == .lastLogged {
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
        let favoritedFoods = favoriteEntries.compactMap { $0.foodItem }
        let filteredFoods = filteredAllFoods

        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()

                ScrollView {
                    VStack {
                        if !hasActiveFilters {
                            Group {
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
                                                defaultType: .specific(
                                                    .ingredient
                                                )
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
                                    if favoritedFoods.isEmpty {
                                        Text("No favorites yet.")
                                            .font(
                                                .system(
                                                    size: 14,
                                                    weight: .medium
                                                )
                                            )
                                            .foregroundColor(.secondary)
                                            .padding()
                                            .transition(.opacity)
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
                                                if let entry = food
                                                    .favoriteEntry
                                                {
                                                    modelContext.delete(entry)
                                                    try? modelContext.save()
                                                }
                                            },
                                            isFavorited: { food in
                                                food.favoriteEntry != nil
                                            }
                                        )
                                        .transition(.opacity)
                                    }
                                } menuItems: {
                                    Button {
                                        showReorderFavoritesSheet = true
                                    } label: {
                                        Label(
                                            "Reorder Favorites",
                                            systemImage: "arrow.up.arrow.down"
                                        )
                                    }
                                }
                                .padding([.top, .leading, .trailing])

                                if !drafts.isEmpty {
                                    Card("Drafts", titleBottomPadding: -4) {
                                        EntryList(
                                            items: sortedDrafts,
                                            allowSwipeActions: true,
                                            showCard: false,
                                            rowContent: { draft in
                                                DraftRow(
                                                    draft: draft,
                                                    servingUnits:
                                                        portionUnitOptions,
                                                    showsLogDate: true
                                                ) {
                                                    draftToResume = draft
                                                }
                                            },
                                            onDelete: { draft in
                                                draftToDelete = draft
                                                showDraftDeleteAlert = true
                                            }
                                        )
                                    }
                                    .padding([.top, .leading, .trailing])
                                    .transition(.opacity)
                                }
                            }
                            .transition(.opacity)
                        }

                        if !allFoods.isEmpty {
                            Card {
                                if filteredFoods.isEmpty {
                                    Text("No entries match these filters.")
                                        .font(
                                            .system(size: 14, weight: .medium)
                                        )
                                        .foregroundColor(.secondary)
                                        .padding()
                                        .transition(.opacity)
                                } else {
                                    EntryList(
                                        items: filteredFoods,
                                        allowSwipeActions: true,
                                        showCard: false,
                                        rowContent: { food in
                                            foodRow(for: food)
                                        },
                                        onDelete: { food in
                                            foodToDelete = food
                                            showDeleteAlert = true
                                        },
                                        onEdit: { food in
                                            foodToEdit = food
                                            showEditSheet = true
                                        },
                                        onFavorite: { food in
                                            let descriptor = FetchDescriptor<
                                                FavoriteEntry
                                            >()
                                            let existingFavorites =
                                                (try? modelContext.fetch(
                                                    descriptor
                                                )) ?? []

                                            let maxIndex =
                                                existingFavorites.compactMap {
                                                    $0.orderIndex
                                                }.max() ?? -1

                                            let newFavorite = FavoriteEntry(
                                                orderIndex: maxIndex + 1,
                                                foodItem: food
                                            )
                                            modelContext.insert(newFavorite)

                                            try? modelContext.save()
                                        },
                                        isFavorited: { food in
                                            food.favoriteEntry != nil
                                        }
                                    )
                                    .transition(.opacity)
                                }
                            }
                            .padding([.top, .leading, .trailing])
                        }

                        Spacer()
                    }
                    .animation(
                        .easeInOut(duration: 0.25),
                        value: hasActiveFilters
                    )
                    .animation(
                        .easeInOut(duration: 0.25),
                        value: filteredFoods.isEmpty
                    )
                    .animation(
                        .easeInOut(duration: 0.25),
                        value: favoritedFoods.isEmpty
                    )
                    .animation(
                        .easeInOut(duration: 0.25),
                        value: drafts.isEmpty
                    )
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.8),
                        value: favoritedFoods
                    )
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.8),
                        value: filteredFoods
                    )
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
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundStyle(.primary)
                        }
                    }

                    ToolbarItemGroup(placement: .topBarTrailing) {
                        filterButton
                        sortMenu
                    }
                }
            }
        }
        .environment(\.rootDismiss, { dismiss() })
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
        .sheet(item: $draftToResume) { draft in
            if draft.isAvailable {
                switch draft.kind {
                case .logFood, .logRecipe:
                    if let food = draft.foodItem {
                        Group {
                            if draft.kind == .logRecipe {
                                LogRecipeView(
                                    recipe: food,
                                    draft: draft,
                                    isPushedView: false
                                )
                            } else {
                                LogEntryView(
                                    food: food,
                                    draft: draft,
                                    isPushedView: false
                                )
                            }
                        }
                        .environment(\.rootDismiss) {
                            dismiss()
                        }
                    }
                case .addRecipe:
                    AddRecipeView(
                        onLogInstantly: { savedRecipe in
                            self.recipeToLog = savedRecipe
                        },
                        draft: draft
                    )
                case .addFood, nil:
                    AddEntryView(
                        entryType: draft.entryType ?? .food,
                        onLogInstantly: { savedFood in
                            self.foodToLog = savedFood
                        },
                        draft: draft
                    )
                }
            }
        }
        .sheet(item: $foodToLog) { food in
            LogEntryView(food: food, isPushedView: false)
                .environment(\.rootDismiss) {
                    dismiss()
                }
        }
        .sheet(item: $recipeToLog) { recipe in
            LogRecipeView(recipe: recipe, isPushedView: false)
                .environment(\.rootDismiss) {
                    dismiss()
                }
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
        .sheet(isPresented: $showFilterSheet) {
            FilterView(
                selectedTypes: $selectedTypes,
                selectedSources: $selectedSources,
                selectedCategories: $selectedCategories,
                defaultType: .all
            )
            .presentationDetents([.height(350)])
            .presentationDragIndicator(.visible)
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
        .alert(
            "Delete Draft?",
            isPresented: $showDraftDeleteAlert,
            presenting: draftToDelete
        ) { draft in
            Button("Cancel", role: .cancel) { draftToDelete = nil }
            Button("Delete", role: .destructive) {
                let id = draft.id
                draftToDelete = nil
                DispatchQueue.main.async {
                    withAnimation {
                        DraftStore.delete(id: id, in: modelContext)
                    }
                }
            }
        } message: { _ in
            Text(
                "This unfinished entry will be permanently deleted. This action cannot be undone."
            )
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
