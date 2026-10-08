//
//  FoodDetailView.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/2/26.
//

import SwiftData
import SwiftUI

struct FoodDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.tabBarHeight) private var tabBarHeight

    let food: FoodItem
    var isPushedView: Bool = true

    @Query private var logs: [LoggedEntry]
    @Query private var recipeUses: [RecipeIngredient]
    @Query(sort: \ServingSizeUnit.displayOrder) private var portionUnitOptions:
        [ServingSizeUnit]

    @State private var foodToLog: FoodItem? = nil
    @State private var foodToEdit: FoodItem? = nil
    @State private var foodToDelete: FoodItem? = nil
    @State private var showDeleteAlert = false
    @State private var showingAllNotes = false
    @State private var selectedEntry: LoggedEntry? = nil
    @State private var isDismissing = false

    private let recentLogLimit = 5

    init(food: FoodItem, isPushedView: Bool = true) {
        self.food = food
        self.isPushedView = isPushedView

        let foodID = food.id
        _logs = Query(FoodItemStore.topLevelLogsDescriptor(for: food))
        _recipeUses = Query(
            filter: #Predicate<RecipeIngredient> {
                $0.ingredientItem?.id == foodID
            }
        )
    }

    private var isAvailable: Bool {
        !food.isDeleted && food.modelContext != nil
    }

    private var typeName: String {
        food.type.rawValue.capitalized
    }

    private var pinnedNote: Note? {
        guard let note = food.stickyNote, !note.text.isEmpty else { return nil }
        return note
    }

    private var noteCount: Int {
        let logNotes = logs.filter { !($0.logNote ?? "").isEmpty }.count
        return logNotes + (pinnedNote == nil ? 0 : 1)
    }

    private var ingredients: [RecipeIngredient] {
        (food.recipeIngredients ?? []).sorted {
            $0.displayOrder < $1.displayOrder
        }
    }

    private var usedInRecipes: [FoodItem] {
        var seen = Set<UUID>()
        return recipeUses.compactMap(\.parentRecipe)
            .filter { seen.insert($0.id).inserted }
            .sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }

    private var usualPortion: String? {
        let portions = logs.map { portionText($0.loggedQuantity, $0.loggedUnit) }
        let counts = portions.reduce(into: [String: Int]()) {
            $0[$1, default: 0] += 1
        }
        return portions.max {
            counts[$0, default: 0] < counts[$1, default: 0]
        }
    }

    private var servingUnitName: String {
        food.servingUnit?.unit ?? "serving"
    }

    private var servingText: String {
        var text = portionText(food.servingSize, servingUnitName)
        if let weight = food.servingWeight {
            text += " · \(EntryHelper.format(weight)) \(food.servingWeightUnit)"
        }
        return text
    }

    private func portionText(_ quantity: Double, _ unit: String) -> String {
        EntryHelper.portionText(
            quantity: quantity,
            unit: unit,
            servingUnits: portionUnitOptions
        )
    }

    private func dismissOnce() {
        guard !isDismissing else { return }
        isDismissing = true
        dismiss()
    }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            if isAvailable {
                content
            } else {
                Color.clear
                    .onAppear { dismissOnce() }
            }
        }
        .navigationTitle(isAvailable ? food.name : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isAvailable {
                    Menu {
                        FoodActionMenuItems(
                            food: food,
                            onEdit: { foodToEdit = food },
                            onDelete: {
                                foodToDelete = food
                                showDeleteAlert = true
                            }
                        )
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }

            if !isPushedView {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .sheet(item: $foodToLog) { food in
            LogFoodSheet(food: food)
        }
        .sheet(item: $foodToEdit) { food in
            if food.type == .recipe {
                EditRecipeView(recipe: food)
            } else {
                EditEntryView(foodItem: food)
            }
        }
        .sheet(item: $selectedEntry) { entry in
            NavigationStack {
                LoggedEntryDetailView(entry: entry, isPushedView: false)
            }
            .environment(\.tabBarHeight, 0)
        }
        .sheet(isPresented: $showingAllNotes) {
            NavigationStack {
                VStack(spacing: 20) {
                    Image(systemName: "note.text")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("TODO: View All Notes Implementation")
                        .foregroundStyle(.secondary)
                }
                .navigationTitle("All Notes")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium, .large])
        }
        .deleteFoodAlert(
            isPresented: $showDeleteAlert,
            food: $foodToDelete,
            onWillDelete: { dismissOnce() }
        )
    }

    private var content: some View {
        ScrollView {
            VStack {
                actionStrip
                    .padding(.horizontal)
                    .padding(.bottom, 6)

                Card("Details") {
                    RowGroup(.divider) {
                        detailRow("Type", value: typeName)

                        if let source = food.source?.source {
                            detailRow("Source", value: source)
                        }

                        if let category = food.category?.category {
                            detailRow("Category", value: category)
                        }

                        if let foodGroup = food.foodGroup?.foodGroup {
                            detailRow("Food Group", value: foodGroup)
                        }

                        detailRow("Serving", value: servingText)

                        if food.isCustomDefaultServing,
                            let customServing = food.customServingSize
                        {
                            detailRow(
                                "Default Portion",
                                value: portionText(customServing, servingUnitName)
                            )
                        }

                        detailRow(
                            "Added",
                            value: food.dateAdded.formatted(
                                date: .abbreviated,
                                time: .omitted
                            )
                        )

                        if food.isAIEstimated {
                            detailRow("AI Estimated", value: "Yes")
                        }
                    }
                }
                .padding([.horizontal])

                if noteCount > 0 {
                    Card("Notes") {
                        RowGroup(.divider) {
                            if let pinnedNote {
                                WrappedInputRow(
                                    placeholder: "",
                                    text: .constant(pinnedNote.text),
                                    isSticky: true,
                                    timestamp: pinnedNote.lastUpdated,
                                    isEditable: false
                                )
                            }

                            Button {
                                showingAllNotes = true
                            } label: {
                                BaseRowLayout(title: "All Notes") {
                                    HStack(spacing: 8) {
                                        Text(noteCount.formatted())
                                            .font(.system(size: 16))
                                            .foregroundStyle(.secondary)

                                        Image(systemName: "chevron.right")
                                            .font(
                                                .system(size: 14, weight: .semibold)
                                            )
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding([.top, .horizontal])
                }

                if food.type == .recipe && !ingredients.isEmpty {
                    Card("Ingredients") {
                        RowGroup(.divider) {
                            ForEach(ingredients) { ingredient in
                                ingredientRow(ingredient)
                            }
                        }
                    }
                    .padding([.top, .horizontal])
                }

                if !usedInRecipes.isEmpty {
                    Card("Used In") {
                        RowGroup(.divider) {
                            ForEach(usedInRecipes) { recipe in
                                NavigationLink {
                                    FoodDetailView(food: recipe)
                                } label: {
                                    NavigationRow(
                                        icon: .appSymbol(.recipe),
                                        title: recipe.name
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding([.top, .horizontal])
                }

                if let lastLog = logs.first {
                    historyCard(lastLog: lastLog)
                        .padding([.top, .horizontal])
                }
            }
            .padding(.bottom)
        }
        .contentMargins(
            .bottom,
            tabBarHeight > 0 ? tabBarHeight + 12 : 0,
            for: .scrollContent
        )
        .contentMargins(.bottom, tabBarHeight, for: .scrollIndicators)
        .ignoresSafeArea(edges: tabBarHeight > 0 ? .bottom : [])
        .safeAreaInset(edge: .top) {
            Card {
                MealRow(
                    food: food,
                    servingUnits: portionUnitOptions,
                    icon: food.type.appSymbol
                )
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
            .background(.ultraThinMaterial)
        }
    }

    private var actionStrip: some View {
        return GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    foodToLog = food
                } label: {
                    Label("Log \(typeName)", systemImage: "plus")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                }
                .buttonStyle(.glassProminent)
            }
        }
    }

    private func historyCard(lastLog: LoggedEntry) -> some View {
        Card("History") {
            RowGroup(.divider) {
                detailRow("Times Logged", value: logs.count.formatted())

                BaseRowLayout(title: "Last Logged") {
                    Text(lastLog.timestamp, format: .relative(presentation: .named))
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }

                if let usualPortion {
                    detailRow("Usual Portion", value: usualPortion)
                }

                ForEach(Array(logs.prefix(recentLogLimit))) { entry in
                    LoggedEntrySummaryRow(
                        entry: entry,
                        servingUnits: portionUnitOptions
                    ) {
                        selectedEntry = entry
                    }
                }

                if logs.count > recentLogLimit {
                    NavigationLink {
                        FoodLogsView(food: food)
                    } label: {
                        NavigationRow(title: "See All Logs")
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func ingredientRow(_ ingredient: RecipeIngredient) -> some View {
        let multiplier = EntryHelper.ingredientMultiplier(
            quantity: ingredient.quantity,
            unit: ingredient.unit,
            baseServingSize: ingredient.baseServingSize,
            baseServingWeight: ingredient.baseServingWeight,
            baseServingWeightUnit: ingredient.baseServingWeightUnit
        )
        let calories =
            multiplier.isFinite ? ingredient.baseCalories * multiplier : 0

        let row = BaseRowLayout(
            icon: .appSymbol(
                ingredient.ingredientItem?.type.appSymbol ?? .ingredient,
                tint: .secondary
            ),
            title: ingredient.name,
            subtitle: portionText(ingredient.quantity, ingredient.unit)
        ) {
            HStack(spacing: 8) {
                Text("\(EntryHelper.formatMacro(calories)) kcal")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                if ingredient.ingredientItem != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }

        if let item = ingredient.ingredientItem {
            NavigationLink {
                FoodDetailView(food: item)
            } label: {
                row.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            row
        }
    }

    private func detailRow(_ title: String, value: String) -> some View {
        BaseRowLayout(title: title) {
            Text(value)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private struct LoggedEntrySummaryRow: View {
    let entry: LoggedEntry
    let servingUnits: [ServingSizeUnit]
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            BaseRowLayout(
                title: entry.timestamp.formatted(
                    date: .abbreviated,
                    time: .shortened
                ),
                subtitle: EntryHelper.portionText(
                    quantity: entry.loggedQuantity,
                    unit: entry.loggedUnit,
                    servingUnits: servingUnits
                )
            ) {
                HStack(spacing: 8) {
                    Text("\(EntryHelper.formatMacro(entry.calories)) kcal")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct FoodLogsView: View {
    @Query private var logs: [LoggedEntry]
    @Query(sort: \ServingSizeUnit.displayOrder) private var portionUnitOptions:
        [ServingSizeUnit]

    @State private var selectedEntry: LoggedEntry? = nil

    init(food: FoodItem) {
        _logs = Query(FoodItemStore.topLevelLogsDescriptor(for: food))
    }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            ScrollView {
                Card {
                    RowGroup(.divider) {
                        ForEach(logs) { entry in
                            LoggedEntrySummaryRow(
                                entry: entry,
                                servingUnits: portionUnitOptions
                            ) {
                                selectedEntry = entry
                            }
                        }
                    }
                }
                .padding([.horizontal, .bottom])
            }
        }
        .navigationTitle("All Logs")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedEntry) { entry in
            NavigationStack {
                LoggedEntryDetailView(entry: entry, isPushedView: false)
            }
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: FoodItem.self,
        LoggedEntry.self,
        FavoriteEntry.self,
        ServingSizeUnit.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext

    let rice = FoodItem(
        name: "Brown Rice",
        type: .ingredient,
        servingSize: 1,
        servingWeight: 195,
        servingWeightUnit: "g",
        isAIEstimated: false,
        calories: 216,
        protein: 5,
        carbs: 45,
        fat: 1.8,
        fiber: 3.5,
        isCustomDefaultServing: false,
        stickyNote: Note(text: "Rinse before cooking")
    )
    context.insert(rice)

    for dayOffset in 0..<7 {
        context.insert(
            LoggedEntry(
                name: rice.name,
                typeRawValue: rice.type.rawValue,
                originalFoodItem: rice,
                timestamp: Date().addingTimeInterval(Double(-dayOffset) * 86400),
                loggedQuantity: dayOffset.isMultiple(of: 3) ? 2 : 1,
                loggedUnit: "serving",
                calories: 216,
                protein: 5,
                carbs: 45,
                fat: 1.8,
                fiber: 3.5
            )
        )
    }

    return NavigationStack {
        FoodDetailView(food: rice)
    }
    .modelContainer(container)
}
