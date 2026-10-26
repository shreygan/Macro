//
//  NewEntryView.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/3/26.
//

import SwiftData
import SwiftUI

private struct NewFoodRequest: Identifiable, Hashable {
    let id = UUID()
    let name: String
    var source: String = ""
}

private final class SearchLogStatsCache {
    var stats: [UUID: FoodLogStats]?
}

struct NewEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @Environment(\.toastCenter) private var toastCenter

    var onBrowseLibrary: (() -> Void)? = nil
    var onFinishLogging: (() -> Void)? = nil

    @Query(NewEntryView.favoritesDescriptor) private var favoriteEntries:
        [FavoriteEntry]
    @Query(sort: \ServingSizeUnit.displayOrder) private var portionUnitOptions:
        [ServingSizeUnit]
    @Query(sort: \FoodItem.dateAdded, order: .reverse) private var allFoods:
        [FoodItem]
    @Query(sort: \EntryDraft.updatedAt, order: .reverse) private var drafts:
        [EntryDraft]
    @Query private var users: [User]
    @Query(NewEntryView.recentEntriesDescriptor) private var recentEntries:
        [LoggedEntry]

    @State private var searchLogStats = SearchLogStatsCache()

    @State private var draftToResume: EntryDraft? = nil
    @State private var showAllDrafts = false

    private let recentLimit = 10
    private let draftPreviewLimit = 3

    private static var recentEntriesDescriptor: FetchDescriptor<LoggedEntry> {
        var descriptor = FetchDescriptor<LoggedEntry>(
            predicate: #Predicate { $0.parentEntry == nil },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 200
        descriptor.relationshipKeyPathsForPrefetching = [\.originalFoodItem]
        return descriptor
    }

    private static var favoritesDescriptor: FetchDescriptor<FavoriteEntry> {
        var descriptor = FetchDescriptor<FavoriteEntry>(
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        descriptor.relationshipKeyPathsForPrefetching = [\.foodItem]
        return descriptor
    }

    @State private var searchText = ""

    @State private var showAddIngredient = false
    @State private var showAddFood = false
    @State private var showAddRecipe = false
    @State private var showAddDrink = false
    @State private var foodToCreate: NewFoodRequest? = nil
    @State private var foodToLog: FoodItem? = nil
    @State private var drinkToLog: FoodItem? = nil
    @State private var storedBuiltInIDs: Set<UUID> = []
    @State private var recipeToLog: FoodItem? = nil

    @State private var showReorderFavoritesSheet = false

    @State private var foodToEdit: FoodItem? = nil
    @State private var foodToDelete: FoodItem? = nil

    private var tracksHydration: Bool {
        users.first?.tracksHydration ?? true
    }

    private var isSearching: Bool {
        !searchText.isEmpty
    }

    private var searchResults: [FoodItem] {
        let library = allFoods.filter(\.isInLibrary)
        let ranked = FoodSearch(searchText).ranked(library, stats: logStats())
        let aliases = DrinkAliasSearch(searchText)
        return ranked + library.filter { aliases.includes($0) && !ranked.contains($0) }
    }

    private var builtInResults: [FoodItem] {
        BuiltInCatalog.matches(searchText, stored: allFoods)
    }

    private func logStats() -> [UUID: FoodLogStats] {
        if let stats = searchLogStats.stats {
            return stats
        }
        let stats = FoodItemStore.logStats(in: modelContext)
        searchLogStats.stats = stats
        return stats
    }

    private var recentFoods: [FoodItem] {
        var seen = Set<UUID>()
        var result: [FoodItem] = []
        for entry in recentEntries {
            guard let food = entry.originalFoodItem,
                seen.insert(food.id).inserted
            else { continue }
            result.append(food)
            if result.count == recentLimit { break }
        }
        return result
    }

    private func foodRow(for food: FoodItem) -> some View {
        MealRow(
            food: food,
            servingUnits: portionUnitOptions,
            icon: food.type.appSymbol
        ) {
            log(food)
        }
        .aliasNote(DrinkAliasSearch(searchText).alias(for: food))
    }

    private func log(_ food: FoodItem) {
        guard BuiltInCatalog.isStored(food) else {
            do {
                let stored = try BuiltInCatalog.stored(food, in: modelContext)
                storedBuiltInIDs.insert(stored.id)
                log(stored)
            } catch {
                toastCenter?.show(.failure(String(localized: "Couldn't Open \(food.name)")))
            }
            return
        }
        if food.type == .recipe {
            recipeToLog = food
        } else if tracksHydration, food.isLoggableDrink {
            drinkToLog = food
        } else {
            foodToLog = food
        }
    }

    private func edit(_ food: FoodItem) {
        guard !BuiltInCatalog.isStored(food) else {
            foodToEdit = food
            return
        }
        do {
            let stored = try BuiltInCatalog.stored(food, in: modelContext)
            storedBuiltInIDs.insert(stored.id)
            foodToEdit = stored
        } catch {
            toastCenter?.show(.failure(String(localized: "Couldn't Open \(food.name)")))
        }
    }

    private func finishLogging() {
        dismiss()
        onFinishLogging?()
    }

    private func confirmDelete(_ food: FoodItem) {
        foodToDelete = food
    }

    private func deleteDraft(_ draft: EntryDraft) {
        DispatchQueue.main.async {
            EntryActions.delete(draft, in: modelContext, toastCenter: toastCenter)
        }
    }

    private func foodList(_ foods: [FoodItem]) -> some View {
        EntryList(
            items: foods,
            allowSwipeActions: true,
            showCard: false,
            rowContent: { food in
                foodRow(for: food)
                    .contextMenu {
                        FoodActionMenuItems(
                            food: food,
                            onLog: { log(food) },
                            onEdit: { foodToEdit = food },
                            onDelete: { confirmDelete(food) }
                        )
                    }
            },
            onDelete: { food in
                confirmDelete(food)
            },
            onEdit: { food in
                foodToEdit = food
            },
            onFavorite: { food in
                EntryActions.toggleFavorite(food, in: modelContext, toastCenter: toastCenter)
            },
            isFavorited: { food in
                food.favoriteEntry != nil
            }
        )
    }

    private func discardIfUnused(_ food: FoodItem) {
        guard storedBuiltInIDs.remove(food.id) != nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            BuiltInCatalog.discardIfUnused(food, in: modelContext)
        }
    }

    private func discardStoredBuiltIns() {
        let foods = allFoods.filter { storedBuiltInIDs.contains($0.id) }
        storedBuiltInIDs = []
        guard !foods.isEmpty else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            for food in foods {
                BuiltInCatalog.discardIfUnused(food, in: modelContext)
            }
        }
    }

    private func builtInList(_ foods: [FoodItem]) -> some View {
        EntryList(
            title: "Built-In",
            items: foods,
            allowSwipeActions: false,
            rowContent: { food in
                foodRow(for: food)
                    .contextMenu {
                        BuiltInMenuItems(
                            food: food,
                            onLog: { log(food) },
                            onEdit: { edit(food) }
                        )
                    }
            }
        )
    }

    private func draftList(_ drafts: [EntryDraft]) -> some View {
        EntryList(
            items: drafts,
            allowSwipeActions: true,
            showCard: false,
            rowContent: { draft in
                DraftRow(
                    draft: draft,
                    servingUnits: portionUnitOptions,
                    showsLogDate: true
                ) {
                    draftToResume = draft
                }
                .contextMenu {
                    Button {
                        draftToResume = draft
                    } label: {
                        Label("Resume Draft", systemImage: "square.and.pencil")
                    }

                    Divider()

                    Button(role: .destructive) {
                        deleteDraft(draft)
                    } label: {
                        Label("Delete Draft", systemImage: "trash")
                    }
                }
            },
            onDelete: { draft in
                deleteDraft(draft)
            }
        )
    }

    @ViewBuilder
    private func resumedDraftView(_ draft: EntryDraft) -> some View {
        if draft.isAvailable {
            switch draft.kind {
            case .logFood, .logRecipe:
                if let food = draft.foodItem {
                    if draft.kind == .logRecipe {
                        LogRecipeView(recipe: food, draft: draft, isPushedView: true)
                    } else {
                        LogEntryView(food: food, draft: draft, isPushedView: true)
                    }
                }
            case .addRecipe:
                AddRecipeView(offersLogNow: true, isPushedView: true, draft: draft)
            case .addFood, nil:
                AddEntryView(
                    entryType: draft.entryType ?? .food,
                    isPushedView: true,
                    offersLogNow: true,
                    draft: draft
                )
            }
        }
    }

    private func emptyText(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.compactTitle)
            .foregroundColor(.secondary)
            .padding()
            .transition(.opacity)
    }

    private var noResultsView: some View {
        ContentUnavailableView {
            Label(
                "No Results for \"\(searchText)\"",
                systemImage: "magnifyingglass"
            )
        } description: {
            SearchSuggestionButton(
                suggestion: FoodSearch.suggestion(for: searchText, in: allFoods),
                fallback: "Try a new search or create a new item."
            ) { searchText = $0 }
            .font(.subheadline)
        } actions: {
            createFromSearchButtons
        }
    }

    private func createFromSearch(name: String, source: String) {
        foodToCreate = NewFoodRequest(name: name, source: source)
    }

    private var createFromSearchButtons: some View {
        CreateFromSearchButtons(
            query: searchText,
            title: "Create New Food",
            onCreate: createFromSearch
        )
    }

    var body: some View {
        let favoritedFoods = favoriteEntries.compactMap { $0.foodItem }
        let recentFoods = recentFoods
        let searchResults = isSearching ? searchResults : []
        let builtInResults = isSearching ? builtInResults : []
        let showsNoResults = isSearching && searchResults.isEmpty && builtInResults.isEmpty

        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()

                ScrollView {
                    VStack {
                        if !isSearching {
                            Group {
                                Card("New Entry") {
                                    ButtonRow(
                                        icon: .appSymbol(.ingredient),
                                        title: "Add Ingredient",
                                        bottomPadding: 2
                                    ) {
                                        showAddIngredient = true
                                    }

                                    ButtonRow(
                                        icon: .appSymbol(.food),
                                        title: "Add Food",
                                        bottomPadding: 2
                                    ) {
                                        showAddFood = true
                                    }

                                    ButtonRow(
                                        icon: .appSymbol(.recipe),
                                        title: "Add Recipe",
                                        bottomPadding: tracksHydration ? 2 : 16
                                    ) {
                                        showAddRecipe = true
                                    }

                                    if tracksHydration {
                                        ButtonRow(
                                            icon: .appSymbol(.drink),
                                            title: "Add Drink",
                                        ) {
                                            showAddDrink = true
                                        }
                                    }
                                }
                                .padding([.leading, .trailing])

                                Card("Favorites", titleBottomPadding: -4) {
                                    if favoritedFoods.isEmpty {
                                        emptyText("No favorites yet.")
                                    } else {
                                        foodList(favoritedFoods)
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
                                        draftList(
                                            Array(
                                                drafts.prefix(draftPreviewLimit)
                                            )
                                        )

                                        if drafts.count > draftPreviewLimit {
                                            Divider()
                                                .padding(.horizontal, 16)
                                                .transition(.opacity)

                                            ButtonRow(
                                                icon: .customSymbol(
                                                    "tray.full"
                                                ),
                                                title:
                                                    "See All Drafts (\(drafts.count))"
                                            ) {
                                                showAllDrafts = true
                                            }
                                            .transition(.opacity)
                                        }
                                    }
                                    .padding([.top, .leading, .trailing])
                                    .transition(.opacity)
                                }

                                if !allFoods.isEmpty {
                                    Card("Recents", titleBottomPadding: -4) {
                                        if recentFoods.isEmpty {
                                            emptyText(
                                                "Recently logged items will appear here."
                                            )
                                        } else {
                                            foodList(recentFoods)
                                                .transition(.opacity)
                                        }

                                        if let onBrowseLibrary {
                                            if !recentFoods.isEmpty {
                                                Divider()
                                                    .padding(.horizontal, 16)
                                                    .transition(.opacity)
                                            }

                                            ButtonRow(
                                                icon: .customSymbol(
                                                    "book.pages"
                                                ),
                                                title: "Browse Library",
                                                topPadding: recentFoods.isEmpty
                                                    ? 0 : 8
                                            ) {
                                                dismiss()
                                                onBrowseLibrary()
                                            }
                                        }
                                    }
                                    .padding([.top, .leading, .trailing])
                                }
                            }
                            .transition(.opacity)
                        } else {
                            if !showsNoResults {
                                LibrarySearchCard(
                                    query: searchText,
                                    hasResults: !searchResults.isEmpty,
                                    onCreate: createFromSearch
                                ) {
                                    foodList(searchResults)
                                        .transition(.opacity)
                                }
                                .padding([.leading, .trailing])
                                .transition(.opacity)
                            }

                            if !builtInResults.isEmpty {
                                builtInList(builtInResults)
                                    .padding([.top, .leading, .trailing])
                                    .transition(.opacity)
                            }
                        }

                        Spacer()
                    }
                    .animation(
                        .easeInOut(duration: 0.25),
                        value: isSearching
                    )
                    .animation(
                        .easeInOut(duration: 0.25),
                        value: searchResults.isEmpty
                    )
                    .animation(
                        .easeInOut(duration: 0.25),
                        value: favoritedFoods.isEmpty
                    )
                    .animation(
                        .easeInOut(duration: 0.25),
                        value: recentFoods.isEmpty
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
                        value: recentFoods
                    )
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.8),
                        value: drafts
                    )
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.8),
                        value: searchResults
                    )
                    .animation(
                        .easeInOut(duration: 0.25),
                        value: builtInResults.isEmpty
                    )
                }
                .contentMargins(.bottom, 8, for: .scrollContent)
                .navigationTitle("New Entry")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(
                    text: $searchText,
                    prompt: "What did you eat today?"
                )
                .searchDictationBehavior(.automatic)
                .searchPresentationToolbarBehavior(.avoidHidingContent)
                .onChange(of: isSearching) { _, searching in
                    if !searching {
                        searchLogStats.stats = nil
                    }
                }
                .navigationDestination(isPresented: $showAllDrafts) {
                    DraftListView(
                        onResume: { draftToResume = $0 },
                        onDelete: { deleteDraft($0) }
                    )
                }
                .navigationDestination(isPresented: $showAddIngredient) {
                    AddEntryView(
                        entryType: .ingredient,
                        isPushedView: true,
                        offersLogNow: true
                    )
                }
                .navigationDestination(isPresented: $showAddFood) {
                    AddEntryView(
                        entryType: .food,
                        isPushedView: true,
                        offersLogNow: true
                    )
                }
                .navigationDestination(item: $foodToCreate) { request in
                    AddEntryView(
                        entryType: .food,
                        isPushedView: true,
                        offersLogNow: true,
                        prefill: .named(request.name, source: request.source)
                    )
                }
                .navigationDestination(isPresented: $showAddDrink) {
                    AddEntryView(
                        entryType: .drink,
                        isPushedView: true,
                        offersLogNow: true
                    )
                }
                .navigationDestination(isPresented: $showAddRecipe) {
                    AddRecipeView(offersLogNow: true, isPushedView: true)
                }
                .navigationDestination(item: $foodToLog) { food in
                    LogEntryView(food: food, isPushedView: true)
                }
                .onChange(of: foodToLog) { oldFood, newFood in
                    if newFood == nil, let oldFood {
                        discardIfUnused(oldFood)
                    }
                }
                .navigationDestination(item: $recipeToLog) { recipe in
                    LogRecipeView(recipe: recipe, isPushedView: true)
                }
                .navigationDestination(item: $draftToResume) { draft in
                    resumedDraftView(draft)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundStyle(.primary)
                        }
                    }
                }

                if showsNoResults {
                    noResultsView
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: showsNoResults)
        }
        .environment(\.rootDismiss, { finishLogging() })
        .onDisappear(perform: discardStoredBuiltIns)
        .sheet(item: $drinkToLog) { drink in
            let dayStartMinutes = users.first?.dayStartMinutes ?? 0
            let today = Calendar.current.logicalDay(for: .now, dayStartMinutes: dayStartMinutes)
            LogDrinkSheet(
                day: today,
                dayStartMinutes: dayStartMinutes,
                logicalToday: today,
                drink: drink,
                focusesAmount: false,
                onLogged: finishLogging
            )
        }
        .onChange(of: drinkToLog) { oldDrink, newDrink in
            if newDrink == nil, let oldDrink {
                discardIfUnused(oldDrink)
            }
        }
        .sheet(isPresented: $showReorderFavoritesSheet) {
            ReorderFavoritesView()
        }
        .onChange(of: foodToEdit) { oldFood, newFood in
            if newFood == nil, let oldFood {
                discardIfUnused(oldFood)
            }
        }
        .sheet(item: $foodToEdit) { food in
            if food.type == .recipe {
                EditRecipeView(recipe: food)
            } else {
                EditEntryView(foodItem: food)
            }
        }
        .deleteFoodAlert(food: $foodToDelete)
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
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
