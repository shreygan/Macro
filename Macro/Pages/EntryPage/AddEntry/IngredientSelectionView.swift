//
//  IngredientSelectionView.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/17/26.
//

import SwiftData
import SwiftUI

@Observable
final class IngredientSelection {
    private(set) var items: [FoodItem] = []
    let inRecipeIDs: Set<UUID>
    let recipeID: UUID?
    var blockedIDs: Set<UUID> = []

    init(inRecipeIDs: Set<UUID>, recipeID: UUID?) {
        self.inRecipeIDs = inRecipeIDs
        self.recipeID = recipeID
    }

    func contains(_ food: FoodItem) -> Bool {
        items.contains { $0.id == food.id }
    }

    func isInRecipe(_ food: FoodItem) -> Bool {
        inRecipeIDs.contains(food.id)
    }

    func isBlocked(_ food: FoodItem) -> Bool {
        blockedIDs.contains(food.id) || isInRecipe(food)
    }

    func toggle(_ food: FoodItem) {
        if let index = items.firstIndex(where: { $0.id == food.id }) {
            items.remove(at: index)
        } else {
            items.append(food)
        }
    }

    func add(_ food: FoodItem) {
        if !contains(food) {
            items.append(food)
        }
    }
}

struct IngredientSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext

    var excludedRecipe: FoodItem?
    var onAdd: ([FoodItem]) -> Void

    @State private var selection: IngredientSelection

    @State private var activeSheet: ActiveSheet?
    enum ActiveSheet: Identifiable {
        case newIngredient, newFood
        var id: Int { hashValue }
    }

    init(
        inRecipeIDs: Set<UUID> = [],
        excludedRecipe: FoodItem? = nil,
        onAdd: @escaping ([FoodItem]) -> Void
    ) {
        self.excludedRecipe = excludedRecipe
        self.onAdd = onAdd
        self._selection = State(
            initialValue: IngredientSelection(
                inRecipeIDs: inRecipeIDs,
                recipeID: excludedRecipe?.id
            )
        )
    }

    var body: some View {
        NavigationStack {
            LibraryView(
                title: "Add Ingredient",
                searchPrompt: "Search your library",
                swipeActions: [],
                fallbackEntryType: .ingredient,
                selection: selection
            ) {
                SearchStateReader { isSearching in
                    if !isSearching {
                        VStack {
                            Card("New Entry") {
                                RowGroup(.none) {
                                    ButtonRow(
                                        icon: .appSymbol(.ingredient),
                                        title: "Add Ingredient",
                                        bottomPadding: 2
                                    ) { activeSheet = .newIngredient }

                                    ButtonRow(
                                        icon: .appSymbol(.food),
                                        title: "Add Food"
                                    ) { activeSheet = .newFood }
                                }
                            }
                            .padding(.bottom)

                            Card("Library") {
                                RowGroup(.divider) {
                                    libraryLink(
                                        "Ingredients",
                                        type: .ingredient
                                    )
                                    libraryLink("Foods", type: .food)
                                    libraryLink("Recipes", type: .recipe)
                                }
                            }
                        }
                        .transition(
                            .opacity.combined(
                                with: .scale(scale: 0.95, anchor: .top)
                            )
                        )
                    }
                }
            }
            .addSelectionToolbar(selection, onAdd: confirm)
            .navigationDestination(item: $activeSheet) { sheet in
                switch sheet {
                case .newIngredient:
                    AddEntryView(
                        entryType: .ingredient,
                        isPushedView: true,
                        onSelectInstantly: selectCreated
                    )
                case .newFood:
                    AddEntryView(
                        entryType: .food,
                        isPushedView: true,
                        onSelectInstantly: selectCreated
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark").foregroundStyle(.primary)
                    }
                }
            }
        }
        .environment(\.tabBarHeight, 0)
        .sensoryFeedback(.selection, trigger: selection.items.count)
        .onAppear(perform: loadBlockedRecipes)
    }

    private func loadBlockedRecipes() {
        guard let excludedRecipe else { return }
        selection.blockedIDs =
            FoodItemStore.recipesContaining(excludedRecipe, in: modelContext)
            .union([excludedRecipe.id])
    }

    private func libraryLink(_ title: String, type: EntryType) -> some View {
        NavigationLink(
            destination: LibraryView(
                title: title,
                defaultType: .specific(type),
                swipeActions: [],
                selection: selection
            )
            .addSelectionToolbar(selection, onAdd: confirm)
        ) {
            NavigationRow(icon: .appSymbol(type.appSymbol), title: title)
        }
        .buttonStyle(.plain)
    }

    private func selectCreated(_ food: FoodItem) {
        selection.add(food)
        activeSheet = nil
    }

    private func confirm() {
        onAdd(selection.items)
        dismiss()
    }
}

private extension View {
    func addSelectionToolbar(
        _ selection: IngredientSelection,
        onAdd: @escaping () -> Void
    ) -> some View {
        toolbar {
            DefaultToolbarItem(kind: .search, placement: .bottomBar)

            ToolbarSpacer(.fixed, placement: .bottomBar)

            ToolbarItem(placement: .bottomBar) {
                SelectionDoneButton(selection: selection, onAdd: onAdd)
            }
        }
    }
}

private struct SelectionDoneButton: View {
    let selection: IngredientSelection
    let onAdd: () -> Void

    var body: some View {
        Button(action: onAdd) {
            Image(systemName: "checkmark")
        }
        .buttonStyle(.glassProminent)
        .disabled(selection.items.isEmpty)
        .accessibilityLabel("Add Ingredients")
    }
}

struct SearchStateReader<Content: View>: View {
    @Environment(\.isSearching) private var isSearching

    @State private var smoothIsSearching = false

    @ViewBuilder let content: (Bool) -> Content

    var body: some View {
        content(smoothIsSearching)
            .onChange(of: isSearching) { oldValue, newValue in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    smoothIsSearching = newValue
                }
            }
            .onAppear {
                smoothIsSearching = isSearching
            }
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: FoodItem.self,
            configurations: config
        )

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

        let mockProteinBar = FoodItem(
            name: "Quest Bar",
            type: .food,
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

        container.mainContext.insert(mockApple)
        container.mainContext.insert(mockChicken)
        container.mainContext.insert(mockProteinBar)

        return IngredientSelectionView(inRecipeIDs: [mockChicken.id]) {
            selectedItems in
            print("Preview User Selected: \(selectedItems.map(\.name))")
        }
        .modelContainer(container)

    } catch {
        return Text(
            "Failed to create preview database: \(error.localizedDescription)"
        )
    }
}
