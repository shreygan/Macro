//
//  ImportReviewView.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/31/26.
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ImportReviewView: View {
    @Environment(\.modelContext) private var modelContext

    @Binding var items: [DraftFoodItem]
    @Binding var issues: [ImportIssue]
    @Binding var isLoading: Bool
    @Binding var importAlert: DataTransferAlert?

    @State private var itemToEdit: DraftFoodItem?
    @State private var issueKindToShow: ImportIssue.Kind?
    @State private var recipeToEdit: ImportRecipeEdit?
    @State private var isShowingFilePicker = false
    @State private var duplicateStrategy: DuplicateStrategy = .skip

    var onProcessNewCSV: (URL) -> Void
    var onSaveComplete: () -> Void

    private var newItems: [DraftFoodItem] {
        items.filter { $0.duplicateOf == nil }
    }

    private var duplicateItems: [DraftFoodItem] {
        items.filter { $0.duplicateOf != nil }
    }

    private var itemsToSave: [DraftFoodItem] {
        duplicateStrategy == .skip ? newItems : items
    }

    private var repeatedCount: Int {
        issues.filter { $0.kind == .repeated }.count
    }

    private var skippedRowCount: Int {
        repeatedCount + errorCount
    }

    private var firstIssueKind: ImportIssue.Kind {
        if errorCount > 0 { return .invalid }
        if repeatedCount > 0 { return .repeated }
        return .duplicate
    }

    private var errorCount: Int {
        issues.filter { $0.kind == .invalid }.count
    }

    private var viewState: Int {
        if isLoading { return 0 }
        if items.isEmpty { return 1 }
        return 2
    }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.blue)
                    Text("Reading CSV...")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .id("loading_state")

            } else if items.isEmpty {
                ContentUnavailableView {
                    Label(
                        "No Valid Data",
                        systemImage: "doc.text.magnifyingglass"
                    )
                } description: {
                    Group {
                        if issues.isEmpty {
                            Text("We couldn't parse any entries from your CSV.")
                        } else {
                            let dupes =
                                repeatedCount > 0
                                ? "\(repeatedCount) repeated row\(repeatedCount > 1 ? "s" : "")"
                                : nil
                            let errs =
                                errorCount > 0
                                ? "\(errorCount) invalid row\(errorCount > 1 ? "s" : "")"
                                : nil
                            let reason = [dupes, errs].compactMap { $0 }.joined(
                                separator: " and "
                            )

                            Text(
                                "We skipped \(reason). There are no new entries to import."
                            )
                        }
                    }
                    .font(.subheadline)
                } actions: {
                    VStack(spacing: 12) {
                        Button("Select Another CSV") {
                            isShowingFilePicker = true
                        }
                        .tint(.blue)

                        if !issues.isEmpty {
                            Button("View Skipped Rows") {
                                issueKindToShow = firstIssueKind
                            }
                            .tint(.secondary)
                        }
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .id("empty_state")

            } else {
                ScrollView {
                    importSummaryCard
                        .padding([.horizontal, .bottom])

                    if !newItems.isEmpty {
                        EntryList(
                            title: "New Entries",
                            items: newItems,
                            rowContent: { item in reviewRow(for: item) },
                            onDelete: { item in
                                items.removeAll(where: { $0.id == item.id })
                            },
                            onEdit: { item in beginEditing(item) }
                        )
                        .padding([.horizontal, .bottom])
                    }

                    if duplicateStrategy != .skip && !duplicateItems.isEmpty {
                        EntryList(
                            title: duplicateStrategy == .replace
                                ? "Will Replace Existing" : "Will Import as Copies",
                            items: duplicateItems,
                            rowContent: { item in reviewRow(for: item) },
                            onDelete: { item in
                                items.removeAll(where: { $0.id == item.id })
                            },
                            onEdit: { item in beginEditing(item) }
                        )
                        .padding([.horizontal, .bottom])
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .id("list_state")
            }
        }
        .animation(.snappy, value: viewState)
        .animation(.snappy, value: duplicateStrategy)
        .withGlobalSwipeDismissal()
        .navigationTitle("Review Import (\(itemsToSave.count))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    saveAllToDatabase()
                } label: {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.primary)
                }
                .tint(Color.blue)
                .buttonStyle(.glassProminent)
                .disabled(itemsToSave.isEmpty)
            }
        }
        .sheet(item: $itemToEdit) { editingItem in
            let dummy = FoodItem(
                name: "",
                servingSize: 1.0,
                servingWeightUnit: "",
                isAIEstimated: false,
                calories: 0,
                protein: 0,
                carbs: 0,
                fat: 0,
                fiber: 0,
                isCustomDefaultServing: false
            )

            EditEntryView(
                foodItem: dummy,
                draftItem: editingItem,
                isImportMode: true,
                onImportSave: { updatedDraft in
                    if let index = items.firstIndex(where: {
                        $0.id == editingItem.id
                    }) {
                        items[index] = merged(updatedDraft, into: items[index])
                    }
                }
            )
        }
        .sheet(item: $recipeToEdit) { edit in
            EditRecipeView(
                recipe: edit.recipe,
                isImportMode: true,
                onImportSave: { updatedDraft in
                    if let index = items.firstIndex(where: {
                        $0.id == edit.draftID
                    }) {
                        items[index] = merged(updatedDraft, into: items[index])
                    }
                }
            )
        }
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: [.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let fileURL = urls.first else { return }
                onProcessNewCSV(fileURL)
            case .failure(let error):
                importAlert = .selectionFailed(error)
            }
        }
        .sheet(item: $issueKindToShow) { kind in
            ImportIssuesView(
                kind: kind,
                issues: issues.filter { $0.kind == kind }
            )
        }
        .dataTransferAlert($importAlert)
    }

    @ViewBuilder
    private var importSummaryCard: some View {
        let recipes = newItems.filter { $0.type == .recipe }
        let ingredientCount = recipes.reduce(0) { $0 + $1.ingredients.count }

        Card("Summary", cornerRadius: 20) {
            RowGroup(.divider) {
                BaseRowLayout(
                    icon: .customSymbol("checkmark.circle.fill", tint: .green),
                    title: "New Entries",
                    subtitle: recipes.isEmpty
                        ? "Not in your library yet"
                        : "Includes \(recipes.count) recipe\(recipes.count == 1 ? "" : "s") with \(ingredientCount) ingredient\(ingredientCount == 1 ? "" : "s")"
                ) {
                    Text("\(newItems.count)")
                }

                let favoriteCount = itemsToSave.filter(\.isFavorite).count
                if favoriteCount > 0 {
                    BaseRowLayout(
                        icon: .customSymbol("star.fill", tint: .yellow),
                        title: "Favorites",
                        subtitle: "Added to the end of your favorites"
                    ) {
                        Text("\(favoriteCount)")
                    }
                }

                if !duplicateItems.isEmpty {
                    Button {
                        issueKindToShow = .duplicate
                    } label: {
                        BaseRowLayout(
                            icon: .customSymbol(
                                "square.on.square.intersection.dashed"
                            ),
                            title: "Duplicates",
                            subtitle: "Entries already in your library"
                        ) {
                            ImportIssueCount(count: duplicateItems.count)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    DuplicateStrategyRow(strategy: $duplicateStrategy)
                }

                if repeatedCount > 0 {
                    Button {
                        issueKindToShow = .repeated
                    } label: {
                        BaseRowLayout(
                            icon: .customSymbol("arrow.2.squarepath"),
                            title: "Repeated Rows",
                            subtitle: "Only the first copy is imported"
                        ) {
                            ImportIssueCount(count: repeatedCount)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                if errorCount > 0 {
                    Button {
                        issueKindToShow = .invalid
                    } label: {
                        BaseRowLayout(
                            icon: .customSymbol(
                                "exclamationmark.triangle.fill",
                                tint: .red
                            ),
                            title: "Errors",
                            subtitle: "Rows that couldn't be read"
                        ) {
                            ImportIssueCount(count: errorCount)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func reviewRow(for item: DraftFoodItem) -> some View {

        let activeMultiplier: Double = {
            guard item.isCustomDefaultServing,
                let target = item.customServingSize
            else {
                return 1.0
            }
            return EntryHelper.calculateMultiplier(
                targetPortion: target,
                basePortion: item.servingSize
            )
        }()

        let formatDropZero: (Double?) -> String = { value in
            guard let value = value else { return "" }
            return value.formatted(.number.precision(.fractionLength(0...1)))
        }

        MealRow(
            name: item.name,
            source: item.source,
            isCustomDefaultServing: item.isCustomDefaultServing,
            customServingSize: formatDropZero(item.customServingSize),
            servingSize: formatDropZero(item.servingSize),
            servingSizeUnit: item.servingUnit,
            servingWeight: formatDropZero(item.servingWeight),
            servingWeightUnit: item.servingWeightUnit,
            servingUnits: [],
            calorie: formatDropZero(item.calories * activeMultiplier),
            protein: formatDropZero(item.protein * activeMultiplier),
            carbs: formatDropZero(item.carbs * activeMultiplier),
            fat: formatDropZero(item.fat * activeMultiplier),
            fiber: formatDropZero(item.fiber * activeMultiplier),
            icon: item.type == .food ? nil : item.type.appSymbol
        ) {
            beginEditing(item)
        }
    }

    private func beginEditing(_ item: DraftFoodItem) {
        if item.type == .recipe,
            let recipe = ImportRecipeScratch.makeRecipe(from: item)
        {
            recipeToEdit = ImportRecipeEdit(draftID: item.id, recipe: recipe)
        } else {
            itemToEdit = item
        }
    }

    private func merged(_ edited: DraftFoodItem, into original: DraftFoodItem)
        -> DraftFoodItem
    {
        var result = edited
        let originalNote = (original.stickyNote ?? "").trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        result.isFavorite = original.isFavorite
        result.favoriteOrder = original.favoriteOrder
        result.importID = original.importID
        result.duplicateOf = original.duplicateOf
        result.servingUnitPlural =
            edited.servingUnit == original.servingUnit
            ? original.servingUnitPlural : nil
        result.noteUpdated =
            edited.stickyNote == originalNote ? original.noteUpdated : nil
        result.dateAdded = original.dateAdded
        if edited.ingredients.isEmpty {
            result.ingredients = original.ingredients
        }
        if original.type == .recipe { result.type = .recipe }

        return result
    }

    private func saveAllToDatabase() {
        let resolver = ImportResolver(context: modelContext)
        let existingItems =
            (try? modelContext.fetch(FetchDescriptor<FoodItem>())) ?? []
        var library = existingItems
        var itemsByID = Dictionary(
            existingItems.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var saved: [(draft: DraftFoodItem, item: FoodItem)] = []

        var replacedIDs = Set<UUID>()

        for draft in itemsToSave {
            if duplicateStrategy == .replace, let existingID = draft.duplicateOf,
                let existing = itemsByID[existingID],
                replacedIDs.insert(existingID).inserted
            {
                apply(draft, to: existing, resolver: resolver)
                if !draft.ingredients.isEmpty {
                    for ingredient in existing.recipeIngredients ?? [] {
                        modelContext.delete(ingredient)
                    }
                    existing.recipeIngredients = []
                }
                saved.append((draft, existing))
            } else {
                let resolvedID =
                    draft.duplicateOf == nil
                    ? draft.importID.flatMap { itemsByID[$0] == nil ? $0 : nil }
                        ?? UUID()
                    : UUID()
                let newFood = makeFoodItem(
                    from: draft,
                    id: resolvedID,
                    resolver: resolver
                )

                modelContext.insert(newFood)
                itemsByID[newFood.id] = newFood
                library.append(newFood)
                saved.append((draft, newFood))
            }
        }

        for (draft, recipe) in saved where !draft.ingredients.isEmpty {
            for (index, ingredient) in draft.ingredients.enumerated() {
                let recipeIngredient = RecipeIngredient(
                    quantity: ingredient.quantity,
                    unit: ingredient.unit,
                    displayOrder: index,
                    name: ingredient.name,
                    baseServingSize: ingredient.baseServingSize,
                    baseServingUnitName: ingredient.baseServingUnitName,
                    baseServingWeight: ingredient.baseServingWeight,
                    baseServingWeightUnit: ingredient.baseServingWeightUnit,
                    baseCalories: ingredient.baseCalories,
                    baseProtein: ingredient.baseProtein,
                    baseCarbs: ingredient.baseCarbs,
                    baseFat: ingredient.baseFat,
                    baseFiber: ingredient.baseFiber
                )

                recipeIngredient.ingredientItem = resolveIngredientItem(
                    for: ingredient,
                    itemsByID: &itemsByID,
                    library: &library,
                    resolver: resolver
                )
                recipeIngredient.parentRecipe = recipe

                modelContext.insert(recipeIngredient)
            }
        }

        let existingFavorites =
            (try? modelContext.fetch(FetchDescriptor<FavoriteEntry>())) ?? []
        var nextFavoriteOrder =
            (existingFavorites.map(\.orderIndex).max() ?? -1) + 1
        let importedFavorites = saved
            .filter { $0.draft.isFavorite && $0.item.favoriteEntry == nil }
            .sorted {
                ($0.draft.favoriteOrder ?? .max)
                    < ($1.draft.favoriteOrder ?? .max)
            }

        for favorite in importedFavorites {
            modelContext.insert(
                FavoriteEntry(
                    orderIndex: nextFavoriteOrder,
                    foodItem: favorite.item
                )
            )
            nextFavoriteOrder += 1
        }

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            importAlert = .saveFailed(error)
            return
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onSaveComplete()
    }

    private func apply(
        _ draft: DraftFoodItem,
        to food: FoodItem,
        resolver: ImportResolver
    ) {
        let noteText = (draft.stickyNote ?? "").trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        food.name = draft.name
        if !(food.type == .recipe && draft.ingredients.isEmpty) {
            food.type = draft.type
        }
        food.source = resolver.source(draft.source)
        food.category = resolver.category(draft.category)
        food.foodGroup = resolver.foodGroup(draft.foodGroup)
        food.servingSize = draft.servingSize
        food.servingUnit = resolver.unit(
            draft.servingUnit,
            plural: draft.servingUnitPlural
        )
        food.servingWeight = draft.servingWeight
        food.servingWeightUnit = draft.servingWeightUnit
        food.isAIEstimated = draft.isAIEstimated
        food.calories = draft.calories
        food.protein = draft.protein
        food.carbs = draft.carbs
        food.fat = draft.fat
        food.fiber = draft.fiber
        food.isCustomDefaultServing = draft.isCustomDefaultServing
        food.customServingSize = draft.customServingSize

        if noteText.isEmpty {
            food.stickyNote = nil
        } else if let note = food.stickyNote {
            note.text = noteText
            note.lastUpdated = draft.noteUpdated ?? Date()
        } else {
            food.stickyNote = Note(
                text: noteText,
                lastUpdated: draft.noteUpdated ?? Date()
            )
        }
    }

    private func makeFoodItem(
        from draft: DraftFoodItem,
        id: UUID,
        resolver: ImportResolver
    ) -> FoodItem {
        let draftNoteText = (draft.stickyNote ?? "").trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let resolvedStickyNote =
            draftNoteText.isEmpty
            ? nil
            : Note(text: draftNoteText, lastUpdated: draft.noteUpdated ?? Date())

        return FoodItem(
            id: id,
            name: draft.name,
            type: draft.type,
            source: resolver.source(draft.source),
            category: resolver.category(draft.category),
            foodGroup: resolver.foodGroup(draft.foodGroup),
            servingSize: draft.servingSize,
            servingUnit: resolver.unit(
                draft.servingUnit,
                plural: draft.servingUnitPlural
            ),
            servingWeight: draft.servingWeight,
            servingWeightUnit: draft.servingWeightUnit,
            isAIEstimated: draft.isAIEstimated,
            calories: draft.calories,
            protein: draft.protein,
            carbs: draft.carbs,
            fat: draft.fat,
            fiber: draft.fiber,
            isCustomDefaultServing: draft.isCustomDefaultServing,
            customServingSize: draft.customServingSize,
            stickyNote: resolvedStickyNote,
            dateAdded: draft.dateAdded ?? Date()
        )
    }

    private func resolveIngredientItem(
        for ingredient: DraftImportIngredient,
        itemsByID: inout [UUID: FoodItem],
        library: inout [FoodItem],
        resolver: ImportResolver
    ) -> FoodItem {
        if let id = ingredient.linkedItemID, let linked = itemsByID[id] {
            return linked
        }

        if let match = resolver.matchFood(
            id: nil,
            name: ingredient.name,
            source: ingredient.linkedItemSource,
            in: library
        ) {
            return match
        }

        let fallbackType = ingredient.linkedItemType ?? .ingredient
        let fallback = FoodItem(
            id: ingredient.linkedItemID ?? UUID(),
            name: ingredient.name,
            type: fallbackType == .recipe ? .food : fallbackType,
            source: resolver.source(ingredient.linkedItemSource),
            servingSize: ingredient.baseServingSize,
            servingUnit: resolver.unit(
                ingredient.baseServingUnitName ?? "serving",
                plural: nil
            ),
            servingWeight: ingredient.baseServingWeight,
            servingWeightUnit: ingredient.baseServingWeightUnit,
            isAIEstimated: false,
            calories: ingredient.baseCalories,
            protein: ingredient.baseProtein,
            carbs: ingredient.baseCarbs,
            fat: ingredient.baseFat,
            fiber: ingredient.baseFiber,
            isCustomDefaultServing: false
        )

        modelContext.insert(fallback)
        itemsByID[fallback.id] = fallback
        library.append(fallback)
        return fallback
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var mockItems = [
            DraftFoodItem(
                name: "Double Chicken Bowl",
                source: "Chipotle",
                category: "Meals",
                foodGroup: "",
                servingSize: 1.0,
                servingUnit: "bowl",
                servingWeight: nil,
                servingWeightUnit: "g",
                isAIEstimated: false,
                calories: 1050,
                protein: 85.0,
                carbs: 80.0,
                fat: 42.0,
                fiber: 15.0,
                isCustomDefaultServing: false,
                customServingSize: nil,
                isFavorite: true
            ),
            DraftFoodItem(
                name: "Paneer Paratha",
                source: "Mom's Cooking",
                category: "Meals",
                foodGroup: "",
                servingSize: 1.0,
                servingUnit: "paratha",
                servingWeight: 150.0,
                servingWeightUnit: "g",
                isAIEstimated: false,
                calories: 350,
                protein: 12.0,
                carbs: 40.0,
                fat: 15.0,
                fiber: 4.0,
                isCustomDefaultServing: false,
                customServingSize: nil
            ),
            DraftFoodItem(
                name: "Protein Shake",
                source: "Optimum Nutrition",
                category: "Supplements",
                foodGroup: "",
                servingSize: 1.0,
                servingUnit: "scoop",
                servingWeight: 31.0,
                servingWeightUnit: "g",
                isAIEstimated: false,
                calories: 160,
                protein: 30.0,
                carbs: 4.0,
                fat: 2.0,
                fiber: 1.0,
                isCustomDefaultServing: false,
                customServingSize: nil
            ),
        ]

        @State private var isLoading = false

        var body: some View {
            NavigationStack {
                ImportReviewView(
                    items: $mockItems,
                    issues: .constant([]),
                    isLoading: $isLoading,
                    importAlert: .constant(nil),
                    onProcessNewCSV: { url in
                        print("Preview: Would process new CSV at \(url)")
                    },
                    onSaveComplete: {
                        print("Preview: Save completed")
                    }
                )
            }
            .modelContainer(
                for: [
                    FoodItem.self, EntrySource.self, ServingSizeUnit.self,
                ],
                inMemory: true
            )
        }
    }

    return PreviewWrapper()
}
