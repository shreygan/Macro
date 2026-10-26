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
    @Environment(\.modelContext) private var modelContext
    @Environment(\.toastCenter) private var toastCenter

    let food: FoodItem
    var onConfirm: (FoodMergePlan) -> Void

    @Query(sort: \FoodItem.name) private var allFoods: [FoodItem]
    @Query(sort: \ServingSizeUnit.displayOrder) private var servingUnits: [ServingSizeUnit]

    @State private var selectedIDs: [UUID] = []
    @State private var searchText = ""
    @State private var isShowingReview = false
    @State private var reviewFoods: [FoodItem] = []
    @State private var storedBuiltIns: [FoodItem] = []
    @State private var didMerge = false

    private var libraryFoods: [FoodItem] {
        allFoods.filter {
            $0.type == food.type && $0.id != food.id && ($0.seedKey == nil || $0.isInLibrary)
        }
    }

    private var builtIns: [FoodItem] {
        BuiltInCatalog.items(stored: allFoods, type: food.type)
            .filter { $0.id != food.id && $0.seedKey != food.seedKey }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var candidates: [FoodItem] {
        libraryFoods + builtIns
    }

    private var similarFoods: [FoodItem] {
        FoodNameMatch.similar(to: food.name, in: candidates)
    }

    private var otherFoods: [FoodItem] {
        let similarIDs = Set(similarFoods.map(\.id))
        return libraryFoods.filter { !similarIDs.contains($0.id) }
    }

    private var otherBuiltIns: [FoodItem] {
        let similarIDs = Set(similarFoods.map(\.id))
        return builtIns.filter { !similarIDs.contains($0.id) }
    }

    private func searchResults(in foods: [FoodItem]) -> [FoodItem] {
        let search = FoodSearch(searchText)
        return foods
            .compactMap { food in search.relevance(of: food).map { (food, $0) } }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }

    private var searchResults: [FoodItem] {
        searchResults(in: libraryFoods)
    }

    private var builtInResults: [FoodItem] {
        searchResults(in: builtIns)
    }

    private func review() {
        var stored: [FoodItem] = []
        for item in selectedFoods {
            guard !BuiltInCatalog.isStored(item) else {
                stored.append(item)
                continue
            }
            do {
                let copy = try BuiltInCatalog.stored(item, in: modelContext)
                storedBuiltIns.append(copy)
                if let index = selectedIDs.firstIndex(of: item.id) {
                    selectedIDs[index] = copy.id
                }
                stored.append(copy)
            } catch {
                toastCenter?.show(.failure(String(localized: "Couldn't Open \(item.name)")))
                return
            }
        }
        reviewFoods = stored
        isShowingReview = true
    }

    private func discardUnusedBuiltIns() {
        guard !didMerge else { return }
        for item in storedBuiltIns {
            BuiltInCatalog.discardIfUnused(item, in: modelContext)
        }
        storedBuiltIns = []
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
                            if !otherBuiltIns.isEmpty {
                                list("Built-In", foods: otherBuiltIns)
                            }
                        } else {
                            if !searchResults.isEmpty {
                                list(nil, foods: searchResults)
                            }
                            if !builtInResults.isEmpty {
                                list("Built-In", foods: builtInResults)
                            }
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
                } else if !searchText.isEmpty && searchResults.isEmpty && builtInResults.isEmpty {
                    ContentUnavailableView {
                        Label(
                            "No \(typeTitle) match \"\(searchText)\"",
                            systemImage: AppSymbols.from(food.type.rawValue.capitalized)?.rawValue ?? "magnifyingglass"
                        )
                    } description: {
                        SearchSuggestionButton(
                            suggestion: FoodSearch.suggestion(for: searchText, in: candidates),
                            fallback: "Try a new search."
                        ) { searchText = $0 }
                        .font(.subheadline)
                    }
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
                        review()
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
                    foods: [food] + reviewFoods,
                    kept: food,
                    servingUnits: servingUnits,
                    onConfirm: { plan in
                        didMerge = true
                        onConfirm(plan)
                        dismiss()
                    }
                )
            }
        }
        .environment(\.tabBarHeight, 0)
        .sensoryFeedback(.selection, trigger: selectedIDs.count)
        .onDisappear(perform: discardUnusedBuiltIns)
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
