//
//  LogDrinkSheet.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/18/26.
//

import SwiftData
import SwiftUI

private struct PickerScrollTarget: Equatable {
    let id: UUID
    let animated: Bool
    let token = UUID()
}

struct LogDrinkSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.toastCenter) private var toastCenter
    @Environment(\.scenePhase) private var scenePhase

    @Query private var users: [User]
    @Query(FoodItem.drinksDescriptor) private var allDrinks: [FoodItem]

    private let editingEntry: LoggedEntry?
    private let initialDrink: FoodItem?
    private let day: Date
    private let logicalToday: Date
    private let passedDayStartMinutes: Int?
    private let focusesAmount: Bool
    private let onLogged: (() -> Void)?

    @State private var storedDrink: FoodItem?
    @State private var amountText: String
    @State private var chosenVolumeML: Double?
    @State private var timestamp: Date
    @State private var followsClock: Bool
    @State private var clockTimestamp: Date?
    @State private var locationSelection: LocationSelection = .none
    @State private var isSavingSize = false
    @State private var showAllDrinks = false
    @State private var entryForDetails: LoggedEntry?
    @State private var detailsEdit: HydrationLogEdit?
    @State private var newSizeName = ""
    @State private var pendingSizes: [PendingDrinkSize] = []
    @State private var contentHeight: CGFloat?
    @State private var chromeHeight: CGFloat = 0
    @State private var dragStartML: Double?
    @State private var dragFillML: Double?
    @State private var peakAmountML: Double = 0
    @State private var dragDetentID: UUID?
    @State private var recentLogVolumes: [Double] = []
    @State private var drinkToEdit: FoodItem?
    @State private var storedBuiltIns: [FoodItem] = []
    @State private var detailsPrefill: DrinkLogPrefill?
    @State private var pickerScrollTarget: PickerScrollTarget?
    @FocusState private var isAmountFocused: Bool

    init(
        day: Date,
        dayStartMinutes: Int,
        logicalToday: Date,
        drink: FoodItem? = nil,
        focusesAmount: Bool = true,
        onLogged: (() -> Void)? = nil
    ) {
        self.editingEntry = nil
        self.initialDrink = drink
        self.focusesAmount = focusesAmount
        self.onLogged = onLogged
        self.day = day
        self.logicalToday = logicalToday
        self.passedDayStartMinutes = dayStartMinutes
        _amountText = State(initialValue: "")
        let timestamp = HydrationLogger.timestamp(forDay: day, dayStartMinutes: dayStartMinutes)
        _timestamp = State(initialValue: timestamp)
        _followsClock = State(initialValue: true)
        _clockTimestamp = State(initialValue: timestamp)
    }

    init(editing entry: LoggedEntry) {
        self.editingEntry = entry
        self.initialDrink = nil
        self.focusesAmount = false
        self.onLogged = nil
        self.day = entry.timestamp
        self.logicalToday = entry.timestamp
        self.passedDayStartMinutes = nil
        _storedDrink = State(initialValue: entry.originalFoodItem)
        _amountText = State(initialValue: "")
        _timestamp = State(initialValue: entry.timestamp)
        _followsClock = State(initialValue: false)
        _locationSelection = State(initialValue: LocationSelection(entry.location))
    }

    private var selectedDrink: FoodItem? {
        guard let storedDrink, !storedDrink.isDeleted, storedDrink.modelContext != nil else { return nil }
        return storedDrink
    }

    private var selectionIsGone: Bool {
        editingEntry == nil && storedDrink != nil && selectedDrink?.isLoggableDrink != true
    }

    private var unit: VolumeUnit {
        users.first?.volumeUnit ?? .localeDefault
    }

    private var dayStartMinutes: Int {
        passedDayStartMinutes ?? users.first?.dayStartMinutes ?? 0
    }

    private var pastDaySubtitle: String? {
        guard editingEntry == nil, !Calendar.current.isDate(day, inSameDayAs: logicalToday) else { return nil }
        return EntryHelper.logDayText(day)
    }

    private var loggableDrinks: [FoodItem] {
        allDrinks.filter(\.isLoggableDrink)
    }

    private var pickerDrinks: [FoodItem] {
        var drinks = loggableDrinks
            .filter { $0.hydrationOrder != nil }
            .sorted { ($0.hydrationOrder ?? 0) < ($1.hydrationOrder ?? 0) }
        if let selectedDrink, selectedDrink.type == .drink, !drinks.contains(where: { $0.id == selectedDrink.id }) {
            drinks.append(selectedDrink)
        }
        return drinks
    }

    private var defaultDrink: FoodItem? {
        pickerDrinks.first ?? lastLoggedDrink ?? loggableDrinks.first
    }

    private var lastLoggedDrink: FoodItem? {
        var descriptor = FetchDescriptor<LoggedEntry>(
            predicate: #Predicate { $0.parentEntry == nil && $0.volumeML > 0 },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 20
        let logs = (try? modelContext.fetch(descriptor)) ?? []
        return logs.lazy
            .compactMap(\.originalFoodItem)
            .first { !$0.isDeleted && $0.modelContext != nil && $0.isLoggableDrink }
    }

    private var amountML: Double {
        if let chosenVolumeML { return chosenVolumeML }
        let separator = Locale.current.decimalSeparator ?? "."
        let value = Double(
            amountText
                .replacingOccurrences(of: separator, with: ".")
                .replacingOccurrences(of: ",", with: ".")
        ) ?? 0
        return unit.milliliters(from: value)
    }

    private var sizeOptions: [DrinkSizeOption] {
        guard let selectedDrink else { return [] }
        return selectedDrink.sortedDrinkSizes.map { DrinkSizeOption(id: $0.id, name: $0.name, volumeML: $0.volumeML) }
            + pendingSizes(for: selectedDrink).map { DrinkSizeOption(id: $0.id, name: $0.name, volumeML: $0.volumeML) }
    }

    private func pendingSizes(for drink: FoodItem) -> [PendingDrinkSize] {
        pendingSizes.filter { $0.foodID == drink.id }
    }

    private var matchingSize: DrinkSizeOption? {
        sizeOptions.first {
            HydrationLogger.isSameVolume($0.volumeML, amountML)
        }
    }

    private var recentAmounts: [Double] {
        guard let selectedDrink else { return [] }
        return HydrationLogger.recentAmounts(for: selectedDrink, volumes: recentLogVolumes)
    }

    private var isCustomAmount: Bool {
        isAmountFocused
            || (matchingSize == nil
                && !recentAmounts.contains { HydrationLogger.isSameVolume($0, amountML) })
    }

    private var canLog: Bool {
        (selectedDrink != nil || editingEntry != nil) && amountML > 0
    }

    private struct LogPreview {
        var amounts: DrinkAmounts
        var macros: [(icon: RowIcon, value: Double)]
    }

    private static func macros(
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        fiber: Double
    ) -> [(icon: RowIcon, value: Double)] {
        [(.calorie, calories), (.protein, protein), (.carbs, carbs), (.fat, fat), (.fiber, fiber)]
    }

    private var preview: LogPreview? {
        guard amountML > 0 else { return nil }
        if let editingEntry, editingEntry.volumeML > 0,
            editingEntry.originalFoodItem?.id == selectedDrink?.id
        {
            let ratio = amountML / editingEntry.volumeML
            return LogPreview(
                amounts: editingEntry.drinkAmounts.scaled(by: ratio),
                macros: Self.macros(
                    calories: editingEntry.calories * ratio,
                    protein: editingEntry.protein * ratio,
                    carbs: editingEntry.carbs * ratio,
                    fat: editingEntry.fat * ratio,
                    fiber: editingEntry.fiber * ratio
                )
            )
        }
        guard let selectedDrink, selectedDrink.type == .drink else { return nil }
        let servingVolume = selectedDrink.servingVolumeML ?? 0
        let multiplier = servingVolume > 0 ? amountML / servingVolume : 0
        return LogPreview(
            amounts: DrinkAmounts(
                food: selectedDrink,
                quantity: amountML,
                unit: VolumeUnit.milliliters.rawValue
            ),
            macros: Self.macros(
                calories: selectedDrink.calories * multiplier,
                protein: selectedDrink.protein * multiplier,
                carbs: selectedDrink.carbs * multiplier,
                fat: selectedDrink.fat * multiplier,
                fiber: selectedDrink.fiber * multiplier
            )
        )
    }

    private var factsText: String? {
        guard let preview else { return nil }
        let parts = preview.amounts.summary(unit: unit, calories: 0)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var macroText: Text? {
        guard let preview, preview.macros.contains(where: { $0.value > 0 }) else { return nil }
        var result: Text?
        for (index, macro) in preview.macros.enumerated() where index == 0 || macro.value > 0 {
            let part = macro.icon.macroText(
                EntryHelper.formatMacro(macro.value),
                iconSize: 13,
                valueSize: 13,
                valueColor: .primary,
                isFirst: result == nil
            )
            result = result.map { Text("\($0)\(part)") } ?? part
        }
        return result
    }

    private var combinedInfoText: Text {
        let facts = factsText.map { Text($0).foregroundStyle(.secondary) }
        switch (macroText, facts) {
        case let (macros?, facts?):
            return Text("\(macros)\(Text(verbatim: " · ").foregroundStyle(.secondary))\(facts)")
        case let (macros?, nil):
            return macros
        case let (nil, facts?):
            return facts
        case (nil, nil):
            return Text(verbatim: " ")
        }
    }

    private func infoLine(_ text: Text) -> some View {
        text
            .font(.subtitle)
            .lineLimit(1)
            .frame(height: FontSize.subtitleLineHeight)
    }

    private var showsMacroLine: Bool {
        if let selectedDrink, selectedDrink.type == .drink {
            return [selectedDrink.calories, selectedDrink.protein, selectedDrink.carbs, selectedDrink.fat, selectedDrink.fiber]
                .contains { $0 > 0 }
        }
        guard let editingEntry else { return false }
        return [editingEntry.calories, editingEntry.protein, editingEntry.carbs, editingEntry.fat, editingEntry.fiber]
            .contains { $0 > 0 }
    }

    private var showsFactsLine: Bool {
        if let selectedDrink, selectedDrink.type == .drink {
            return (selectedDrink.caffeineMg ?? 0) > 0
                || (selectedDrink.abv ?? 0) > 0
                || selectedDrink.hydrationPercent != 100
        }
        guard let editingEntry else { return false }
        return editingEntry.caffeineMg > 0
            || editingEntry.alcoholGrams > 0
            || !HydrationLogger.isSameVolume(editingEntry.hydrationML, editingEntry.volumeML)
    }

    private static let fillHeadroom = 1.2

    private var fillReferenceML: Double {
        let largest = sizeOptions.map(\.volumeML).max() ?? 0
        return max(largest * Self.fillHeadroom, 500, peakAmountML * Self.fillHeadroom)
    }

    private var fillFraction: Double {
        min(max((dragFillML ?? amountML) / fillReferenceML, 0), 1)
    }

    private var dragStepML: Double {
        unit == .milliliters ? 5 : unit.milliliters(from: 0.25)
    }

    private func draggedVolume(
        translation: CGFloat,
        from start: Double
    ) -> (raw: Double, volume: Double, size: DrinkSizeOption?) {
        let range = fillReferenceML
        let raw = start - Double(translation / DrinkFillGlyph.size.height) * range
        let clamped = min(max(raw, dragStepML), range)
        if let size = sizeOptions.first(where: { abs($0.volumeML - clamped) <= dragStepML }) {
            return (clamped, size.volumeML, size)
        }
        return (clamped, (clamped / dragStepML).rounded() * dragStepML, nil)
    }

    private var fillDrag: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                let start = dragStartML ?? amountML
                if dragStartML == nil {
                    dragStartML = start
                }
                let result = draggedVolume(translation: value.translation.height, from: start)
                dragFillML = result.raw
                dragDetentID = result.size?.id
                if !HydrationLogger.isSameVolume(result.volume, amountML) {
                    setAmount(result.volume)
                }
            }
            .onEnded { _ in
                dragStartML = nil
                dragFillML = nil
                dragDetentID = nil
            }
    }

    private func adjustAmount(by steps: Double) {
        let volume = min(max(amountML + steps * dragStepML, dragStepML), fillReferenceML)
        setAmount(volume)
    }

    private func editableValue(_ milliliters: Double) -> String {
        let text = unit.editableText(fromML: milliliters)
        let separator = Locale.current.decimalSeparator ?? "."
        return separator == "." ? text : text.replacingOccurrences(of: ".", with: separator)
    }

    private func setAmount(_ milliliters: Double) {
        isAmountFocused = false
        amountText = editableValue(milliliters)
        chosenVolumeML = milliliters
    }

    private func loadRecentLogs(for drink: FoodItem?) {
        guard let drink else {
            recentLogVolumes = []
            return
        }
        let logs = (try? modelContext.fetch(HydrationLogger.recentLogsDescriptor(for: drink))) ?? []
        recentLogVolumes = logs
            .filter { $0.persistentModelID != editingEntry?.persistentModelID }
            .map(\.volumeML)
    }

    private func select(_ drink: FoodItem) {
        guard drink.id != selectedDrink?.id else { return }
        if editingEntry != nil {
            followDefaultLocation(from: selectedDrink, to: drink)
        }
        storedDrink = drink
        loadRecentLogs(for: drink)
        defer { peakAmountML = amountML }
        if editingEntry != nil, amountML > 0 { return }
        if let lastVolume = recentLogVolumes.first {
            setAmount(lastVolume)
        } else if let size = drink.defaultDrinkSize {
            setAmount(size.volumeML)
        } else if let volume = drink.servingVolumeML {
            setAmount(volume)
        }
    }

    @discardableResult
    private func refreshTimestamp() -> Date {
        guard followsClock else { return timestamp }
        let now = HydrationLogger.timestamp(forDay: day, dayStartMinutes: dayStartMinutes)
        clockTimestamp = now
        timestamp = now
        return now
    }

    private func scrollPicker(to drink: FoodItem?, animated: Bool) {
        guard let drink else { return }
        pickerScrollTarget = PickerScrollTarget(id: drink.id, animated: animated)
    }

    private func followDefaultLocation(from oldDrink: FoodItem?, to newDrink: FoodItem) {
        let oldDefault = oldDrink.flatMap { HydrationLogger.defaultLocation(for: $0, in: modelContext) }
        guard locationSelection.resolvedLocation == oldDefault else { return }
        locationSelection = LocationSelection(HydrationLogger.defaultLocation(for: newDrink, in: modelContext))
    }

    private func chooseFromList(_ drink: FoodItem) {
        guard !BuiltInCatalog.isStored(drink) else {
            select(drink)
            scrollPicker(to: drink, animated: true)
            return
        }
        do {
            let stored = try BuiltInCatalog.stored(drink, in: modelContext)
            storedBuiltIns.append(stored)
            select(stored)
            scrollPicker(to: stored, animated: true)
        } catch {
            toastCenter?.show(.failure(String(localized: "Couldn't Open \(drink.name)")))
        }
    }

    private func discardUnusedBuiltIns() {
        for drink in storedBuiltIns {
            BuiltInCatalog.discardIfUnused(drink, in: modelContext)
        }
        storedBuiltIns = []
    }

    private func prepareInitialState() {
        defer { scrollPicker(to: selectedDrink, animated: false) }
        if let editingEntry {
            if amountText.isEmpty {
                setAmount(editingEntry.volumeML)
                loadRecentLogs(for: selectedDrink)
            }
            return
        }
        guard selectedDrink == nil else { return }
        if let initialDrink, initialDrink.isLoggableDrink {
            guard focusesAmount else {
                select(initialDrink)
                return
            }
            storedDrink = initialDrink
            loadRecentLogs(for: initialDrink)
            isAmountFocused = true
            return
        }
        if let drink = defaultDrink {
            select(drink)
        }
    }

    private func replaceGoneSelection() {
        guard selectionIsGone else { return }
        pendingSizes.removeAll()
        storedDrink = nil
        recentLogVolumes = []
        if let drink = defaultDrink {
            select(drink)
        } else {
            amountText = ""
            chosenVolumeML = nil
        }
    }

    private func dropSavedPendingSizes() {
        guard let selectedDrink else { return }
        pendingSizes.removeAll { pending in
            pending.foodID == selectedDrink.id
                && selectedDrink.sortedDrinkSizes.contains { HydrationLogger.isSameVolume($0.volumeML, pending.volumeML) }
        }
    }

    private func saveSize() {
        guard let selectedDrink, amountML > 0 else { return }
        let trimmed = newSizeName.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingSizes.append(
            PendingDrinkSize(foodID: selectedDrink.id, name: trimmed.isEmpty ? nil : trimmed, volumeML: amountML)
        )
        isAmountFocused = false
        newSizeName = ""
    }

    private func addPendingSizes(to drink: FoodItem?) -> Bool {
        guard let drink else { return false }
        let pending = pendingSizes(for: drink)
        HydrationLogger.addSizes(pending, to: drink, in: modelContext)
        return !pending.isEmpty
    }

    private func saveEdits(to entry: LoggedEntry) -> Bool {
        guard amountML > 0 else { return false }
        isAmountFocused = false
        let name = entry.name
        let goalFeedback = WaterGoalFeedback(at: timestamp, in: modelContext)
        let addedSizes = addPendingSizes(to: selectedDrink)
        HydrationLogger.update(entry, to: selectedDrink, volumeML: amountML)
        if addedSizes, let selectedDrink, entry.originalFoodItem?.id == selectedDrink.id {
            entry.sizeName = HydrationLogger.sizeName(for: selectedDrink, volumeML: entry.volumeML)
        }
        entry.timestamp = timestamp
        let newLocation = locationSelection.resolvedLocation
        let awaitsCurrent = locationSelection.isCurrent && newLocation == nil
        if !awaitsCurrent, newLocation != entry.location {
            RecentLocationStore.record(newLocation, usedAt: timestamp, in: modelContext)
            entry.setLocation(newLocation, in: modelContext)
        }
        do {
            try modelContext.save()
            QuickLogger.finishLocation(
                of: entry,
                awaitingCurrent: awaitsCurrent,
                replacing: entry.storedLocation,
                in: modelContext
            )
            goalFeedback.playIfReached()
            return true
        } catch {
            modelContext.rollback()
            toastCenter?.show(.failure(String(localized: "Couldn't Save Changes"), message: name))
            return false
        }
    }

    private func delete(_ entry: LoggedEntry) {
        isAmountFocused = false
        dismiss()
        EntryActions.delete(entry, in: modelContext, toastCenter: toastCenter)
    }

    private func finishLogging() {
        if let onLogged {
            onLogged()
        } else {
            dismiss()
        }
    }

    private func openNewDetails() {
        guard let drink = selectedDrink, amountML > 0 else { return }
        isAmountFocused = false
        detailsPrefill = DrinkLogPrefill(
            drink: drink,
            volumeML: amountML,
            timestamp: refreshTimestamp(),
            pendingSizes: pendingSizes(for: drink)
        )
    }

    private func openDetails(for entry: LoggedEntry) {
        guard amountML > 0 else { return }
        isAmountFocused = false
        detailsEdit = HydrationLogEdit(
            drink: selectedDrink,
            volumeML: amountML,
            timestamp: timestamp,
            location: locationSelection.resolvedLocation
        )
        entryForDetails = entry
    }

    private func commit() {
        if let editingEntry {
            if saveEdits(to: editingEntry) { dismiss() }
            return
        }

        guard let drink = selectedDrink, amountML > 0 else { return }
        isAmountFocused = false
        let originalDrink = pendingSizes(for: drink).isEmpty ? nil : MacroBackup.foodRecord(drink)
        _ = addPendingSizes(to: drink)
        let sizeName = HydrationLogger.sizeName(for: drink, volumeML: amountML)
        let timestamp = refreshTimestamp()
        let goalFeedback = WaterGoalFeedback(at: timestamp, in: modelContext)

        do {
            let entry = try withAnimation {
                try HydrationLogger.log(
                    drink,
                    volumeML: amountML,
                    sizeName: sizeName,
                    at: timestamp,
                    in: modelContext
                )
            }
            goalFeedback.playIfReached()
            finishLogging()
            if let toastCenter {
                toastCenter.show(
                    .hydrationLogged(
                        entry,
                        originalDrink: originalDrink,
                        title: HydrationLogger.loggedTitle(forDay: day, logicalToday: logicalToday),
                        unit: unit,
                        in: modelContext,
                        presenter: toastCenter
                    )
                )
            }
        } catch {
            toastCenter?.show(.failure(String(localized: "Couldn't Log Drink"), message: drink.name))
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()

                ScrollView {
                    VStack {
                        if editingEntry != nil {
                            Card {
                                drinkPicker
                            }
                            .padding(.horizontal)
                        }

                        Card {
                            amountSection
                                .overlay(alignment: .topTrailing) {
                                    if editingEntry == nil {
                                        DateTimePill(selection: $timestamp, components: .hourAndMinute)
                                        .padding([.top, .trailing], 12)
                                        .accessibilityLabel("Time")
                                    }
                                }
                        }
                        .padding(editingEntry == nil ? [.horizontal] : [.top, .horizontal])

                        if editingEntry == nil {
                            Card {
                                RowGroup(.divider) {
                                    drinkPicker

                                    Button {
                                        openNewDetails()
                                    } label: {
                                        NavigationRow(title: String(localized: "Add Details"))
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(!canLog)
                                }
                            }
                            .padding([.top, .horizontal])
                        }

                        if let editingEntry {
                            Card {
                                RowGroup(.divider) {
                                    DateTimePillRow(
                                        title: "Date & Time",
                                        dateSelection: $timestamp,
                                        timeSelection: $timestamp
                                    )

                                    if editingEntry.location != nil || !locationSelection.isNone {
                                        LocationRow(
                                            selection: $locationSelection,
                                            food: selectedDrink,
                                            logDate: timestamp
                                        )
                                    }

                                    Button {
                                        openDetails(for: editingEntry)
                                    } label: {
                                        NavigationRow(
                                            title: String(localized: "Add Details")
                                        )
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(!canLog)
                                } bottomContent: {
                                    Divider()
                                        .padding(.horizontal, 16)

                                    ButtonRow(
                                        icon: .customSymbol("trash", tint: .red),
                                        title: "Delete Log",
                                        tint: .destructiveFill,
                                        textColor: .red
                                    ) {
                                        delete(editingEntry)
                                    }
                                }
                            }
                            .padding([.top, .horizontal])
                        }
                    }
                    .padding(.bottom, 26)
                    .onGeometryChange(for: CGSize.self) { proxy in
                        proxy.size
                    } action: { size in
                        guard size.width >= 300 else { return }
                        contentHeight = size.height
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .ignoresSafeArea(.container, edges: .bottom)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.safeAreaInsets.top
                } action: { inset in
                    chromeHeight = inset
                }
            }
            .navigationTitle(editingEntry == nil ? "Log Drink" : "Edit Drink")
            .pastDaySubtitle(pastDaySubtitle)
            .titleMenu(isShown: editingEntry == nil) {
                Button {
                    isAmountFocused = false
                    drinkToEdit = selectedDrink
                } label: {
                    Label("Edit in Library", systemImage: "pencil")
                    if let selectedDrink {
                        Text(selectedDrink.name)
                    }
                }
                .disabled(selectedDrink == nil)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel("Close")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        commit()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel(editingEntry == nil ? "Log Drink" : "Save Changes")
                    .disabled(!canLog)
                    .tint(Color.accentColor)
                    .buttonStyle(.glassProminent)
                }
            }
        }
        .fittedSheetHeight(contentHeight.map { $0 + chromeHeight })
        .sheet(item: $entryForDetails) { entry in
            NavigationStack {
                LoggedEntryDetailView(
                    entry: entry,
                    isPushedView: false,
                    startsEditing: true,
                    onSaveDismiss: {
                        if addPendingSizes(to: selectedDrink) {
                            if let drink = entry.originalFoodItem, drink.id == selectedDrink?.id {
                                entry.sizeName = HydrationLogger.sizeName(for: drink, volumeML: entry.volumeML)
                            }
                            try? modelContext.save()
                        }
                        dismiss()
                    },
                    hydrationEdit: detailsEdit
                )
            }
            .environment(\.tabBarHeight, 0)
        }
        .sheet(item: $detailsPrefill) { prefill in
            LogEntryView(food: prefill.drink, drinkPrefill: prefill)
                .environment(\.rootDismiss, finishLogging)
                .environment(\.tabBarHeight, 0)
        }
        .onAppear(perform: prepareInitialState)
        .onDisappear(perform: discardUnusedBuiltIns)
        .task(id: followsClock) {
            guard followsClock else { return }
            while !Task.isCancelled {
                let now = Date()
                let nextMinute = Calendar.current.nextDate(
                    after: now,
                    matching: DateComponents(second: 0),
                    matchingPolicy: .nextTime
                ) ?? now.addingTimeInterval(60)
                try? await Task.sleep(for: .seconds(nextMinute.timeIntervalSince(now)))
                guard !Task.isCancelled else { return }
                refreshTimestamp()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refreshTimestamp()
            }
        }
        .onChange(of: amountML) { _, volume in
            guard dragStartML == nil, volume > peakAmountML else { return }
            peakAmountML = volume
        }
        .onChange(of: amountText) { _, text in
            if let chosenVolumeML, text != editableValue(chosenVolumeML) {
                self.chosenVolumeML = nil
            }
        }
        .onChange(of: timestamp) { _, newValue in
            guard editingEntry == nil else { return }
            if newValue != clockTimestamp {
                followsClock = false
            }
            let placed = HydrationLogger.place(newValue, inDay: day, dayStartMinutes: dayStartMinutes)
            if placed != newValue { timestamp = placed }
        }
        .sheet(isPresented: $showAllDrinks, onDismiss: dropSavedPendingSizes) {
            DrinkListView(
                mode: .choose(selectedID: selectedDrink?.id, onSelect: chooseFromList),
                allowsDelete: editingEntry == nil
            )
        }
        .sheet(item: $drinkToEdit, onDismiss: dropSavedPendingSizes) { drink in
            EditEntryView(foodItem: drink, onSaveInstantly: { saved in
                if saved.isLoggableDrink { select(saved) }
            })
        }
        .onChange(of: selectionIsGone) { _, isGone in
            if isGone { replaceGoneSelection() }
        }
        .alert("Save Size", isPresented: $isSavingSize) {
            TextField("Name (Optional)", text: $newSizeName)
            Button("Cancel", role: .cancel) { newSizeName = "" }
            Button("Save") { saveSize() }
        } message: {
            Text("Saves \(unit.formattedAmount(amountML)) as a size for \(selectedDrink?.name ?? "")")
        }
    }

    private var drinkPicker: some View {
        HStack(alignment: .top, spacing: 4) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(pickerDrinks) { drink in
                            DrinkPickerButton(
                                drink: drink,
                                isSelected: drink.id == selectedDrink?.id
                            ) {
                                select(drink)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .scrollIndicators(.hidden)
                .chipScrollFade()
                .onChange(of: pickerScrollTarget, initial: true) { _, target in
                    guard let target else { return }
                    withAnimation(target.animated ? .snappy : nil) {
                        proxy.scrollTo(target.id, anchor: .center)
                    }
                }
            }

            Button {
                showAllDrinks = true
            } label: {
                DrinkPickerLabel(
                    symbol: "square.grid.2x2",
                    title: String(localized: "All Drinks"),
                    tint: .secondary,
                    isSelected: false
                )
            }
            .buttonStyle(.plain)
            .padding(.vertical, 12)
            .padding(.trailing, 16)
        }
    }

    private var amountSection: some View {
        VStack(spacing: 12) {
            DrinkFillGlyph(
                symbol: selectedDrink?.drinkSymbol ?? DrinkFormState.defaultSymbol,
                tint: (selectedDrink?.drinkTint ?? DrinkFormState.defaultTint).color,
                fraction: fillFraction,
                animatesLevel: dragStartML == nil
            )
            .contentShape(Rectangle())
            .gesture(fillDrag)
            .sensoryFeedback(.selection, trigger: dragDetentID) { _, new in new != nil }
            .accessibilityElement()
            .accessibilityLabel("Amount")
            .accessibilityValue(unit.formattedAmount(amountML))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: adjustAmount(by: 1)
                case .decrement: adjustAmount(by: -1)
                @unknown default: break
                }
            }
            .padding(.top, 14)

            VStack(spacing: 2) {
                Text(verbatim: "0").font(.pageTitle)
                Text(verbatim: " ").font(.subtitle)
                Text(verbatim: " ").font(.subtitle)
            }
            .frame(maxWidth: .infinity)
            .hidden()
            .overlay {
                VStack(spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        let amountFont: Font = showsMacroLine || showsFactsLine ? .pageTitle : .largeAmount
                        Text(verbatim: amountText.isEmpty ? "0" : amountText)
                            .font(amountFont)
                            .fixedSize()
                            .padding(.trailing, 2)
                            .hidden()
                            .overlay(alignment: .leading) {
                                TextField("0", text: $amountText)
                                    .font(amountFont)
                                    .keyboardType(.decimalPad)
                                    .focused($isAmountFocused)
                                    .accessibilityLabel("Amount")
                            }

                        Text(unit.rawValue)
                            .font(.rowValue)
                            .foregroundStyle(.secondary)
                    }

                    if showsMacroLine || showsFactsLine {
                        ViewThatFits(in: .horizontal) {
                            infoLine(combinedInfoText)

                            VStack(spacing: 2) {
                                if showsMacroLine {
                                    infoLine(macroText ?? Text(verbatim: " "))
                                        .minimumScaleFactor(0.8)
                                }

                                if showsFactsLine {
                                    infoLine(Text(factsText ?? " ").foregroundStyle(.secondary))
                                        .minimumScaleFactor(0.8)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(sizeOptions) { size in
                        Button {
                            setAmount(size.volumeML)
                        } label: {
                            Text(sizeLabel(size))
                        }
                        .buttonStyle(
                            .filterChip(isSelected: !isAmountFocused && matchingSize?.id == size.id)
                        )
                    }

                    ForEach(recentAmounts, id: \.self) { volume in
                        Button {
                            setAmount(volume)
                        } label: {
                            Label(unit.formattedAmount(volume), systemImage: "clock.arrow.circlepath")
                                .labelStyle(.titleAndIcon)
                        }
                        .buttonStyle(
                            .filterChip(
                                isSelected: !isAmountFocused
                                    && HydrationLogger.isSameVolume(volume, amountML)
                            )
                        )
                    }

                    Button("Custom") {
                        isAmountFocused = true
                    }
                    .buttonStyle(.filterChip(isSelected: isCustomAmount))

                    if canLog, selectedDrink?.type == .drink, matchingSize == nil {
                        Button("Save as Size", systemImage: "plus") {
                            isSavingSize = true
                        }
                        .labelStyle(.titleAndIcon)
                        .buttonStyle(.filterChip(isSelected: false))
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, 16)
                .animation(.easeInOut(duration: 0.2), value: matchingSize == nil)
            }
            .scrollIndicators(.hidden)
            .chipScrollFade()
        }
        .padding(.vertical, 14)
    }

    private func sizeLabel(_ size: DrinkSizeOption) -> String {
        let amount = unit.formattedAmount(size.volumeML)
        guard let name = size.name, !name.isEmpty else { return amount }
        return "\(name) · \(amount)"
    }
}

private extension View {
    @ViewBuilder
    func pastDaySubtitle(_ subtitle: String?) -> some View {
        if let subtitle {
            navigationSubtitle(subtitle)
        } else {
            self
        }
    }
}

extension View {
    @ViewBuilder
    func titleMenu<C: View>(isShown: Bool, @ViewBuilder content: () -> C) -> some View {
        if isShown {
            toolbarTitleMenu(content: content)
        } else {
            self
        }
    }
}

private struct DrinkSizeOption: Identifiable {
    let id: UUID
    let name: String?
    let volumeML: Double
}

struct DrinkPickerButton: View {
    let drink: FoodItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            DrinkPickerLabel(
                symbol: drink.drinkSymbol,
                title: drink.name,
                tint: drink.drinkTint.color,
                isSelected: isSelected
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct DrinkPickerLabel: View {
    let symbol: String
    let title: String
    let tint: Color
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            Image(symbol: symbol)
                .font(.largeIcon)
                .foregroundStyle(isSelected ? Color.white : tint)
                .frame(width: 52, height: 52)
                .background(Circle().fill(isSelected ? tint : Color.controlFill))

            Text(title)
                .font(isSelected ? .detailEmphasis : .detail)
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .lineLimit(1)
        }
        .frame(width: 64)
        .contentShape(Rectangle())
    }
}

#Preview {
    let container = try! ModelContainer(
        for: User.self, FoodItem.self, LoggedEntry.self, ServingSizeUnit.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    )
    container.mainContext.insert(User(onboardingComplete: true))
    AppSeeder.resetListSeeding()
    try? AppSeeder.seedDefaults(into: container.mainContext)

    return LogDrinkSheet(
        day: .now,
        dayStartMinutes: 0,
        logicalToday: Calendar.current.startOfDay(for: .now)
    )
    .modelContainer(container)
}

#Preview("Latte") {
    let container = try! ModelContainer(
        for: User.self, FoodItem.self, LoggedEntry.self, ServingSizeUnit.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    )
    container.mainContext.insert(User(onboardingComplete: true))
    AppSeeder.resetListSeeding()
    try? AppSeeder.seedDefaults(into: container.mainContext)
    let coffee = (try? container.mainContext.fetch(FetchDescriptor<FoodItem>()))?
        .first { $0.seedKey == "coffee" }
    coffee?.name = "Latte"
    coffee?.calories = 120
    coffee?.protein = 6.5
    coffee?.carbs = 10
    coffee?.fat = 5
    coffee?.hasNutrition = true
    if let coffee {
        _ = try? HydrationLogger.log(coffee, volumeML: 350, sizeName: "Mug", at: .now, in: container.mainContext)
    }

    return LogDrinkSheet(
        day: .now,
        dayStartMinutes: 0,
        logicalToday: Calendar.current.startOfDay(for: .now)
    )
    .modelContainer(container)
}
