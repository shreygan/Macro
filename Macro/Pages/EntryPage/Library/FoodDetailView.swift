//
//  FoodDetailView.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/2/26.
//

import SwiftData
import SwiftUI

struct FoodDetailView: View {
    var isPushedView: Bool = true

    @State private var food: FoodItem

    init(food: FoodItem, isPushedView: Bool = true) {
        _food = State(initialValue: food)
        self.isPushedView = isPushedView
    }

    var body: some View {
        FoodDetailContent(food: food, isPushedView: isPushedView) { kept in
            food = kept
        }
        .id(food.id)
    }
}

private struct FoodDetailContent: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.tracksHydration) private var tracksHydration
    @Environment(\.dismiss) private var dismiss
    @Environment(\.toastCenter) private var toastCenter

    let food: FoodItem
    var isPushedView: Bool = true
    var onMerged: (FoodItem) -> Void = { _ in }

    @Query private var logs: [LoggedEntry]
    @Query private var drafts: [EntryDraft]
    @Query private var recipeUses: [RecipeIngredient]
    @Query private var users: [User]
    @Query(sort: \ServingSizeUnit.displayOrder) private var portionUnitOptions:
        [ServingSizeUnit]

    @State private var foodToLog: FoodItem? = nil
    @State private var draftToResume: EntryDraft? = nil
    @State private var foodToEdit: FoodItem? = nil
    @State private var foodToDelete: FoodItem? = nil
    @State private var foodToMerge: FoodItem? = nil
    @State private var foodToDuplicate: FoodItem? = nil
    @State private var pendingMerge: FoodMergePlan? = nil
    @State private var showingAllNotes = false
    @State private var showingAllPhotos = false
    @State private var photoFramingWidth: CGFloat = 0
    @State private var selectedEntry: LogSelection? = nil
    @State private var entryToLogAgain: LoggedEntry? = nil
    @State private var foodToShow: FoodItem? = nil
    @State private var showingAllLogs = false
    @State private var showingAllDrafts = false
    @State private var placeToShow: EntryLocation? = nil
    @State private var showingAllPlaces = false
    @State private var showingAllRecipes = false
    @State private var recipeLogStats: [UUID: FoodLogStats] = [:]
    @State private var showingMap = false
    @State private var isDismissing = false
    @State private var headerHeight: CGFloat = 0
    @State private var pageHeight: CGFloat = 0
    @State private var hydrationDay: HydrationDayRequest? = nil

    private let recentLogLimit = 5
    private let recentDraftLimit = 3
    private let usedInLimit = 3
    private let maxPinnedHeaderFraction: CGFloat = 0.25

    private var isHeaderPinned: Bool {
        pageHeight == 0 || headerHeight <= pageHeight * maxPinnedHeaderFraction
    }

    init(
        food: FoodItem,
        isPushedView: Bool = true,
        onMerged: @escaping (FoodItem) -> Void = { _ in }
    ) {
        self.food = food
        self.isPushedView = isPushedView
        self.onMerged = onMerged

        let foodID = food.id
        _logs = Query(FoodItemStore.topLevelLogsDescriptor(for: food))
        let logFood = DraftKind.logFood.rawValue
        let logRecipe = DraftKind.logRecipe.rawValue
        _drafts = Query(
            filter: #Predicate<EntryDraft> {
                $0.foodItem?.id == foodID
                    && ($0.kindRawValue == logFood
                        || $0.kindRawValue == logRecipe)
            },
            sort: \EntryDraft.updatedAt,
            order: .reverse
        )
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

    private var usedInRecipes: [UsedInRecipe] {
        let stats = recipeLogStats
        return UsedInRecipe.recipes(from: recipeUses).sorted { lhs, rhs in
            let lhsStats = stats[lhs.id]
            let rhsStats = stats[rhs.id]
            if lhsStats?.count != rhsStats?.count {
                return (lhsStats?.count ?? 0) > (rhsStats?.count ?? 0)
            }
            if lhsStats?.lastLogged != rhsStats?.lastLogged {
                return (lhsStats?.lastLogged ?? .distantPast)
                    > (rhsStats?.lastLogged ?? .distantPast)
            }
            return lhs.recipe.name.localizedStandardCompare(rhs.recipe.name)
                == .orderedAscending
        }
    }

    private var usedInRecipeIDs: [UUID] {
        UsedInRecipe.recipes(from: recipeUses).map(\.id)
    }

    private func performPendingMerge() {
        guard let plan = pendingMerge else { return }
        pendingMerge = nil
        if EntryActions.merge(plan, in: modelContext, toastCenter: toastCenter) {
            onMerged(plan.kept)
        }
    }

    private func refreshRecipeLogStats() {
        let recipes = UsedInRecipe.recipes(from: recipeUses).map(\.recipe)
        guard recipes.count > usedInLimit else {
            recipeLogStats = [:]
            return
        }
        recipeLogStats = FoodItemStore.logStats(for: recipes, in: modelContext)
    }

    private var isDrink: Bool {
        food.type == .drink
    }

    private var usualPortion: String? {
        guard let usual = PortionKey.usual(in: logs) else { return nil }
        let text = portionText(usual.quantity, usual.unit)
        guard isDrink, usual.unit == VolumeUnit.milliliters.rawValue,
            let name = HydrationLogger.sizeName(for: food, volumeML: usual.quantity),
            !name.isEmpty
        else { return text }
        return "\(name) · \(text)"
    }

    private var dailyAverage: String? {
        let drinkLogs = logs.filter { $0.volumeML > 0 }
        guard !drinkLogs.isEmpty else { return nil }
        let calendar = Calendar.current
        let days = Set(drinkLogs.map {
            calendar.logicalDay(for: $0.timestamp, dayStartMinutes: dayStartMinutes)
        })
        guard days.count >= 2 else { return nil }
        let total = drinkLogs.reduce(0) { $0 + $1.volumeML }
        return volumeUnit.formattedCompactAmount(total / Double(days.count))
    }

    private var caffeineText: String? {
        guard let caffeine = food.caffeineMg else { return nil }
        let amount = EntryHelper.format(caffeine)
        if let name = food.defaultDrinkSize?.name, !name.isEmpty {
            return String(localized: "\(amount) mg per \(name)")
        }
        if let volume = food.servingVolumeML {
            return String(localized: "\(amount) mg per \(volumeUnit.formattedAmount(volume))")
        }
        return String(localized: "\(amount) mg per serving")
    }

    private var sizeItems: [DrinkSizeItem] {
        let sizes = food.sortedDrinkSizes
        guard !sizes.isEmpty else {
            guard let volume = food.servingVolumeML, volume > 0 else { return [] }
            return [DrinkSizeItem(id: food.id, name: nil, volumeML: volume, isServing: true)]
        }
        return (sizes.filter(\.isDefault) + sizes.filter { !$0.isDefault }).map {
            DrinkSizeItem(
                id: $0.id,
                name: $0.name.flatMap { $0.isEmpty ? nil : $0 },
                volumeML: $0.volumeML,
                isServing: $0.isDefault
            )
        }
    }

    private func sizeFacts(_ volumeML: Double) -> String? {
        guard let serving = food.servingVolumeML, serving > 0 else { return nil }
        return DrinkRowInfo(
            food: food,
            amounts: DrinkAmounts(food: food, multiplier: volumeML / serving),
            hasMacros: false
        )
        .factsText(unit: volumeUnit, includesHydration: false)
    }


    private var servingUnitName: String {
        food.servingUnit?.unit ?? "serving"
    }

    private var volumeUnit: VolumeUnit {
        users.first?.volumeUnit ?? .localeDefault
    }

    private var dayStartMinutes: Int {
        users.first?.dayStartMinutes ?? 0
    }

    private func logAgain(_ entry: LoggedEntry) {
        guard EntryActions.opensAsHydrationLog(entry, tracksHydration: tracksHydration) else {
            entryToLogAgain = entry
            return
        }
        EntryActions.logHydrationAgain(
            entry,
            dayStartMinutes: dayStartMinutes,
            unit: users.first?.volumeUnit ?? .localeDefault,
            in: modelContext,
            toastCenter: toastCenter
        )
    }

    private var historyItems: [LogHistoryItem] {
        LogHistoryItem.items(from: logs, dayStartMinutes: dayStartMinutes, groupsHydrationLogs: tracksHydration)
    }

    private var servingText: String {
        var text = portionText(food.servingSize, servingUnitName)
        if let volume = food.servingVolumeML {
            text += " · \(volumeUnit.formattedAmount(volume))"
        } else if let weight = food.servingWeight {
            text += " · \(EntryHelper.format(weight)) \(food.servingWeightUnit)"
        }
        return text
    }

    private func portionText(_ quantity: Double, _ unit: String) -> String {
        EntryHelper.portionText(
            quantity: quantity,
            unit: unit,
            servingUnits: portionUnitOptions,
            volumeUnit: volumeUnit
        )
    }

    private func deleteDraft(_ draft: EntryDraft) {
        DispatchQueue.main.async {
            EntryActions.delete(draft, in: modelContext, toastCenter: toastCenter)
        }
    }

    private func deleteEntry(_ entry: LoggedEntry) {
        DispatchQueue.main.async {
            EntryActions.delete(entry, in: modelContext, toastCenter: toastCenter)
        }
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
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { height in
            pageHeight = height
        }
        .onAppear { refreshRecipeLogStats() }
        .onChange(of: usedInRecipeIDs) { refreshRecipeLogStats() }
        .withGlobalSwipeDismissal()
        .navigationTitle(isAvailable ? typeName : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isAvailable {
                    Menu {
                        FoodActionMenuItems(
                            food: food,
                            onEdit: { foodToEdit = food },
                            onDuplicate: { foodToDuplicate = food },
                            onMerge: { foodToMerge = food },
                            onDelete: {
                                foodToDelete = food
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
        .navigationDestination(item: $foodToShow) { food in
            FoodDetailView(food: food)
        }
        .navigationDestination(isPresented: $showingAllLogs) {
            FoodLogsView(food: food)
        }
        .navigationDestination(isPresented: $showingAllDrafts) {
            FoodDraftsView(food: food)
        }
        .navigationDestination(item: $placeToShow) { place in
            FoodLogsView(food: food, place: place)
        }
        .navigationDestination(isPresented: $showingAllPlaces) {
            FoodPlacesView(food: food)
        }
        .navigationDestination(isPresented: $showingMap) {
            FoodLocationsMapView(food: food)
        }
        .navigationDestination(isPresented: $showingAllRecipes) {
            FoodRecipesView(food: food)
        }
        .navigationDestination(isPresented: $showingAllNotes) {
            NotesHistoryView(food: food, isPushedView: true)
        }
        .navigationDestination(isPresented: $showingAllPhotos) {
            PhotoHistoryView(food: food, isPushedView: true)
        }
        .navigationDestination(item: $selectedEntry) { selection in
            LoggedEntryDetailView(
                entry: selection.entry,
                showsLibraryLink: false,
                startsEditing: selection.startsEditing
            )
        }
        .sheet(item: $foodToLog) { food in
            LogFoodSheet(food: food)
        }
        .sheet(item: $draftToResume) { draft in
            if draft.isAvailable {
                LogFoodSheet(food: food, draft: draft)
            }
        }
        .sheet(item: $foodToMerge, onDismiss: performPendingMerge) { food in
            MergeFoodPickerView(food: food) { plan in
                pendingMerge = plan
            }
        }
        .sheet(item: $foodToEdit) { food in
            if food.type == .recipe {
                EditRecipeView(recipe: food)
            } else {
                EditEntryView(foodItem: food)
            }
        }
        .sheet(item: $foodToDuplicate) { food in
            DuplicateFoodSheet(food: food)
        }
        .sheet(item: $entryToLogAgain) { entry in
            LogAgainSheet(entry: entry)
        }
        .hydrationDaySheet(item: $hydrationDay, dayStartMinutes: dayStartMinutes)
        .deleteFoodAlert(
            food: $foodToDelete,
            onWillDelete: { dismissOnce() }
        )
    }

    private var content: some View {
        ScrollView {
            VStack {
                VStack(spacing: 24) {
                    if !isHeaderPinned {
                        headerCard
                    }

                    actionStrip
                }
                .padding(.horizontal)
                .padding(.bottom, 6)

                detailsCard
                    .padding([.horizontal])

                if isDrink {
                    sizesSection
                    draftsSection
                    historySection
                    notesSection
                    photosSection
                    placesSection
                    usedInSection
                } else {
                    notesSection
                    photosSection
                    placesSection
                    ingredientsSection
                    usedInSection
                    draftsSection
                    historySection
                }
            }
            .animation(.easeInOut(duration: 0.25), value: drafts.isEmpty)
            .animation(.easeInOut(duration: 0.25), value: logs.isEmpty)
        }
        .tabBarScrollInsets()
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            photoFramingWidth = max(0, width - 32)
        }
        .safeAreaBar(edge: .top) {
            if isHeaderPinned {
                headerCard
                    .padding(.horizontal)
                    .padding(.bottom, 24)
            }
        }
    }

    private var detailsCard: some View {
        Card("Details") {
            RowGroup(.divider) {
                if let source = food.source?.source {
                    detailRow("Source", value: source)
                }

                if let defaultLocation = food.defaultLocation {
                    detailRow("Default Location", value: defaultLocation.name)
                }

                if let category = food.category?.category {
                    detailRow("Category", value: category)
                }

                if isDrink {
                    if let caffeineText {
                        detailRow("Caffeine", value: caffeineText)
                    }
                    if let abv = food.abv {
                        detailRow(
                            "Alcohol",
                            value: String(localized: "\(EntryHelper.format(abv))% ABV")
                        )
                    }
                    if tracksHydration, food.hydrationPercent != 100 {
                        detailRow(
                            "Water Goal",
                            value: food.hydrationPercent <= 0
                                ? String(localized: "Not counted")
                                : String(localized: "Counts as \(EntryHelper.format(food.hydrationPercent))%")
                        )
                    }
                } else {
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
    }

    @ViewBuilder
    private var sizesSection: some View {
        let sizes = sizeItems
        if !sizes.isEmpty {
            Card(sizes.count == 1 ? String(localized: "Serving") : String(localized: "Serving & Sizes")) {
                RowGroup(.divider) {
                    ForEach(sizes) { size in
                        BaseRowLayout(
                            title: size.name ?? volumeUnit.formattedAmount(size.volumeML),
                            titleTag: size.isServing && sizes.count > 1 ? String(localized: "Serving") : nil,
                            subtitle: sizeFacts(size.volumeML)
                        ) {
                            if size.name != nil {
                                Text(volumeUnit.formattedAmount(size.volumeML))
                                    .font(.rowValue)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding([.top, .horizontal])
        }
    }

    @ViewBuilder
    private var notesSection: some View {
        if noteCount > 0 {
            Card("Notes") {
                RowGroup(.divider) {
                    if let pinnedNote {
                        WrappedInputRow(
                            placeholder: "",
                            text: .constant(pinnedNote.text),
                            caption: String(
                                localized:
                                    "Updated \(pinnedNote.lastUpdated.formatted(.relative(presentation: .named)))"
                            ),
                            captionSymbol: "pin.fill",
                            captionTint: .orange,
                            isEditable: false
                        )
                    }

                    if noteCount > (pinnedNote == nil ? 0 : 1) {
                        Button {
                            showingAllNotes = true
                        } label: {
                            BaseRowLayout(title: "All Notes") {
                                HStack(spacing: 8) {
                                    Text(noteCount.formatted())
                                        .font(.rowValue)
                                        .foregroundStyle(.secondary)

                                    Image(systemName: "chevron.right")
                                        .font(.chevron)
                                        .foregroundStyle(Color.tertiaryText)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding([.top, .horizontal])
        }
    }

    private var photosSection: some View {
        FoodPhotosCard(
            logs: logs,
            framingWidth: photoFramingWidth,
            onViewLog: { selectedEntry = LogSelection(entry: $0) },
            onShowAll: { showingAllPhotos = true }
        )
    }

    private var placesSection: some View {
        FoodPlacesCard(
            food: food,
            logs: logs,
            servingUnits: portionUnitOptions,
            onSelect: { placeToShow = $0 },
            onSetDefault: {
                setDefaultLocation(
                    $0,
                    for: food,
                    in: modelContext,
                    toastCenter: toastCenter
                )
            },
            onShowAll: { showingAllPlaces = true },
            onShowMap: { showingMap = true }
        )
    }

    @ViewBuilder
    private var ingredientsSection: some View {
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
    }

    @ViewBuilder
    private var usedInSection: some View {
        if !usedInRecipes.isEmpty {
            usedInCard
                .padding([.top, .horizontal])
        }
    }

    @ViewBuilder
    private var draftsSection: some View {
        if !drafts.isEmpty {
            draftsCard
                .padding([.top, .horizontal])
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var historySection: some View {
        if !logs.isEmpty {
            historyCard
                .padding([.top, .horizontal])
                .transition(.opacity)
        }
    }

    private var headerCard: some View {
        Card {
            MealRow(
                food: food,
                servingUnits: portionUnitOptions,
                icon: food.type.appSymbol
            )
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { height in
            headerHeight = height
        }
    }

    private var actionStrip: some View {
        return GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    foodToLog = food
                } label: {
                    Label("Log \(typeName)", systemImage: "plus")
                        .font(.prominentButton)
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                }
                .buttonStyle(.glassProminent)
            }
        }
    }

    private var usedInCard: some View {
        let recipes = usedInRecipes

        return Card("Used In") {
            RowGroup(.divider) {
                ForEach(recipes.prefix(usedInLimit)) { usedIn in
                    UsedInRecipeRow(usedIn: usedIn, servingUnits: portionUnitOptions) {
                        foodToShow = usedIn.recipe
                    }
                }
            } bottomContent: {
                if recipes.count > usedInLimit {
                    Divider()
                        .padding(.horizontal, 16)

                    ButtonRow(
                        icon: .appSymbol(.recipe),
                        title: String(localized: "See All Recipes (\(recipes.count))")
                    ) {
                        showingAllRecipes = true
                    }
                }
            }
        }
    }

    private var draftsCard: some View {
        Card("Drafts", titleBottomPadding: -4) {
            FoodDraftList(
                drafts: Array(drafts.prefix(recentDraftLimit)),
                servingUnits: portionUnitOptions,
                onResume: { draftToResume = $0 },
                onDelete: deleteDraft
            )

            if drafts.count > recentDraftLimit {
                Divider()
                    .padding(.horizontal, 16)

                ButtonRow(
                    icon: .customSymbol("tray.full"),
                    title: "See All Drafts (\(drafts.count))"
                ) {
                    showingAllDrafts = true
                }
            }
        }
    }

    private var historyCard: some View {
        let dailyAverage = isDrink ? dailyAverage : nil
        let usualMeal = usualMeal
        let usualPortion = usualPortion
        let hasStats = dailyAverage != nil || usualMeal != nil || usualPortion != nil

        return Card("History", titleBottomPadding: hasStats ? 0 : -4) {
            if hasStats {
                statStrip(dailyAverage: dailyAverage, usualMeal: usualMeal, usualPortion: usualPortion)

                Divider()
                    .padding(.horizontal, 16)
            }

            let historyItems = historyItems

            LogHistoryList(
                items: Array(historyItems.prefix(recentLogLimit)),
                servingUnits: portionUnitOptions,
                onSelect: { selectedEntry = LogSelection(entry: $0) },
                onEdit: {
                    selectedEntry = LogSelection(entry: $0, startsEditing: true)
                },
                onLogAgain: logAgain,
                onDelete: deleteEntry,
                onSelectHydrationDay: { hydrationDay = HydrationDayRequest(day: $0) }
            )

            if historyItems.count > recentLogLimit {
                Divider()
                    .padding(.horizontal, 16)

                ButtonRow(
                    icon: .customSymbol("clock.arrow.circlepath"),
                    title: "See All Logs (\(logs.count))"
                ) {
                    showingAllLogs = true
                }
            }
        }
    }

    private func statStrip(
        dailyAverage: String?,
        usualMeal: (value: String, label: String)?,
        usualPortion: String?
    ) -> some View {
        HStack(spacing: 0) {
            if let dailyAverage {
                statColumn(value: dailyAverage, label: "Per Day Logged")
            } else {
                statColumn(
                    value: logs.count.formatted(),
                    label: logs.count == 1 ? "Log" : "Logs"
                )
            }

            if let usualMeal {
                Divider().frame(height: 32)

                statColumn(value: usualMeal.value, label: usualMeal.label)
            }

            if let usualPortion {
                Divider().frame(height: 32)

                statColumn(value: usualPortion, label: isDrink ? "Usual Amount" : "Usual Portion")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
    }

    private func statColumn(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.statValue)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.detail)
                .foregroundStyle(Color.tertiaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }

    private var usualMeal: (value: String, label: String)? {
        let categories = logs.compactMap { entry -> String? in
            guard let category = entry.category?.category, !category.isEmpty
            else { return nil }
            return category
        }
        if !isDrink, let category = mostCommon(categories) {
            return (category, "Usual Meal")
        }

        let calendar = Calendar.current
        let minutes = logs.map { entry in
            let parts = calendar.dateComponents([.hour, .minute], from: entry.timestamp)
            return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        }
        guard let time = UsualTimeWindow(minutes: minutes)?.formatted else { return nil }
        return (time, "Usual Time")
    }

    @ViewBuilder
    private func ingredientRow(_ ingredient: RecipeIngredient) -> some View {
        let calories = ingredient.calories
        let drinkAmount = ingredient.ingredientItem.flatMap { food in
            food.type == .drink
                ? DrinkRowInfo(
                    food: food,
                    amounts: DrinkAmounts(food: food, quantity: ingredient.quantity, unit: ingredient.unit),
                    hasMacros: calories > 0
                ).amountText(unit: volumeUnit) : nil
        }

        let row = BaseRowLayout(
            icon: ingredient.ingredientItem.flatMap { food in
                food.type == .drink
                    ? .customSymbol(food.drinkSymbol, tint: food.drinkTint.color) : nil
            }
                ?? .appSymbol(
                    ingredient.ingredientItem?.type.appSymbol ?? .ingredient,
                    tint: .secondary
                ),
            title: ingredient.name,
            subtitle: drinkAmount ?? portionText(ingredient.quantity, ingredient.unit)
        ) {
            HStack(spacing: 8) {
                Text("\(EntryHelper.formatMacro(calories)) kcal")
                    .font(.compactValue)
                    .foregroundStyle(.secondary)

                if ingredient.ingredientItem != nil {
                    Image(systemName: "chevron.right")
                        .font(.chevron)
                        .foregroundStyle(Color.tertiaryText)
                }
            }
        }

        if let item = ingredient.ingredientItem {
            Button {
                foodToShow = item
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
                .font(.rowValue)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private struct LogSelection: Hashable {
    let entry: LoggedEntry
    var startsEditing = false
}

private func mostCommon<Value: Hashable>(_ values: [Value]) -> Value? {
    guard values.count >= 3 else { return nil }
    var counts: [Value: Int] = [:]
    for value in values {
        counts[value, default: 0] += 1
    }
    let ranked = counts.sorted { $0.value > $1.value }
    guard let top = ranked.first, top.value * 2 >= values.count else { return nil }
    if let runnerUp = ranked.dropFirst().first, runnerUp.value == top.value {
        return nil
    }
    return top.key
}

struct UsualTimeWindow {
    private static let dayMinutes = 24 * 60
    private static let windowMinutes = 3 * 60

    let startMinute: Int
    let endMinute: Int

    init?(minutes: [Int]) {
        guard minutes.count >= 3,
            let best = Self.densestWindow(in: minutes),
            best.logs.count * 2 >= minutes.count
        else { return nil }

        var remaining = minutes
        for minute in best.logs {
            if let index = remaining.firstIndex(of: minute) {
                remaining.remove(at: index)
            }
        }
        if let rival = Self.densestWindow(in: remaining), rival.logs.count == best.logs.count {
            return nil
        }

        startMinute = best.start / 60 * 60
        endMinute = (best.start + best.span) / 60 * 60 + 60
    }

    var formatted: String {
        let base = Date(timeIntervalSinceReferenceDate: 0)
        let from = base.addingTimeInterval(Double(startMinute) * 60)
        let to = base.addingTimeInterval(Double(endMinute % Self.dayMinutes) * 60)
        guard endMinute >= Self.dayMinutes else {
            var style = Date.IntervalFormatStyle().hour()
            style.timeZone = .gmt
            return (from..<base.addingTimeInterval(Double(endMinute) * 60)).formatted(style)
        }
        var style = Date.FormatStyle().hour()
        style.timeZone = .gmt
        return "\(from.formatted(style)) – \(to.formatted(style))"
    }

    private static func densestWindow(in minutes: [Int]) -> (start: Int, span: Int, logs: [Int])? {
        var best: (start: Int, span: Int, logs: [Int])?
        for start in Set(minutes).sorted() {
            let inside = minutes.filter { (($0 - start + dayMinutes) % dayMinutes) < windowMinutes }
            let span = inside.map { ($0 - start + dayMinutes) % dayMinutes }.max() ?? 0
            if let current = best,
                inside.count < current.logs.count
                    || (inside.count == current.logs.count && span >= current.span)
            {
                continue
            }
            best = (start, span, inside)
        }
        return best
    }
}

struct PortionKey: Hashable {
    let quantity: Double
    let unit: String

    static func usual(in logs: [LoggedEntry]) -> PortionKey? {
        mostCommon(logs.map { entry in
            entry.typeRawValue == EntryType.drink.rawValue && entry.volumeML > 0
                ? PortionKey(quantity: entry.volumeML.rounded(), unit: VolumeUnit.milliliters.rawValue)
                : PortionKey(quantity: entry.loggedQuantity, unit: entry.loggedUnit)
        })
    }
}

private struct DrinkSizeItem: Identifiable {
    let id: UUID
    let name: String?
    let volumeML: Double
    let isServing: Bool
}

struct FoodPlace {
    var location: EntryLocation
    var logs: [LoggedEntry]

    static func places(in logs: [LoggedEntry]) -> [FoodPlace] {
        var places: [FoodPlace] = []
        for entry in logs {
            guard let location = entry.location?.withoutMapPin else { continue }
            if let index = places.firstIndex(where: {
                RecentLocationStore.isSamePlace($0.location, location)
            }) {
                places[index].logs.append(entry)
            } else {
                places.append(FoodPlace(location: location, logs: [entry]))
            }
        }
        return places.enumerated()
            .sorted { lhs, rhs in
                lhs.element.logs.count != rhs.element.logs.count
                    ? lhs.element.logs.count > rhs.element.logs.count
                    : lhs.offset < rhs.offset
            }
            .map(\.element)
    }
}

private struct FoodPlacesCard: View {
    let food: FoodItem
    let logs: [LoggedEntry]
    let servingUnits: [ServingSizeUnit]
    var onSelect: (EntryLocation) -> Void
    var onSetDefault: (EntryLocation?) -> Void
    var onShowAll: () -> Void
    var onShowMap: () -> Void

    private let placeLimit = 3

    var body: some View {
        let places = FoodPlace.places(in: logs)
        let usualPortion = PortionKey.usual(in: logs)
        let isMappable = places.contains { $0.location.coordinate != nil }

        if places.count >= 2 || isMappable {
            Card("Locations") {
                RowGroup(.divider) {
                    ForEach(places.prefix(placeLimit), id: \.location) { place in
                        FoodPlaceRow(
                            food: food,
                            place: place,
                            servingUnits: servingUnits,
                            usualPortion: usualPortion,
                            onSelect: onSelect,
                            onSetDefault: onSetDefault
                        )
                    }
                } bottomContent: {
                    if places.count > placeLimit {
                        Divider()
                            .padding(.horizontal, 16)

                        ButtonRow(
                            icon: .customSymbol("mappin.and.ellipse"),
                            title: String(localized: "See All Locations (\(places.count))")
                        ) {
                            onShowAll()
                        }
                    }
                }
            } headerAccessory: {
                if isMappable {
                    ShowOnMapButton(action: onShowMap)
                }
            }
            .padding([.top, .horizontal])
        }
    }
}

private struct FoodPhotosCard: View {
    let logs: [LoggedEntry]
    let framingWidth: CGFloat
    var onViewLog: (LoggedEntry) -> Void
    var onShowAll: () -> Void

    @State private var viewerPhoto: EntryPhoto? = nil
    @State private var viewerSelection: PersistentIdentifier? = nil

    @Namespace private var photoNamespace

    private let recentPhotoLimit = 10

    var body: some View {
        let items = PhotoLog.logs(from: logs).flatMap { log in
            log.photos.map { PhotoViewerItem(photo: $0, entry: log.entry) }
        }

        if !items.isEmpty {
            card(items)
                .padding([.top, .horizontal])
                .fullScreenCover(item: $viewerPhoto) { photo in
                    PhotoViewer(items: items, selection: $viewerSelection)
                        .navigationTransition(
                            .zoom(
                                sourceID: viewerSelection ?? photo.persistentModelID,
                                in: photoNamespace
                            )
                        )
                }
        }
    }

    private func card(_ items: [PhotoViewerItem]) -> some View {
        let recentPhotos = items.prefix(recentPhotoLimit)

        return Card("Photos") {
            RowGroup(.divider) {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 8) {
                        ForEach(Array(recentPhotos)) { item in
                            Button {
                                viewerSelection = item.id
                                viewerPhoto = item.photo
                            } label: {
                                EntryPhotoImage(
                                    photo: item.photo,
                                    framingWidth: framingWidth
                                )
                                .frame(width: 72, height: 72)
                                .clipShape(
                                    RoundedRectangle(
                                        cornerRadius: 12,
                                        style: .continuous
                                    )
                                )
                            }
                            .buttonStyle(.plain)
                            .contentShape(
                                .contextMenuPreview,
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                            .contextMenu {
                                Button {
                                    onViewLog(item.entry)
                                } label: {
                                    Label("View Log", systemImage: "list.bullet.rectangle")
                                }
                            }
                            .matchedTransitionSource(id: item.id, in: photoNamespace)
                            .accessibilityLabel(
                                "Photo from \(EntryHelper.logDateText(item.entry.timestamp))"
                            )
                        }
                    }
                }
                .contentMargins(.horizontal, 16, for: .scrollContent)
                .scrollIndicators(.hidden)
                .frame(height: 72)
                .padding(.vertical, 12)

                Button {
                    onShowAll()
                } label: {
                    BaseRowLayout(title: "All Photos") {
                        HStack(spacing: 8) {
                            Text(items.count.formatted())
                                .font(.rowValue)
                                .foregroundStyle(.secondary)

                            Image(systemName: "chevron.right")
                                .font(.chevron)
                                .foregroundStyle(Color.tertiaryText)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

func setDefaultLocation(
    _ location: EntryLocation?,
    for food: FoodItem,
    in context: ModelContext,
    toastCenter: ToastCenter?
) {
    do {
        try withAnimation(.snappy(duration: 0.3)) {
            try DefaultLocationResolver.set(location, for: food, in: context)
        }
    } catch {
        context.rollback()
        toastCenter?.show(
            .failure(
                location == nil
                    ? String(localized: "Couldn't Clear Default Location")
                    : String(localized: "Couldn't Set Default Location"),
                message: food.name
            )
        )
    }
}

struct FoodPlaceRow: View {
    let food: FoodItem
    let place: FoodPlace
    let servingUnits: [ServingSizeUnit]
    let usualPortion: PortionKey?
    var onSelect: (EntryLocation) -> Void
    var onSetDefault: (EntryLocation?) -> Void

    @Environment(\.volumeUnit) private var volumeUnit

    private var isDefault: Bool {
        guard let current = food.defaultLocation else { return false }
        return RecentLocationStore.isSamePlace(current, place.location)
    }

    private var subtitle: String {
        var parts: [String] = []
        if isDefault {
            parts.append(String(localized: "Default"))
        }
        if let portion {
            parts.append(String(localized: "Usually \(portion)"))
        }
        if let last = place.logs.first?.timestamp {
            parts.append(String(localized: "Last Logged \(EntryHelper.logDayText(last))"))
        }
        return parts.joined(separator: " · ")
    }

    private var portion: String? {
        guard place.logs.count >= 2,
            let usual = PortionKey.usual(in: place.logs),
            usual != usualPortion
        else { return nil }
        let text = EntryHelper.portionText(
            quantity: usual.quantity,
            unit: usual.unit,
            servingUnits: servingUnits,
            volumeUnit: volumeUnit
        )
        guard food.type == .drink, usual.unit == VolumeUnit.milliliters.rawValue,
            let name = HydrationLogger.sizeName(for: food, volumeML: usual.quantity),
            !name.isEmpty
        else { return text }
        return "\(name) · \(text)"
    }

    var body: some View {
        Button {
            onSelect(place.location)
        } label: {
            BaseRowLayout(
                icon: .customSymbol(isDefault ? "pin.fill" : "mappin"),
                title: place.location.name,
                subtitle: subtitle
            ) {
                HStack(spacing: 8) {
                    Text(place.logs.count.formatted())
                        .font(.rowValue)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .accessibilityLabel(
                            place.logs.count == 1
                                ? String(localized: "1 log")
                                : String(localized: "\(place.logs.count) logs")
                        )

                    Image(systemName: "chevron.right")
                        .font(.chevron)
                        .foregroundStyle(Color.tertiaryText)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onSelect(place.location)
            } label: {
                Label("View Logs", systemImage: "list.bullet.rectangle")
            }

            if !place.location.needsName {
                Divider()

                if isDefault {
                    Button {
                        onSetDefault(nil)
                    } label: {
                        Label("Stop Using Here by Default", systemImage: "pin.slash")
                    }
                } else {
                    Button {
                        onSetDefault(place.location)
                    } label: {
                        Label("Use Here by Default", systemImage: "pin")
                        if let current = food.defaultLocation {
                            Text("Replaces “\(current.name)”")
                        }
                    }
                }
            }
        }
    }
}

private struct FoodPlacesView: View {
    let food: FoodItem

    var body: some View {
        FoodPlacesContent(food: food)
    }
}

private struct FoodPlacesContent: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.toastCenter) private var toastCenter

    let food: FoodItem

    @Query private var logs: [LoggedEntry]
    @Query(sort: \ServingSizeUnit.displayOrder) private var portionUnitOptions:
        [ServingSizeUnit]

    @State private var placeToShow: EntryLocation? = nil
    @State private var showingMap = false

    init(food: FoodItem) {
        self.food = food
        _logs = Query(FoodItemStore.topLevelLogsDescriptor(for: food))
    }

    var body: some View {
        let usualPortion = PortionKey.usual(in: logs)

        ZStack {
            Color.background.ignoresSafeArea()

            ScrollView {
                Card {
                    RowGroup(.divider, isLazy: true) {
                        ForEach(FoodPlace.places(in: logs), id: \.location) { place in
                            FoodPlaceRow(
                                food: food,
                                place: place,
                                servingUnits: portionUnitOptions,
                                usualPortion: usualPortion,
                                onSelect: { placeToShow = $0 },
                                onSetDefault: {
                                    setDefaultLocation(
                                        $0,
                                        for: food,
                                        in: modelContext,
                                        toastCenter: toastCenter
                                    )
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal)
            }
            .tabBarScrollInsets()
        }
        .withGlobalSwipeDismissal()
        .navigationTitle("All Locations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if logs.contains(where: { $0.location?.coordinate != nil }) {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Show on Map", systemImage: "map") {
                        showingMap = true
                    }
                }
            }
        }
        .navigationDestination(item: $placeToShow) { place in
            FoodLogsView(food: food, place: place)
        }
        .navigationDestination(isPresented: $showingMap) {
            FoodLocationsMapView(food: food)
        }
    }
}

private struct UsedInRecipe: Identifiable {
    let recipe: FoodItem
    var uses: [RecipeIngredient]

    var id: UUID { recipe.id }

    static func recipes(from uses: [RecipeIngredient]) -> [UsedInRecipe] {
        var result: [UsedInRecipe] = []
        for use in uses {
            guard let recipe = use.parentRecipe else { continue }
            if let index = result.firstIndex(where: { $0.id == recipe.id }) {
                result[index].uses.append(use)
            } else {
                result.append(UsedInRecipe(recipe: recipe, uses: [use]))
            }
        }
        return result
    }
}

private struct UsedInRecipeRow: View {
    let usedIn: UsedInRecipe
    let servingUnits: [ServingSizeUnit]
    var onSelect: () -> Void

    @Environment(\.volumeUnit) private var volumeUnit

    private var portion: String {
        usedIn.uses
            .sorted { $0.displayOrder < $1.displayOrder }
            .map {
                EntryHelper.portionText(
                    quantity: $0.quantity,
                    unit: $0.unit,
                    servingUnits: servingUnits,
                    volumeUnit: volumeUnit
                )
            }
            .joined(separator: " + ")
    }

    private var calories: Double {
        usedIn.uses.reduce(0) { $0 + $1.calories }
    }

    var body: some View {
        Button {
            onSelect()
        } label: {
            BaseRowLayout(
                icon: .appSymbol(.recipe),
                title: usedIn.recipe.name,
                subtitle: portion
            ) {
                HStack(spacing: 8) {
                    Text("\(EntryHelper.formatMacro(calories)) kcal")
                        .font(.compactValue)
                        .foregroundStyle(.secondary)

                    Image(systemName: "chevron.right")
                        .font(.chevron)
                        .foregroundStyle(Color.tertiaryText)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct FoodRecipesView: View {
    let food: FoodItem

    var body: some View {
        FoodRecipesContent(food: food)
    }
}

private struct FoodRecipesContent: View {
    @Query private var recipeUses: [RecipeIngredient]
    @Query(sort: \ServingSizeUnit.displayOrder) private var portionUnitOptions:
        [ServingSizeUnit]

    @State private var foodToShow: FoodItem? = nil

    init(food: FoodItem) {
        let foodID = food.id
        _recipeUses = Query(
            filter: #Predicate<RecipeIngredient> {
                $0.ingredientItem?.id == foodID
            }
        )
    }

    private var recipes: [UsedInRecipe] {
        UsedInRecipe.recipes(from: recipeUses).sorted {
            $0.recipe.name.localizedStandardCompare($1.recipe.name) == .orderedAscending
        }
    }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            ScrollView {
                Card {
                    RowGroup(.divider, isLazy: true) {
                        ForEach(recipes) { usedIn in
                            UsedInRecipeRow(
                                usedIn: usedIn,
                                servingUnits: portionUnitOptions
                            ) {
                                foodToShow = usedIn.recipe
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .tabBarScrollInsets()
        }
        .withGlobalSwipeDismissal()
        .navigationTitle("Used In")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $foodToShow) { food in
            FoodDetailView(food: food)
        }
    }
}

struct FoodLogsView: View {
    let food: FoodItem
    var place: EntryLocation? = nil
    var showsMapButton = true

    var body: some View {
        FoodLogsContent(food: food, place: place, showsMapButton: showsMapButton)
    }
}

private struct FoodLogsContent: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.tracksHydration) private var tracksHydration
    @Environment(\.toastCenter) private var toastCenter

    @Query private var logs: [LoggedEntry]
    @Query(sort: \ServingSizeUnit.displayOrder) private var portionUnitOptions:
        [ServingSizeUnit]

    @State private var selectedEntry: LogSelection? = nil
    @State private var entryToLogAgain: LoggedEntry? = nil
    @State private var isVisible = false
    @State private var isDismissing = false
    @State private var showingMap = false
    @State private var hydrationDay: HydrationDayRequest? = nil

    @Query private var users: [User]

    @Environment(\.dismiss) private var dismiss

    private let food: FoodItem
    private let place: EntryLocation?
    private let showsMapButton: Bool

    init(food: FoodItem, place: EntryLocation? = nil, showsMapButton: Bool = true) {
        self.food = food
        self.place = place
        self.showsMapButton = showsMapButton
        _logs = Query(FoodItemStore.topLevelLogsDescriptor(for: food))
    }

    private var shownLogs: [LoggedEntry] {
        guard let place else { return logs }
        return logs.filter { entry in
            guard let location = entry.location?.withoutMapPin else { return false }
            return RecentLocationStore.isSamePlace(place, location)
        }
    }

    private var dayStartMinutes: Int {
        users.first?.dayStartMinutes ?? 0
    }

    private func logAgain(_ entry: LoggedEntry) {
        guard EntryActions.opensAsHydrationLog(entry, tracksHydration: tracksHydration) else {
            entryToLogAgain = entry
            return
        }
        EntryActions.logHydrationAgain(
            entry,
            dayStartMinutes: dayStartMinutes,
            unit: users.first?.volumeUnit ?? .localeDefault,
            in: modelContext,
            toastCenter: toastCenter
        )
    }

    private struct LogMonth: Identifiable {
        let id: Date
        var items: [LogHistoryItem]
    }

    private var months: [LogMonth] {
        let calendar = Calendar.current
        var result: [LogMonth] = []
        for item in LogHistoryItem.items(from: shownLogs, dayStartMinutes: dayStartMinutes, groupsHydrationLogs: tracksHydration) {
            let month =
                calendar.dateInterval(of: .month, for: item.date)?.start
                ?? item.date
            if result.last?.id == month {
                result[result.count - 1].items.append(item)
            } else {
                result.append(LogMonth(id: month, items: [item]))
            }
        }
        return result
    }

    private func deleteEntry(_ entry: LoggedEntry) {
        DispatchQueue.main.async {
            EntryActions.delete(entry, in: modelContext, toastCenter: toastCenter)
        }
    }

    private func dismissIfEmpty() {
        guard place != nil, isVisible, !isDismissing, shownLogs.isEmpty else { return }
        isDismissing = true
        dismiss()
    }

    var body: some View {
        let months = months

        ZStack {
            Color.background.ignoresSafeArea()

            ScrollView {
                LazyVStack {
                    ForEach(months) { month in
                        Card(
                            month.id.formatted(.dateTime.month(.wide).year()),
                            titleBottomPadding: -4
                        ) {
                            LogHistoryList(
                                items: month.items,
                                servingUnits: portionUnitOptions,
                                onSelect: { selectedEntry = LogSelection(entry: $0) },
                                onEdit: {
                                    selectedEntry = LogSelection(
                                        entry: $0,
                                        startsEditing: true
                                    )
                                },
                                onLogAgain: logAgain,
                                onDelete: deleteEntry,
                                onSelectHydrationDay: { hydrationDay = HydrationDayRequest(day: $0) }
                            )
                        }
                        .padding(.horizontal)
                        .padding(.top, month.id == months.first?.id ? 0 : nil)
                        .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: months.map(\.id))
            }
            .tabBarScrollInsets()
        }
        .withGlobalSwipeDismissal()
        .hydrationDaySheet(item: $hydrationDay, dayStartMinutes: dayStartMinutes)
        .navigationTitle(place?.name ?? String(localized: "All Logs"))
        .navigationSubtitle(place == nil ? "" : food.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsMapButton, let place, place.coordinate != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Show on Map", systemImage: "map") {
                        showingMap = true
                    }
                }
            }
        }
        .navigationDestination(isPresented: $showingMap) {
            FoodLocationsMapView(food: food, initialPlace: place)
        }
        .onAppear {
            isVisible = true
            dismissIfEmpty()
        }
        .onDisappear { isVisible = false }
        .onChange(of: months.isEmpty) {
            dismissIfEmpty()
        }
        .navigationDestination(item: $selectedEntry) { selection in
            LoggedEntryDetailView(
                entry: selection.entry,
                showsLibraryLink: false,
                showsMapLink: showsMapButton,
                startsEditing: selection.startsEditing
            )
        }
        .sheet(item: $entryToLogAgain) { entry in
            LogAgainSheet(entry: entry)
        }
    }
}

private struct FoodDraftsView: View {
    let food: FoodItem

    var body: some View {
        FoodDraftsContent(food: food)
    }
}

private struct FoodDraftsContent: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.toastCenter) private var toastCenter
    @Environment(\.dismiss) private var dismiss

    let food: FoodItem

    @Query private var drafts: [EntryDraft]
    @Query(sort: \ServingSizeUnit.displayOrder) private var portionUnitOptions:
        [ServingSizeUnit]

    @State private var draftToResume: EntryDraft? = nil
    @State private var isVisible = false
    @State private var isDismissing = false

    init(food: FoodItem) {
        self.food = food

        let foodID = food.id
        let logFood = DraftKind.logFood.rawValue
        let logRecipe = DraftKind.logRecipe.rawValue
        _drafts = Query(
            filter: #Predicate<EntryDraft> {
                $0.foodItem?.id == foodID
                    && ($0.kindRawValue == logFood
                        || $0.kindRawValue == logRecipe)
            },
            sort: \EntryDraft.updatedAt,
            order: .reverse
        )
    }

    private func deleteDraft(_ draft: EntryDraft) {
        DispatchQueue.main.async {
            EntryActions.delete(draft, in: modelContext, toastCenter: toastCenter)
        }
    }

    private func dismissIfEmpty() {
        guard isVisible, !isDismissing, drafts.isEmpty else { return }
        isDismissing = true
        dismiss()
    }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            ScrollView {
                Card {
                    FoodDraftList(
                        drafts: drafts,
                        servingUnits: portionUnitOptions,
                        onResume: { draftToResume = $0 },
                        onDelete: deleteDraft
                    )
                }
                .padding(.horizontal)
            }
            .tabBarScrollInsets()
        }
        .withGlobalSwipeDismissal()
        .navigationTitle("All Drafts")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isVisible = true
            dismissIfEmpty()
        }
        .onDisappear { isVisible = false }
        .onChange(of: drafts.isEmpty) {
            dismissIfEmpty()
        }
        .sheet(item: $draftToResume) { draft in
            if draft.isAvailable {
                LogFoodSheet(food: food, draft: draft)
            }
        }
    }
}

private struct FoodDraftList: View {
    let drafts: [EntryDraft]
    let servingUnits: [ServingSizeUnit]
    var onResume: (EntryDraft) -> Void
    var onDelete: (EntryDraft) -> Void

    var body: some View {
        EntryList(
            items: drafts,
            allowSwipeActions: true,
            showCard: false,
            isLazy: false,
            rowContent: { draft in
                DraftRow(
                    draft: draft,
                    servingUnits: servingUnits,
                    showsFoodName: false
                ) {
                    onResume(draft)
                }
                .contextMenu {
                    Button {
                        onResume(draft)
                    } label: {
                        Label("Resume Draft", systemImage: "square.and.pencil")
                    }

                    Divider()

                    Button(role: .destructive) {
                        onDelete(draft)
                    } label: {
                        Label("Delete Draft", systemImage: "trash")
                    }
                }
            },
            onDelete: onDelete
        )
    }
}

private enum LogHistoryItem: Identifiable, Equatable {
    case log(LoggedEntry)
    case hydrationDay(Date, HydrationDaySummary)

    var id: String {
        switch self {
        case .log(let entry): entry.id.uuidString
        case .hydrationDay(let day, _): "hydration-\(day.timeIntervalSinceReferenceDate)"
        }
    }

    var date: Date {
        switch self {
        case .log(let entry): entry.timestamp
        case .hydrationDay(let day, _): day
        }
    }

    static func items(
        from logs: [LoggedEntry],
        dayStartMinutes: Int,
        groupsHydrationLogs: Bool = true
    ) -> [LogHistoryItem] {
        let calendar = Calendar.current
        var items: [LogHistoryItem] = []
        var dayLogs: [Date: [LoggedEntry]] = [:]
        for entry in logs {
            guard groupsHydrationLogs, entry.isHydrationLog else {
                items.append(.log(entry))
                continue
            }
            let day = calendar.logicalDay(for: entry.timestamp, dayStartMinutes: dayStartMinutes)
            if dayLogs[day] == nil {
                items.append(.hydrationDay(day, HydrationDaySummary(logs: [])))
            }
            dayLogs[day, default: []].append(entry)
        }
        return items.map { item in
            guard case .hydrationDay(let day, _) = item else { return item }
            return .hydrationDay(day, HydrationDaySummary(logs: dayLogs[day] ?? []))
        }
    }
}

private struct LogHistoryList: View {
    @Environment(\.tracksHydration) private var tracksHydration

    let items: [LogHistoryItem]
    let servingUnits: [ServingSizeUnit]
    var onSelect: (LoggedEntry) -> Void
    var onEdit: (LoggedEntry) -> Void
    var onLogAgain: (LoggedEntry) -> Void
    var onDelete: (LoggedEntry) -> Void
    var onSelectHydrationDay: (Date) -> Void

    @State private var focusManager = SwipeFocusManager()

    var body: some View {
        RowGroup(.divider, isLazy: false) {
            ForEach(items) { item in
                switch item {
                case .log(let entry):
                    CustomSwipeRow(
                        content: { logRow(entry) },
                        onDelete: { onDelete(entry) }
                    )
                    .transition(
                        .asymmetric(
                            insertion: .identity,
                            removal: .opacity.combined(with: .scale(scale: 0.9))
                        )
                    )
                case .hydrationDay(let day, let summary):
                    HydrationDayHistoryRow(day: day, summary: summary) {
                        onSelectHydrationDay(day)
                    }
                }
            }
        }
        .environment(focusManager)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: items)
    }

    private func logRow(_ entry: LoggedEntry) -> some View {
        LogHistoryRow(entry: entry, servingUnits: servingUnits) {
            onSelect(entry)
        }
        .contextMenu {
            if EntryActions.canLogAgain(entry, tracksHydration: tracksHydration) {
                Button {
                    onLogAgain(entry)
                } label: {
                    Label("Log Again", systemImage: "plus.square.on.square")
                }
            }

            Button {
                onEdit(entry)
            } label: {
                Label("Edit Entry", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive) {
                onDelete(entry)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

private struct LogAgainSheet: View {
    let entry: LoggedEntry

    var body: some View {
        Group {
            if let food = entry.originalFoodItem {
                if food.type == .recipe {
                    LogRecipeView(
                        recipe: food,
                        previousEntry: entry
                    )
                } else {
                    LogEntryView(
                        food: food,
                        previousEntry: entry
                    )
                }
            }
        }
        .environment(\.rootDismiss, nil)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: FoodItem.self,
        LoggedEntry.self,
        FavoriteEntry.self,
        ServingSizeUnit.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
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

#Preview("Drink") {
    let container = try! ModelContainer(
        for: User.self, FoodItem.self, LoggedEntry.self, ServingSizeUnit.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    )
    let context = container.mainContext
    context.insert(User(onboardingComplete: true))
    AppSeeder.resetListSeeding()
    try? AppSeeder.seedDefaults(into: context)
    let foods = (try? context.fetch(FetchDescriptor<FoodItem>())) ?? []
    let coffee = foods.first { $0.seedKey == "coffee" }!

    for dayOffset in 0..<6 {
        let day = Date().addingTimeInterval(Double(-dayOffset) * 86400)
        _ = try? HydrationLogger.log(coffee, volumeML: 240, sizeName: "Cup", at: day, in: context)
        if dayOffset.isMultiple(of: 2) {
            _ = try? HydrationLogger.log(coffee, volumeML: 350, sizeName: "Mug", at: day, in: context)
        }
    }

    return NavigationStack {
        FoodDetailView(food: coffee)
    }
    .modelContainer(container)
}
