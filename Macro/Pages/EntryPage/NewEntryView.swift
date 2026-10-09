//
//  NewEntryView.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/3/26.
//

import SwiftData
import SwiftUI

private struct NewFoodRequest: Identifiable {
    let id = UUID()
    let name: String
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
        descriptor.fetchLimit = 100
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

    @State private var showAddIngredientSheet = false
    @State private var showAddFoodSheet = false
    @State private var showAddRecipeSheet = false
    @State private var foodToCreate: NewFoodRequest? = nil
    @State private var foodToLog: FoodItem? = nil
    @State private var recipeToLog: FoodItem? = nil

    @State private var showReorderFavoritesSheet = false

    @State private var foodToEdit: FoodItem? = nil
    @State private var foodToDelete: FoodItem? = nil

    private var isSearching: Bool {
        !searchText.isEmpty
    }

    private var searchResults: [FoodItem] {
        let matches = allFoods.filter { food in
            food.name.localizedStandardContains(searchText)
                || (food.source?.source.localizedStandardContains(searchText)
                    ?? false)
        }

        let stats = logStats()
        return matches.sorted { lhs, rhs in
            let lhsDate = stats[lhs.id]?.lastLogged ?? .distantPast
            let rhsDate = stats[rhs.id]?.lastLogged ?? .distantPast
            if lhsDate == rhsDate {
                return lhs.dateAdded > rhs.dateAdded
            }
            return lhsDate > rhsDate
        }
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
    }

    private func log(_ food: FoodItem) {
        if food.type == .recipe {
            recipeToLog = food
        } else {
            foodToLog = food
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

    private func emptyText(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
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
            Text("Try a new search or create a new item.")
                .font(.subheadline)
        } actions: {
            Button("Create New Food") {
                foodToCreate = NewFoodRequest(name: searchText)
            }
            .tint(.blue)
        }
    }

    var body: some View {
        let favoritedFoods = favoriteEntries.compactMap { $0.foodItem }
        let recentFoods = recentFoods
        let searchResults = isSearching ? searchResults : []
        let showsNoResults = isSearching && searchResults.isEmpty

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
                        } else if !searchResults.isEmpty {
                            Card {
                                foodList(searchResults)
                                    .transition(.opacity)
                            }
                            .padding([.leading, .trailing])
                            .transition(.opacity)
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
        .sheet(isPresented: $showAddIngredientSheet) {
            AddEntryView(
                entryType: .ingredient,
                offersLogNow: true
            )
            .environment(\.rootDismiss) { finishLogging() }
        }
        .sheet(isPresented: $showAddFoodSheet) {
            AddEntryView(
                entryType: .food,
                offersLogNow: true
            )
            .environment(\.rootDismiss) { finishLogging() }
        }
        .sheet(item: $foodToCreate) { request in
            AddEntryView(
                entryType: .food,
                offersLogNow: true,
                prefill: .named(request.name)
            )
            .environment(\.rootDismiss) { finishLogging() }
        }
        .sheet(isPresented: $showAddRecipeSheet) {
            AddRecipeView(offersLogNow: true)
                .environment(\.rootDismiss) { finishLogging() }
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
                            finishLogging()
                        }
                    }
                case .addRecipe:
                    AddRecipeView(
                        offersLogNow: true,
                        draft: draft
                    )
                    .environment(\.rootDismiss) { finishLogging() }
                case .addFood, nil:
                    AddEntryView(
                        entryType: draft.entryType ?? .food,
                        offersLogNow: true,
                        draft: draft
                    )
                    .environment(\.rootDismiss) { finishLogging() }
                }
            }
        }
        .sheet(item: $foodToLog) { food in
            LogEntryView(food: food, isPushedView: false)
                .environment(\.rootDismiss) {
                    finishLogging()
                }
        }
        .sheet(item: $recipeToLog) { recipe in
            LogRecipeView(recipe: recipe, isPushedView: false)
                .environment(\.rootDismiss) {
                    finishLogging()
                }
        }
        .sheet(isPresented: $showReorderFavoritesSheet) {
            ReorderFavoritesView()
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
