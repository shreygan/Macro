//
//  StartFromPickerView.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/22/26.
//

import SwiftData
import SwiftUI

extension FoodItem {
    static func descriptor(for type: EntryType) -> FetchDescriptor<FoodItem> {
        FetchDescriptor(predicate: #Predicate { $0.type == type })
    }
}

struct StartFromPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let type: EntryType
    var name: String = ""
    var confirmsReplace = false
    var keepsName = true
    var typedSource: String?
    var onSelect: (FoodItem) -> Void

    @Query(sort: \FoodItem.name) private var allFoods: [FoodItem]
    @Query(sort: \ServingSizeUnit.displayOrder) private var servingUnits: [ServingSizeUnit]

    @State private var searchText = ""
    @State private var pendingFood: FoodItem?

    private var candidates: [FoodItem] {
        allFoods.filter { $0.type == type && $0.isInLibrary }
    }

    private var builtIns: [FoodItem] {
        BuiltInCatalog.items(stored: allFoods, type: type)
    }

    private var builtInResults: [FoodItem] {
        BuiltInCatalog.matches(searchText, stored: allFoods, type: type)
    }

    private var similarFoods: [FoodItem] {
        FoodNameMatch.similar(to: name, in: candidates + builtIns)
    }

    private var otherFoods: [FoodItem] {
        let similarIDs = Set(similarFoods.map(\.id))
        return candidates.filter { !similarIDs.contains($0.id) }
    }

    private var otherBuiltIns: [FoodItem] {
        let similarIDs = Set(similarFoods.map(\.id))
        return builtIns.filter { !similarIDs.contains($0.id) }
    }

    private var searchResults: [FoodItem] {
        let search = FoodSearch(searchText)
        return candidates
            .compactMap { food in search.relevance(of: food).map { (food, $0) } }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }

    private var typeTitle: String {
        "\(type.rawValue.capitalized)s"
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

                if candidates.isEmpty && builtIns.isEmpty {
                    ContentUnavailableView(
                        "No \(typeTitle)",
                        systemImage: "square.stack",
                        description: Text("There's nothing to start from yet.")
                    )
                } else if !searchText.isEmpty && searchResults.isEmpty && builtInResults.isEmpty {
                    ContentUnavailableView {
                        Label(
                            "No \(typeTitle) match \"\(searchText)\"",
                            systemImage: AppSymbols.from(type.rawValue.capitalized)?.rawValue ?? "magnifyingglass"
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
            .navigationTitle("Start From")
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
            }
            .alert(
                "Replace Details?",
                isPresented: Binding(
                    get: { pendingFood != nil },
                    set: { if !$0 { pendingFood = nil } }
                ),
                presenting: pendingFood
            ) { food in
                Button("Replace", role: .destructive) { pick(food) }
                Button("Cancel", role: .cancel) {}
            } message: { food in
                ReplaceDetailsMessage.text(
                    from: food,
                    keepsName: keepsName,
                    replacesSource: ReplaceDetailsMessage.replaces(typedSource, with: food)
                )
            }
        }
        .environment(\.tabBarHeight, 0)
    }

    private func pick(_ food: FoodItem) {
        onSelect(food)
        dismiss()
    }

    private func list(_ title: String?, foods: [FoodItem]) -> some View {
        EntryList(
            title: title,
            items: foods,
            allowSwipeActions: false,
            rowContent: { item in
                MealRow(food: item, servingUnits: servingUnits) {
                    if confirmsReplace {
                        pendingFood = item
                    } else {
                        pick(item)
                    }
                }
            }
        )
        .padding([.horizontal, .bottom])
    }
}

struct StartFromMenuItem: View {
    let type: EntryType
    let hasItems: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Start From…", systemImage: "square.on.square")
            Text(hasItems ? copySubtitle : String(localized: "No \(type.rawValue)s yet"))
        }
        .disabled(!hasItems)
    }

    private var copySubtitle: String {
        switch type {
        case .ingredient: String(localized: "Copy an ingredient")
        case .recipe: String(localized: "Copy a recipe")
        case .drink: String(localized: "Copy a drink")
        default: String(localized: "Copy a food")
        }
    }
}

enum ReplaceDetailsMessage {
    static func replaces(_ typedSource: String?, with food: FoodItem) -> Bool {
        guard let typedSource else { return false }
        return typedSource != (food.source?.source ?? "")
    }

    static func text(from food: FoodItem, keepsName: Bool, replacesSource: Bool) -> Text {
        let name = food.name
        switch (replacesSource, keepsName) {
        case (true, true):
            return Text("Your source and other details will be replaced with those from \(name). Name and pinned note are kept.")
        case (true, false):
            return Text("Your source and other details will be replaced with those from \(name). Pinned note is kept.")
        case (false, true):
            return Text("The details you've entered will be replaced with those from \(name). Name and pinned note are kept.")
        case (false, false):
            return Text("The details you've entered will be replaced with those from \(name). Pinned note is kept.")
        }
    }
}

struct ClearFormMenuItem: View {
    let isEnabled: Bool
    var action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            Label("Clear Form", systemImage: "eraser")
        }
        .disabled(!isEnabled)
    }
}

extension View {
    func clearFormAlert(isPresented: Binding<Bool>, onClear: @escaping () -> Void) -> some View {
        alert("Clear Form?", isPresented: isPresented) {
            Button("Clear", role: .destructive, action: onClear)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Everything you've entered will be removed.")
        }
    }
}
