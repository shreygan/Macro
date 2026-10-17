//
//  MergeFoodsView.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/15/26.
//

import SwiftData
import SwiftUI

struct MergeFoodsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \EntrySource.displayOrder) private var savedSources: [EntrySource]
    @Query(sort: \CategorySource.displayOrder) private var savedCategories: [CategorySource]
    @Query(sort: \FoodGroupSource.displayOrder) private var savedFoodGroups: [FoodGroupSource]

    let foods: [FoodItem]
    let servingUnits: [ServingSizeUnit]
    var onConfirm: (FoodMergePlan) -> Void

    @State private var keptID: UUID
    @State private var name: String
    @State private var source: String
    @State private var category: String
    @State private var foodGroup: String
    @State private var defaultLocation: EntryLocation?
    @State private var stickyNote: String
    @State private var editedDefaultPortion: String?
    @State private var servingQuantity = "1"
    @State private var servingUnit: String
    @State private var conversions: [UUID: String] = [:]
    @State private var hints: [UUID: String] = [:]
    @State private var recalculateLogs = false
    @State private var showsRecalculate = false
    @State private var selectedLog: LoggedEntry?
    @State private var pendingUnit: String?

    @State private var showingAllLogs = false
    @State private var sortedLogs: [MergeLog] = []
    @State private var recipeCount = 0
    @State private var draftCount = 0

    init(
        foods: [FoodItem],
        kept: FoodItem,
        servingUnits: [ServingSizeUnit],
        onConfirm: @escaping (FoodMergePlan) -> Void
    ) {
        self.foods = foods
        self.servingUnits = servingUnits
        self.onConfirm = onConfirm

        let unit =
            Self.portionInName(kept.name, units: servingUnits)?.unit
            ?? kept.servingUnit?.unit ?? "serving"
        _keptID = State(initialValue: kept.id)
        _name = State(initialValue: kept.name)
        _source = State(initialValue: kept.source?.source ?? "")
        _category = State(initialValue: kept.category?.category ?? "")
        _foodGroup = State(initialValue: kept.foodGroup?.foodGroup ?? "")
        _defaultLocation = State(initialValue: kept.defaultLocation)
        _stickyNote = State(initialValue: kept.stickyNote?.text ?? "")
        _servingUnit = State(initialValue: unit)

        let (conversions, hints) = Self.guessConversions(
            foods: foods,
            kept: kept,
            unit: unit,
            units: servingUnits
        )
        _conversions = State(initialValue: conversions)
        _hints = State(initialValue: hints)
    }

    private var kept: FoodItem? {
        foods.first { $0.id == keptID }
    }

    private var removedFoods: [FoodItem] {
        foods.filter { $0.id != keptID }
    }

    private var foodsNeedingConversion: [FoodItem] {
        foods.filter { $0.servingUnit?.unit != servingUnit }
    }

    private var movesFavorite: Bool {
        removedFoods.contains { $0.favoriteEntry != nil }
    }

    private var favoriteSubtitle: String? {
        let count = foods.filter { $0.favoriteEntry != nil }.count
        return count > 1 ? String(localized: "Combines \(count) favorites into 1") : nil
    }

    private var plan: FoodMergePlan? {
        guard let kept else { return nil }
        var unitsPerServing: [UUID: Double] = [:]
        for food in foods {
            if food.servingUnit?.unit == servingUnit {
                unitsPerServing[food.id] = food.servingSize
            } else if let value = Double(conversions[food.id] ?? ""), value > 0 {
                unitsPerServing[food.id] = value
            }
        }
        return FoodMergePlan(
            kept: kept,
            foods: foods,
            name: name,
            source: source,
            category: category,
            foodGroup: foodGroup,
            defaultLocation: defaultLocation,
            stickyNote: stickyNote,
            servingSize: Double(servingQuantity) ?? 0,
            servingUnit: servingUnit,
            defaultPortionOverride: editedDefaultPortion.map { Double($0) ?? 0 },
            unitsPerServing: unitsPerServing,
            recalculateLogs: recalculateLogs
        )
    }

    private let recentLogLimit = 5

    private var logCount: Int {
        sortedLogs.count
    }

    private var recentLogs: [MergeLog] {
        Array(sortedLogs.prefix(recentLogLimit))
    }

    private var recalculableLogCount: Int {
        guard let plan else { return 0 }
        return sortedLogs.filter { item in
            guard let macros = plan.recalculatedMacros(for: item.log, of: item.food) else { return false }
            return abs(macros.calories - item.log.calories) >= 1
        }
        .count
    }

    private var recalculateTarget: Bool? {
        guard let plan, plan.servingMacros != nil, plan.servingSize > 0 else { return nil }
        return recalculableLogCount > 0
    }

    private var pluralUnit: String {
        servingUnits.first { $0.unit == servingUnit }?.displayString(for: "2") ?? servingUnit
    }

    private static let abbreviatedUnits: Set<String> = [
        "g", "kg", "mg", "oz", "lb", "lbs", "ml", "l", "tsp", "tbsp",
    ]

    private var conversionUnitTitle: String {
        Self.abbreviatedUnits.contains(servingUnit.lowercased())
            ? pluralUnit : pluralUnit.localizedCapitalized
    }

    private var portionsConvertedSubtitle: String? {
        foods.contains { $0.servingUnit?.unit != servingUnit }
            ? String(localized: "Portions converted to \(pluralUnit)")
            : nil
    }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            ScrollView {
                VStack {
                    keepCard
                        .padding([.horizontal, .bottom])

                    mergedFoodCard
                        .padding([.horizontal, .bottom])

                    if !foodsNeedingConversion.isEmpty {
                        conversionsCard
                            .padding([.horizontal, .bottom])
                    }

                    if logCount > 0 {
                        logsCard
                            .padding([.horizontal, .bottom])
                    }

                    if movesFavorite || recipeCount > 0 || draftCount > 0 {
                        alsoMovesCard
                            .padding([.horizontal, .bottom])
                    }
                }
                .animation(.snappy(duration: 0.3), value: servingUnit)
                .animation(.snappy(duration: 0.3), value: showsRecalculate)
            }
            .withCustomKeyboardToolbar()
        }
        .onAppear(perform: loadUsage)
        .navigationDestination(item: $selectedLog) { log in
            LoggedEntryDetailView(entry: log, isReadOnly: true, showsLibraryLink: false)
        }
        .navigationDestination(isPresented: $showingAllLogs) {
            if let plan {
                MergeLogsView(
                    logs: sortedLogs,
                    plan: plan,
                    recalculateLogs: recalculateLogs,
                    servingUnits: servingUnits
                )
            }
        }
        .onChange(of: servingUnit) {
            refreshGuesses()
            editedDefaultPortion = nil
        }
        .onChange(of: recalculateTarget, initial: true) { _, target in
            guard let target else { return }
            showsRecalculate = target
            if !target {
                recalculateLogs = false
            }
        }
        .navigationTitle("Merge \(foods.count) Foods")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    merge()
                } label: {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.primary)
                }
                .tint(Color.accentColor)
                .buttonStyle(.glassProminent)
                .disabled(!(plan?.isValid ?? false))
            }
        }
    }

    private var keepCard: some View {
        Card("Keep Details From") {
            RowGroup(.divider) {
                ForEach(foods) { food in
                    Button {
                        switchKept(to: food)
                    } label: {
                        HStack(spacing: 0) {
                            keepRow(food)

                            if food.id == keptID {
                                Image(systemName: "checkmark")
                                    .font(.menuIcon)
                                    .foregroundStyle(Color.accentColor)
                                    .padding(.trailing, 16)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(food.id == keptID ? .isSelected : [])
                }
            }
        }
    }

    private func keepRow(_ food: FoodItem) -> some View {
        let own = FoodMergePlan.Macros(
            calories: food.calories,
            protein: food.protein,
            carbs: food.carbs,
            fat: food.fat,
            fiber: food.fiber
        )
        let servingSize = Double(servingQuantity) ?? 0
        let units =
            food.servingUnit?.unit == servingUnit
            ? food.servingSize : Double(conversions[food.id] ?? "") ?? 0

        let portion: String
        let macros: FoodMergePlan.Macros
        if units > 0, servingSize > 0 {
            portion = EntryHelper.portionText(
                quantity: servingSize,
                unit: servingUnit,
                servingUnits: servingUnits
            )
            macros = own.scaled(by: servingSize / units)
        } else {
            portion = EntryHelper.portionText(
                quantity: food.servingSize,
                unit: food.servingUnit?.unit ?? "serving",
                servingUnits: servingUnits
            )
            macros = own
        }

        return VStack(alignment: .leading, spacing: 2) {
            Text(food.name)
                .font(.compactTitle)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text("\(Text(portion).font(.subtitle).foregroundStyle(Color.tertiaryText))  \(macrosText(macros))")
                .lineLimit(1)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var servingWeightText: String? {
        guard let kept, let weight = kept.servingWeight, weight > 0 else { return nil }
        guard plan?.servingMacros != nil else { return String(localized: "Needs conversion") }
        guard let plan, plan.servingSize > 0, let merged = plan.servingWeight else { return "-" }
        return "\(EntryHelper.format(merged)) \(kept.servingWeightUnit)"
    }

    private var keptDefaultPortionText: String? {
        plan?.keptDefaultPortion.map(EntryHelper.format)
    }

    private var defaultPortionBinding: Binding<String> {
        Binding(
            get: { editedDefaultPortion ?? keptDefaultPortionText ?? "" },
            set: { editedDefaultPortion = $0 == keptDefaultPortionText ? nil : $0 }
        )
    }

    private func derivedValue(_ text: String?) -> some View {
        let isPlaceholder = text == nil || text == "-" || text == String(localized: "Needs conversion")
        return Text(text ?? String(localized: "None"))
            .font(.rowValue)
            .foregroundStyle(isPlaceholder ? Color.tertiaryText : .secondary)
            .lineLimit(1)
    }

    private var mergedFoodCard: some View {
        Card("Merged Food") {
            RowGroup(.divider) {
                TextInputRow(
                    title: "Name",
                    placeholder: "Name",
                    text: $name,
                    maxWidth: nil,
                    fitsRightContent: true
                )

                DropdownPillRow(
                    title: "Source",
                    options: [""] + savedSources.visibleNames(keeping: source),
                    selection: $source
                )

                DefaultLocationRow(
                    location: $defaultLocation,
                    sourceName: source,
                    foodIDs: [keptID] + removedFoods.map(\.id),
                    title: String(localized: "Default Location")
                )

                if kept?.type == .ingredient {
                    DropdownPillRow(
                        title: "Food Group",
                        options: [""] + savedFoodGroups.visibleNames(keeping: foodGroup),
                        selection: $foodGroup
                    )
                } else if kept?.type == .food {
                    DropdownPillRow(
                        title: "Category",
                        options: [""] + savedCategories.visibleNames(keeping: category),
                        selection: $category
                    )
                }

                PortionPillRow(
                    title: "Serving",
                    allowsCustomUnit: true,
                    pendingCustomUnit: $pendingUnit,
                    quantity: $servingQuantity,
                    unit: $servingUnit,
                    availableUnits: servingUnits.map(\.unit),
                    servingUnits: servingUnits
                )

                BaseRowLayout(title: "Per Serving", fitsRightContent: true) {
                    if let macros = plan?.servingMacros, (plan?.servingSize ?? 0) > 0 {
                        macrosText(macros)
                    } else if plan?.servingMacros == nil {
                        Text("Needs conversion")
                            .font(.rowValue)
                            .foregroundStyle(Color.tertiaryText)
                    } else {
                        Text("-")
                            .font(.rowValue)
                            .foregroundStyle(Color.tertiaryText)
                    }
                }

                BaseRowLayout(title: "Serving Weight") {
                    derivedValue(servingWeightText)
                }

                BaseRowLayout(title: "Default Portion") {
                    if editedDefaultPortion == nil && keptDefaultPortionText == nil {
                        derivedValue(String(localized: "Needs conversion"))
                    } else {
                        InputPill(
                            text: defaultPortionBinding,
                            unit: unitLabel(for: defaultPortionBinding.wrappedValue),
                            keyboardType: .decimalPad,
                            placeholder: servingQuantity
                        )
                    }
                }

                if kept?.isAIEstimated == true {
                    BaseRowLayout(title: "AI Estimated") {
                        derivedValue(String(localized: "Yes"))
                    }
                }

                WrappedInputRow(
                    placeholder: "Pinned Note",
                    text: $stickyNote,
                    isEditable: true,
                    characterLimit: 2000
                )
            }
        } headerAccessory: {
            Menu {
                Button("Reset Details", systemImage: "arrow.counterclockwise") {
                    resetDetails()
                }
                .disabled(!hasEditedDetails)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.menuIcon)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.controlFill))
            }
            .buttonStyle(.plain)
            .padding(.vertical, -2)
            .padding(.trailing, -6)
            .accessibilityLabel("Merged Food Options")
        }
    }

    private var hasEditedDetails: Bool {
        guard let kept else { return false }
        return name != kept.name
            || source != kept.source?.source ?? ""
            || category != kept.category?.category ?? ""
            || foodGroup != kept.foodGroup?.foodGroup ?? ""
            || defaultLocation != kept.defaultLocation
            || stickyNote != kept.stickyNote?.text ?? ""
            || editedDefaultPortion != nil
    }

    private func resetDetails() {
        guard let kept else { return }
        name = kept.name
        source = kept.source?.source ?? ""
        category = kept.category?.category ?? ""
        foodGroup = kept.foodGroup?.foodGroup ?? ""
        defaultLocation = kept.defaultLocation
        stickyNote = kept.stickyNote?.text ?? ""
        editedDefaultPortion = nil
    }

    private var conversionsCard: some View {
        Card("\(conversionUnitTitle) per Serving") {
            RowGroup(.divider) {
                ForEach(foodsNeedingConversion) { food in
                    BaseRowLayout(
                        title: food.name,
                        subtitle: conversionSubtitle(for: food)
                    ) {
                        InputPill(
                            text: conversionBinding(for: food),
                            unit: unitLabel(for: conversions[food.id] ?? ""),
                            keyboardType: .decimalPad
                        )
                    }
                }
            }
        }
    }

    private var logsCard: some View {
        Card("Logs (\(logCount))") {
            RowGroup(.divider) {
                if let plan {
                    ForEach(recentLogs) { item in
                        LogHistoryRow(
                            entry: item.log,
                            servingUnits: servingUnits,
                            override: item.override(plan: plan, recalculating: recalculateLogs)
                        ) {
                            selectedLog = item.log
                        }
                    }
                }

                if showsRecalculate {
                    ToggleRow(
                        title: "Recalculate from Serving",
                        subtitle: recalculateSubtitle,
                        isOn: $recalculateLogs.animation(.snappy(duration: 0.3))
                    )
                }
            }

            if logCount > recentLogLimit {
                Divider()
                    .padding(.horizontal, 16)

                ButtonRow(
                    icon: .customSymbol("clock.arrow.circlepath"),
                    title: "See All Logs (\(logCount))"
                ) {
                    showingAllLogs = true
                }
            }
        }
    }

    private var alsoMovesCard: some View {
        Card("Also Moves") {
            RowGroup(.divider) {
                if movesFavorite {
                    BaseRowLayout(
                        icon: .customSymbol("star.fill", tint: .yellow),
                        title: "Favorite",
                        subtitle: favoriteSubtitle
                    ) {
                        EmptyView()
                    }
                }

                if recipeCount > 0 {
                    BaseRowLayout(
                        icon: .appSymbol(EntryType.recipe.appSymbol, tint: .secondary),
                        title: "Used in Recipes",
                        subtitle: portionsConvertedSubtitle
                    ) {
                        Text("\(recipeCount)")
                    }
                }

                if draftCount > 0 {
                    BaseRowLayout(
                        icon: .customSymbol("square.and.pencil", tint: .secondary),
                        title: "Drafts",
                        subtitle: portionsConvertedSubtitle
                    ) {
                        Text("\(draftCount)")
                    }
                }
            }
        }
    }

    private var recalculateSubtitle: String {
        if recalculateLogs { return "Logs use the new serving's macros" }
        return recalculableLogCount == 1
            ? "1 log keeps its own macros"
            : "\(recalculableLogCount) logs keep their own macros"
    }

    private func switchKept(to food: FoodItem) {
        guard let kept, food.id != kept.id else { return }
        if name == kept.name { name = food.name }
        if source == kept.source?.source ?? "" { source = food.source?.source ?? "" }
        if category == kept.category?.category ?? "" { category = food.category?.category ?? "" }
        if foodGroup == kept.foodGroup?.foodGroup ?? "" { foodGroup = food.foodGroup?.foodGroup ?? "" }
        if defaultLocation == kept.defaultLocation { defaultLocation = food.defaultLocation }
        if stickyNote == kept.stickyNote?.text ?? "" { stickyNote = food.stickyNote?.text ?? "" }
        keptID = food.id
    }

    private func refreshGuesses() {
        guard let kept else { return }
        let (guesses, guessHints) = Self.guessConversions(
            foods: foods,
            kept: kept,
            unit: servingUnit,
            units: servingUnits
        )
        conversions = guesses
        hints = guessHints
    }

    private func loadUsage() {
        var logs: [MergeLog] = []
        var recipeIDs = Set<UUID>()
        var drafts = 0
        for food in foods {
            let foodLogs = (try? modelContext.fetch(FoodItemStore.topLevelLogsDescriptor(for: food))) ?? []
            logs += foodLogs.map { MergeLog(log: $0, food: food) }
            for ingredient in FoodItemStore.recipeIngredients(using: food, in: modelContext) {
                if let id = ingredient.parentRecipe?.id {
                    recipeIDs.insert(id)
                }
            }
            drafts += food.drafts?.count ?? 0
        }
        sortedLogs = logs.sorted { $0.log.timestamp > $1.log.timestamp }
        recipeCount = recipeIDs.count
        draftCount = drafts
    }

    private func merge() {
        if let pending = pendingUnit?.trimmingCharacters(in: .whitespacesAndNewlines) {
            UIApplication.shared.dismissKeyboard()
            if !pending.isEmpty && pending != servingUnit { return }
        }
        guard let plan, plan.isValid else { return }
        onConfirm(plan)
    }

    private func conversionSubtitle(for food: FoodItem) -> String {
        let serving = EntryHelper.portionText(
            quantity: food.servingSize,
            unit: food.servingUnit?.unit ?? "serving",
            servingUnits: servingUnits
        )
        if (Double(conversions[food.id] ?? "") ?? 0) <= 0 {
            return "\(serving) · \(String(localized: "Required"))"
        }
        guard let hint = hints[food.id] else { return serving }
        return "\(serving) · \(hint)"
    }

    private func conversionBinding(for food: FoodItem) -> Binding<String> {
        Binding(
            get: { conversions[food.id] ?? "" },
            set: {
                conversions[food.id] = $0
                hints[food.id] = nil
            }
        )
    }

    private func unitLabel(for quantity: String) -> String {
        servingUnits.first { $0.unit == servingUnit }?.displayString(for: quantity) ?? servingUnit
    }

    private func macrosText(_ macros: FoodMergePlan.Macros) -> Text {
        var result = RowIcon.calorie.macroText(
            EntryHelper.formatMacro(macros.calories),
            iconSize: 12,
            valueSize: 12,
            valueColor: .primary,
            isFirst: true
        )
        let values: [(RowIcon, Double)] = [
            (.protein, macros.protein),
            (.carbs, macros.carbs),
            (.fat, macros.fat),
            (.fiber, macros.fiber),
        ]
        for (icon, value) in values where value > 0 {
            let text = icon.macroText(
                EntryHelper.formatMacro(value),
                iconSize: 12,
                valueSize: 12,
                valueColor: .primary,
                isFirst: false
            )
            result = Text("\(result)\(text)")
        }
        return result
    }

    private static func portionInName(
        _ name: String,
        units: [ServingSizeUnit]
    ) -> (quantity: Double, unit: String)? {
        for match in name.matches(of: /(\d+(?:\.\d+)?)\s*([A-Za-z]+)/) {
            guard let quantity = Double(match.1), quantity > 0 else { continue }
            let word = match.2.lowercased()
            if let unit = units.first(where: { $0.unit == word || $0.pluralVariant == word }) {
                return (quantity, unit.unit)
            }
        }
        return nil
    }

    private static func roundedEstimate(_ value: Double) -> Double {
        let whole = value.rounded()
        if whole > 0, abs(value - whole) / whole <= 0.1 { return whole }
        return (value * 10).rounded() / 10
    }

    private static func guessConversions(
        foods: [FoodItem],
        kept: FoodItem,
        unit: String,
        units: [ServingSizeUnit]
    ) -> ([UUID: String], [UUID: String]) {
        var conversions: [UUID: String] = [:]
        var hints: [UUID: String] = [:]

        for food in foods where food.servingUnit?.unit != unit {
            if let portion = portionInName(food.name, units: units), portion.unit == unit {
                conversions[food.id] = EntryHelper.format(portion.quantity)
                hints[food.id] = String(localized: "Estimated from name")
            }
        }

        let exactAnchors = foods.filter { $0.servingUnit?.unit == unit }.map { ($0, $0.servingSize) }
        let nameAnchors = foods.compactMap { food -> (FoodItem, Double)? in
            guard let units = Double(conversions[food.id] ?? "") else { return nil }
            return (food, units)
        }
        let anchors = (exactAnchors + nameAnchors).filter { $0.0.calories > 0 && $0.1 > 0 }
        guard let anchor = anchors.first(where: { $0.0.id == kept.id }) ?? anchors.first
        else { return (conversions, hints) }

        let caloriesPerUnit = anchor.0.calories / anchor.1
        for food in foods where food.servingUnit?.unit != unit && conversions[food.id] == nil {
            let estimate = roundedEstimate(food.calories / caloriesPerUnit)
            guard estimate > 0 else { continue }
            conversions[food.id] = EntryHelper.format(estimate)
            hints[food.id] = String(localized: "Estimated from calories")
        }

        return (conversions, hints)
    }
}

private struct MergeLog: Identifiable {
    let log: LoggedEntry
    let food: FoodItem

    var id: UUID { log.id }

    func override(plan: FoodMergePlan, recalculating: Bool) -> LogHistoryRow.Override {
        let portion =
            plan.convertedPortion(quantity: log.loggedQuantity, unit: log.loggedUnit, of: food)
            ?? (log.loggedQuantity, log.loggedUnit)
        let macros = recalculating ? plan.recalculatedMacros(for: log, of: food) : nil
        return LogHistoryRow.Override(
            origin: food.name,
            quantity: portion.quantity,
            unit: portion.unit,
            calories: macros?.calories ?? log.calories,
            protein: macros?.protein ?? log.protein,
            carbs: macros?.carbs ?? log.carbs,
            fat: macros?.fat ?? log.fat,
            fiber: macros?.fiber ?? log.fiber,
            isRecalculated: macros.map { abs($0.calories - log.calories) >= 1 } ?? false
        )
    }
}

private struct MergeLogsView: View {
    let logs: [MergeLog]
    let plan: FoodMergePlan
    let recalculateLogs: Bool
    let servingUnits: [ServingSizeUnit]

    @State private var selectedLog: LoggedEntry?

    private struct LogMonth: Identifiable {
        let id: Date
        var logs: [MergeLog]
    }

    private var months: [LogMonth] {
        let calendar = Calendar.current
        var result: [LogMonth] = []
        for item in logs {
            let month =
                calendar.dateInterval(of: .month, for: item.log.timestamp)?.start
                ?? item.log.timestamp
            if result.last?.id == month {
                result[result.count - 1].logs.append(item)
            } else {
                result.append(LogMonth(id: month, logs: [item]))
            }
        }
        return result
    }

    var body: some View {
        let months = months

        ZStack {
            Color.background.ignoresSafeArea()

            ScrollView {
                LazyVStack {
                    ForEach(months) { month in
                        Card(month.id.formatted(.dateTime.month(.wide).year())) {
                            RowGroup(.divider, isLazy: true) {
                                ForEach(month.logs) { item in
                                    LogHistoryRow(
                                        entry: item.log,
                                        servingUnits: servingUnits,
                                        override: item.override(
                                            plan: plan,
                                            recalculating: recalculateLogs
                                        )
                                    ) {
                                        selectedLog = item.log
                                    }
                                }
                            }
                        }
                        .padding([.horizontal, .bottom])
                    }
                }
            }
        }
        .navigationTitle("All Logs")
        .navigationSubtitle(plan.trimmedName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedLog) { log in
            LoggedEntryDetailView(entry: log, isReadOnly: true, showsLibraryLink: false)
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

    let units = [
        ServingSizeUnit(unit: "serving", pluralVariant: "servings", displayOrder: 0),
        ServingSizeUnit(unit: "slice", pluralVariant: "slices", displayOrder: 1),
        ServingSizeUnit(unit: "g", displayOrder: 2),
    ]
    units.forEach(context.insert)

    let fourSlices = FoodItem(
        name: "Domino's Pan Pizza (4 slices)",
        source: EntrySource(source: "Domino's", displayOrder: 0),
        servingSize: 1,
        servingUnit: units[0],
        servingWeightUnit: "g",
        isAIEstimated: false,
        calories: 1040,
        protein: 44,
        carbs: 120,
        fat: 40,
        fiber: 6,
        isCustomDefaultServing: false,
        stickyNote: Note(text: "Ask for well done")
    )
    let sixSlices = FoodItem(
        name: "Domino's Pan Pizza",
        servingSize: 1,
        servingUnit: units[0],
        servingWeightUnit: "g",
        isAIEstimated: false,
        calories: 1560,
        protein: 66,
        carbs: 180,
        fat: 60,
        fiber: 9,
        isCustomDefaultServing: false
    )
    context.insert(fourSlices)
    context.insert(sixSlices)
    context.insert(FavoriteEntry(orderIndex: 0, foodItem: sixSlices))

    context.insert(
        LoggedEntry(
            name: fourSlices.name,
            typeRawValue: "food",
            originalFoodItem: fourSlices,
            timestamp: .now.addingTimeInterval(-6 * 86400),
            location: EntryLocation(name: "Domino's"),
            loggedQuantity: 1,
            loggedUnit: "serving",
            calories: 1040,
            protein: 44,
            carbs: 120,
            fat: 40,
            fiber: 6
        )
    )
    context.insert(
        LoggedEntry(
            name: sixSlices.name,
            typeRawValue: "food",
            originalFoodItem: sixSlices,
            timestamp: .now.addingTimeInterval(-12 * 86400),
            loggedQuantity: 1,
            loggedUnit: "serving",
            calories: 1580,
            protein: 66,
            carbs: 182,
            fat: 61,
            fiber: 9
        )
    )

    return NavigationStack {
        MergeFoodsView(
            foods: [fourSlices, sixSlices],
            kept: fourSlices,
            servingUnits: units,
            onConfirm: { _ in }
        )
    }
    .modelContainer(container)
}
