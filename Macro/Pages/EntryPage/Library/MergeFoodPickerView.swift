//
//  MergeFoodPickerView.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/15/26.
//

import SwiftData
import SwiftUI

struct MergeFoodPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let food: FoodItem
    var onConfirm: (FoodMergePlan) -> Void

    @Query(sort: \FoodItem.name) private var allFoods: [FoodItem]
    @Query(sort: \ServingSizeUnit.displayOrder) private var servingUnits: [ServingSizeUnit]

    @State private var selectedIDs: [UUID] = []
    @State private var searchText = ""
    @State private var isShowingReview = false

    private var candidates: [FoodItem] {
        allFoods.filter { $0.type == food.type && $0.id != food.id }
    }

    private var similarFoods: [FoodItem] {
        let words = Self.nameWords(food.name)
        guard !words.isEmpty else { return [] }
        return candidates
            .map { ($0, Self.similarity(words, Self.nameWords($0.name))) }
            .filter { $0.1 >= 0.6 }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    private var otherFoods: [FoodItem] {
        let similarIDs = Set(similarFoods.map(\.id))
        return candidates.filter { !similarIDs.contains($0.id) }
    }

    private var searchResults: [FoodItem] {
        let search = FoodSearch(searchText)
        return candidates
            .compactMap { food in search.relevance(of: food).map { (food, $0) } }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }

    private var selectedFoods: [FoodItem] {
        selectedIDs.compactMap { id in candidates.first { $0.id == id } }
    }

    private var typeTitle: String {
        "\(food.type.rawValue.capitalized)s"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()

                ScrollView {
                    VStack {
                        if searchText.isEmpty {
                            if !similarFoods.isEmpty {
                                list("Similar", foods: similarFoods)
                            }
                            if !otherFoods.isEmpty {
                                list(similarFoods.isEmpty ? typeTitle : "All \(typeTitle)", foods: otherFoods)
                            }
                        } else if !searchResults.isEmpty {
                            list(nil, foods: searchResults)
                        }
                    }
                }
                .scrollDismissesKeyboard(.immediately)

                if candidates.isEmpty {
                    ContentUnavailableView(
                        "No Other \(typeTitle)",
                        systemImage: "square.stack",
                        description: Text("There's nothing to merge this with yet.")
                    )
                } else if !searchText.isEmpty && searchResults.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .navigationTitle("Merge With")
            .navigationSubtitle(
                selectedIDs.isEmpty
                    ? String(localized: "None Selected")
                    : String(localized: "\(selectedIDs.count) Selected")
            )
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search \(typeTitle.lowercased())")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark").foregroundStyle(.primary)
                    }
                }

                DefaultToolbarItem(kind: .search, placement: .bottomBar)

                ToolbarSpacer(.fixed, placement: .bottomBar)

                ToolbarItem(placement: .bottomBar) {
                    Button {
                        isShowingReview = true
                    } label: {
                        Image(systemName: "arrow.right")
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(selectedIDs.isEmpty)
                    .accessibilityLabel("Next")
                }
            }
            .navigationDestination(isPresented: $isShowingReview) {
                MergeFoodsView(
                    foods: [food] + selectedFoods,
                    kept: food,
                    servingUnits: servingUnits,
                    onConfirm: { plan in
                        onConfirm(plan)
                        dismiss()
                    }
                )
            }
        }
        .environment(\.tabBarHeight, 0)
        .sensoryFeedback(.selection, trigger: selectedIDs.count)
    }

    private func list(_ title: String?, foods: [FoodItem]) -> some View {
        EntryList(
            title: title,
            items: foods,
            allowSwipeActions: false,
            rowContent: { item in
                MealRow(food: item, servingUnits: servingUnits) {
                    withAnimation(.snappy) {
                        toggle(item)
                    }
                }
                .selectionState(selectedIDs.contains(item.id))
            }
        )
        .padding([.horizontal, .bottom])
    }

    private func toggle(_ item: FoodItem) {
        if let index = selectedIDs.firstIndex(of: item.id) {
            selectedIDs.remove(at: index)
        } else {
            selectedIDs.append(item.id)
        }
    }

    private static let ignoredWords: Set<String> = [
        "serving", "servings", "slice", "slices", "piece", "pieces", "the", "and", "with",
    ]

    private static func nameWords(_ name: String) -> Set<String> {
        let words = name.lowercased()
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { $0.count >= 3 && !ignoredWords.contains($0) }
        return Set(words)
    }

    private static func similarity(_ lhs: Set<String>, _ rhs: Set<String>) -> Double {
        guard !lhs.isEmpty, !rhs.isEmpty else { return 0 }
        return Double(lhs.intersection(rhs).count) / Double(min(lhs.count, rhs.count))
    }
}

#Preview {
    let schema = Schema([
        FoodItem.self, EntrySource.self, CategorySource.self, FoodGroupSource.self,
        ServingSizeUnit.self, FavoriteEntry.self, LoggedEntry.self, EntryDraft.self,
        SavedLocation.self,
    ])
    let container = try! ModelContainer(
        for: schema,
        configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    )
    let context = container.mainContext
    let serving = ServingSizeUnit(unit: "serving", pluralVariant: "servings", displayOrder: 0)
    context.insert(serving)

    func food(_ name: String, _ calories: Double) -> FoodItem {
        let item = FoodItem(
            name: name,
            servingSize: 1,
            servingUnit: serving,
            servingWeightUnit: "g",
            isAIEstimated: false,
            calories: calories,
            protein: calories / 25,
            carbs: calories / 9,
            fat: calories / 26,
            fiber: 2,
            isCustomDefaultServing: false
        )
        context.insert(item)
        return item
    }

    let current = food("Domino's Pan Pizza (4 slices)", 1040)
    _ = food("Domino's Pan Pizza (6 slices)", 1560)
    _ = food("Domino's Pan Pizza", 1300)
    _ = food("Chicken Burrito", 900)
    _ = food("Greek Yogurt", 150)

    return MergeFoodPickerView(food: current, onConfirm: { _ in })
        .modelContainer(container)
}
