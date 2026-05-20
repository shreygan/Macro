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

    @State private var activeSheet: ActiveSheet?
    enum ActiveSheet: Identifiable {
        case newIngredient, newFood, newRecipe
        var id: Int { hashValue }
    }

    var body: some View {
        NavigationStack {
            LibrarySheetView(
                title: "Add Ingredient",
                searchPrompt: "Search ingredients...",
                defaultType: .specific(.ingredient),
                allowSwipeActions: false,
                onSelect: { ingredient in
                    onSelect(ingredient)
                    dismiss()
                }
            ) {
                SearchStateReader { isSearching in
                    if !isSearching {
                        VStack {
                            Card("New Entry") {
                                RowGroup(.none) {
                                    ButtonRow(
                                        icon: .appSymbol(.ingredient),
                                        title: "Add New Ingredient",
                                        bottomPadding: 2
                                    ) { activeSheet = .newIngredient }

                                    ButtonRow(
                                        icon: .appSymbol(.food),
                                        title: "Add New Food"
                                    ) { activeSheet = .newFood }
                                }
                            }
                            .padding(.bottom)

                            Card("Library") {
                                RowGroup(.divider) {
                                    NavigationLink(
                                        destination: LibrarySheetView(
                                            defaultType: .specific(.food),
                                            allowSwipeActions: false,
                                            onSelect: { food in
                                                onSelect(food)
                                                dismiss()
                                            }
                                        )
                                    ) {
                                        NavigationRow(
                                            icon: .appSymbol(.food),
                                            title: "Foods"
                                        )
                                    }.buttonStyle(.plain)

                                    NavigationLink(
                                        destination: LibrarySheetView(
                                            defaultType: .specific(.recipe),
                                            allowSwipeActions: false,
                                            onSelect: { recipe in
                                                onSelect(recipe)
                                                dismiss()
                                            }
                                        )
                                    ) {
                                        NavigationRow(
                                            icon: .appSymbol(.recipe),
                                            title: "Recipes"
                                        )
                                    }.buttonStyle(.plain)
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
            .navigationDestination(item: $activeSheet) { sheet in
                switch sheet {
                case .newIngredient:
                    AddEntrySheetView(
                        entryType: .ingredient,
                        isPushedView: true,
                        onSelectInstantly: { onSelect($0) }
                    )
                case .newFood:
                    AddEntrySheetView(
                        entryType: .food,
                        isPushedView: true,
                        onSelectInstantly: { onSelect($0) }
                    )
                case .newRecipe:
                    AddEntrySheetView(
                        entryType: .recipe,
                        isPushedView: true,
                        onSelectInstantly: { onSelect($0) }
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark").foregroundStyle(.primary)
                    }
                }
            }
        }
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

        return IngredientSelectionSheetView { selectedItem in
            print("Preview User Selected: \(selectedItem.name)")
        }
        .modelContainer(container)

    } catch {
        return Text(
            "Failed to create preview database: \(error.localizedDescription)"
        )
    }
}
