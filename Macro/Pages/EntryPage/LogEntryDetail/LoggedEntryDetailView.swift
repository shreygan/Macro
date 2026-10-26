//
//  LoggedEntryDetailView.swift
//  Macro
//
//  Created by Shrey Gangwar on 8/3/26.
//

import SwiftData
import SwiftUI

struct HydrationLogEdit {
    let drink: FoodItem?
    let volumeML: Double
    let timestamp: Date
    var location: EntryLocation?
}

struct LoggedEntryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @Environment(\.toastCenter) private var toastCenter
    @Environment(\.volumeUnit) private var volumeUnit
    @Environment(\.tracksHydration) private var tracksHydration

    let entry: LoggedEntry
    var isPushedView: Bool = true
    var allowsEditing: Bool = true
    var showsActionsAndLinks: Bool = true
    var showsLibraryLink: Bool = true
    var showsMapLink: Bool = true
    var onRemovePhotos: (() -> Void)? = nil
    private let dismissesAfterEditing: Bool
    private let onSaveDismiss: (() -> Void)?
    private let pendingDrink: FoodItem?
    private let drinkSnapshot: DrinkSnapshot

    private var linkedFood: FoodItem? {
        pendingDrink ?? entry.originalFoodItem
    }

    @State private var isEditing: Bool = false
    @State private var foodToLogAgain: FoodItem? = nil
    @State private var popAfterLogAgain = false
    @State private var showAddToLibrary = false
    @State private var foodToView: FoodItem? = nil
    @State private var showingMap = false
    @State private var isDismissing = false
    @State private var savePrompt: SavePromptStep?

    @Query private var users: [User]
    @Query(sort: \EntrySource.displayOrder) var sourceOptions: [EntrySource]
    @Query(sort: \CategorySource.displayOrder) var categoryOptions:
        [CategorySource]
    @Query(sort: \FoodGroupSource.displayOrder) var foodGroupOptions:
        [FoodGroupSource]
    @Query(sort: \ServingSizeUnit.displayOrder) var portionUnitOptions:
        [ServingSizeUnit]

    @State private var name: String
    @State private var sourceSelection: String
    @State private var categorySelection: String
    @State private var foodGroupSelection: String

    @State private var date: Date
    @State private var time: Date
    @State private var locationSelection: LocationSelection

    @State private var portionQuantity: String
    @State private var portionUnitSelection: String
    @State private var chosenVolumeML: Double?
    @State private var recentDrinkAmounts: [Double] = []
    @State private var skipsPortionRescale = false

    @State private var manualOverrideToggle: Bool
    @State private var caffeine: String
    @State private var abv: String

    @State private var calorie: String
    @State private var protein: String
    @State private var carbs: String
    @State private var fat: String
    @State private var fiber: String

    @State private var stickyNote: String
    @State private var pinnedNoteText: String
    @State private var originalPinnedNote: String
    @State private var showingAllNotes: Bool = false
    @State private var showingAllPhotos: Bool = false
    @State private var hasPhotoHistory: Bool = false

    @State private var selectedPhotos: [LoggedPhoto] = []
    @State private var isLoadingPhotos = false

    @State private var draftIngredients: [LogRecipeIngredient]
    @State private var showIngredientSelectionSheet = false
    @State private var focusManager = SwipeFocusManager()

    private let baseServingSize: Double
    private let baseServingWeight: Double?
    private let baseServingWeightUnit: String
    private let baseUnit: String

    private let calorieStatic: String
    private let proteinStatic: String
    private let carbsStatic: String
    private let fatStatic: String
    private let fiberStatic: String

    @State private var calorieDynamic: String
    @State private var proteinDynamic: String
    @State private var carbsDynamic: String
    @State private var fatDynamic: String
    @State private var fiberDynamic: String

    init(
        entry: LoggedEntry,
        isPushedView: Bool = true,
        allowsEditing: Bool = true,
        showsActionsAndLinks: Bool = true,
        showsLibraryLink: Bool = true,
        showsMapLink: Bool = true,
        startsEditing: Bool = false,
        onSaveDismiss: (() -> Void)? = nil,
        hydrationEdit: HydrationLogEdit? = nil,
        onRemovePhotos: (() -> Void)? = nil
    ) {
        self.entry = entry
        self.isPushedView = isPushedView
        self.allowsEditing = allowsEditing
        self.showsActionsAndLinks = showsActionsAndLinks
        self.showsLibraryLink = showsLibraryLink
        self.showsMapLink = showsMapLink
        self.onRemovePhotos = onRemovePhotos
        self.dismissesAfterEditing = startsEditing && allowsEditing
        self.onSaveDismiss = onSaveDismiss
        let pendingDrink = hydrationEdit?.drink.flatMap {
            $0.id == entry.originalFoodItem?.id ? nil : $0
        }
        self.pendingDrink = pendingDrink
        self.drinkSnapshot = DrinkSnapshot(entry)
        let food = pendingDrink ?? entry.originalFoodItem
        let loggedMacro = { (pending: Double?, logged: Double) -> String in
            let storedText = EntryHelper.formatLoggedMacro(logged, of: entry, food: entry.originalFoodItem)
            guard let hydrationEdit else { return storedText }
            if let pending, let drink = pendingDrink {
                let servingVolume = drink.servingVolumeML ?? 0
                guard servingVolume > 0 else { return "0" }
                return EntryHelper.scale(EntryHelper.format(pending), by: hydrationEdit.volumeML / servingVolume)
            }
            let ratio = entry.volumeML > 0 ? hydrationEdit.volumeML / entry.volumeML : 1
            return EntryHelper.isUnscaled(ratio) ? storedText : EntryHelper.formatMacroField(logged * ratio)
        }
        _isEditing = State(initialValue: dismissesAfterEditing)

        _name = State(initialValue: pendingDrink?.name ?? entry.name)
        let tags = pendingDrink.map { ($0.source, $0.category, $0.foodGroup) }
            ?? (entry.source, entry.category, entry.foodGroup)
        _sourceSelection = State(initialValue: tags.0?.source ?? "")
        _categorySelection = State(initialValue: tags.1?.category ?? "")
        _foodGroupSelection = State(initialValue: tags.2?.foodGroup ?? "")

        _date = State(initialValue: hydrationEdit?.timestamp ?? entry.timestamp)
        _time = State(initialValue: hydrationEdit?.timestamp ?? entry.timestamp)
        _locationSelection = State(initialValue: LocationSelection(hydrationEdit.map(\.location) ?? entry.location))

        _portionQuantity = State(
            initialValue: EntryHelper.format(hydrationEdit?.volumeML ?? entry.loggedQuantity)
        )
        _portionUnitSelection = State(
            initialValue: hydrationEdit == nil ? entry.loggedUnit : VolumeUnit.milliliters.rawValue
        )

        _manualOverrideToggle = State(initialValue: entry.isManualOverride)
        _caffeine = State(initialValue: Self.caffeineText(for: entry))
        _abv = State(initialValue: Self.abvText(for: entry))

        _calorie = State(initialValue: loggedMacro(pendingDrink?.calories, entry.calories))
        _protein = State(initialValue: loggedMacro(pendingDrink?.protein, entry.protein))
        _carbs = State(initialValue: loggedMacro(pendingDrink?.carbs, entry.carbs))
        _fat = State(initialValue: loggedMacro(pendingDrink?.fat, entry.fat))
        _fiber = State(initialValue: loggedMacro(pendingDrink?.fiber, entry.fiber))

        _stickyNote = State(initialValue: entry.logNote ?? "")
        _pinnedNoteText = State(
            initialValue: food?.stickyNote?.text ?? ""
        )
        _originalPinnedNote = State(
            initialValue: food?.stickyNote?.text ?? ""
        )

        _selectedPhotos = State(
            initialValue: EntryHelper.loggedPhotos(from: entry.photos)
        )
        _draftIngredients = State(
            initialValue: LogRecipeIngredient.makeDrafts(for: entry)
        )

        // Without the original item, the logged portion itself is the base
        // (the fallback macros below are the logged values too)
        let originalFood = food
        self.baseServingSize =
            originalFood?.servingSize
            ?? (entry.loggedQuantity > 0 ? entry.loggedQuantity : 1.0)
        self.baseServingWeight = originalFood?.servingWeight
        self.baseServingWeightUnit = originalFood?.servingWeightUnit ?? "g"
        self.baseUnit = originalFood?.servingUnit?.unit ?? entry.loggedUnit

        let calStr = EntryHelper.format(
            originalFood?.calories ?? entry.calories
        )
        let proStr = EntryHelper.format(originalFood?.protein ?? entry.protein)
        let carbStr = EntryHelper.format(originalFood?.carbs ?? entry.carbs)
        let fatStr = EntryHelper.format(originalFood?.fat ?? entry.fat)
        let fibStr = EntryHelper.format(originalFood?.fiber ?? entry.fiber)

        self.calorieStatic = calStr
        self.proteinStatic = proStr
        self.carbsStatic = carbStr
        self.fatStatic = fatStr
        self.fiberStatic = fibStr

        _calorieDynamic = State(initialValue: calStr)
        _proteinDynamic = State(initialValue: proStr)
        _carbsDynamic = State(initialValue: carbStr)
        _fatDynamic = State(initialValue: fatStr)
        _fiberDynamic = State(initialValue: fibStr)
    }

    private var isRecipe: Bool { entry.entryType == .recipe }

    private static func caffeineText(for entry: LoggedEntry) -> String {
        entry.isManualOverride ? EntryHelper.format(entry.caffeineMg.rounded()) : ""
    }

    private static func abvText(for entry: LoggedEntry) -> String {
        entry.isManualOverride ? EntryHelper.formatMacroField(entry.drinkAmounts.abv ?? 0) : ""
    }

    private static func parse(_ text: String) -> Double {
        Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var linkedDrink: FoodItem? {
        guard entry.entryType == .drink, !isRecipe, let food = linkedFood, food.type == .drink else { return nil }
        return food
    }

    private var showsCaffeineRow: Bool {
        guard entry.entryType == .drink, !isRecipe else { return false }
        return linkedDrink?.caffeineMg != nil || entry.caffeineMg > 0
    }

    private var showsAlcoholRow: Bool {
        guard entry.entryType == .drink, !isRecipe else { return false }
        return linkedDrink?.abv != nil || entry.alcoholGrams > 0
    }

    private var clearsDrinkOverride: Bool {
        entry.isManualOverride && !manualOverrideToggle && linkedDrink != nil
    }

    private var portionDrinkAmounts: DrinkAmounts {
        let portion = resolvedPortion
        if clearsDrinkOverride, let food = linkedDrink {
            return DrinkAmounts(food: food, quantity: portion.quantity, unit: portion.unit)
        }
        return drinkSnapshot.amounts(for: linkedFood, quantity: portion.quantity, unit: portion.unit)
    }

    private var overriddenDrinkAmounts: (caffeineMg: Double?, abv: Double?) {
        guard manualOverrideToggle else { return (nil, nil) }
        return (
            showsCaffeineRow ? Self.parse(caffeine) : nil,
            showsAlcoholRow ? Self.parse(abv) : nil
        )
    }

    private var computedCaffeineText: String {
        EntryHelper.format(portionDrinkAmounts.caffeineMg.rounded())
    }

    private var computedABVText: String {
        EntryHelper.formatMacroField(portionDrinkAmounts.abv ?? linkedDrink?.abv ?? 0)
    }

    private var caffeineField: Binding<String> {
        Binding(
            get: { manualOverrideToggle ? caffeine : computedCaffeineText },
            set: { caffeine = $0 }
        )
    }

    private var abvField: Binding<String> {
        Binding(
            get: { manualOverrideToggle ? abv : computedABVText },
            set: { abv = $0 }
        )
    }

    private var drinkHeaderInfo: DrinkRowInfo? {
        guard entry.entryType == .drink, !isRecipe else { return nil }
        let parse = { (text: String) in Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0 }
        let hasMacros = [calorie, protein, carbs, fat, fiber].contains { parse($0) > 0 }
        if let food = linkedDrink {
            let override = overriddenDrinkAmounts
            return DrinkRowInfo(
                food: food,
                amounts: portionDrinkAmounts.overriding(caffeineMg: override.caffeineMg, abv: override.abv),
                hasMacros: hasMacros
            )
        }
        guard var info = DrinkRowInfo(entry: entry) else { return nil }
        let override = overriddenDrinkAmounts
        info.amounts = portionDrinkAmounts.overriding(caffeineMg: override.caffeineMg, abv: override.abv)
        if !HydrationLogger.isSameVolume(info.amounts.volumeML, entry.volumeML) {
            info.sizeName = nil
        }
        info.hasMacros = hasMacros
        return info
    }

    private var showsPhotoCard: Bool {
        isEditing || !selectedPhotos.isEmpty
    }

    private var mappedLocation: EntryLocation? {
        guard let location = entry.location, location.hasCoordinate else { return nil }
        return location.withoutMapPin
    }

    private var canShowOnMap: Bool {
        showsMapLink && showsActionsAndLinks && linkedFood != nil && mappedLocation != nil
    }

    private var showsNotesCard: Bool {
        isEditing || !stickyNote.isEmpty || !pinnedNoteText.isEmpty
    }

    private var pinnedNoteUpdated: Date? {
        guard let note = linkedFood?.stickyNote else {
            return pinnedNoteText.isEmpty ? nil : .now
        }
        return pinnedNoteText == note.text ? note.lastUpdated : .now
    }

    private var shouldShowIngredientIcons: Bool {
        draftIngredients.contains { $0.icon != nil }
    }

    private var totalIngredientCalories: Double {
        draftIngredients.reduce(0) { $0 + $1.activeCalories }
    }
    private var totalIngredientProtein: Double {
        draftIngredients.reduce(0) { $0 + $1.activeProtein }
    }
    private var totalIngredientCarbs: Double {
        draftIngredients.reduce(0) { $0 + $1.activeCarbs }
    }
    private var totalIngredientFat: Double {
        draftIngredients.reduce(0) { $0 + $1.activeFat }
    }
    private var totalIngredientFiber: Double {
        draftIngredients.reduce(0) { $0 + $1.activeFiber }
    }

    private var activeServingWeight: Double? {
        guard isRecipe, baseServingWeight == nil else {
            return baseServingWeight
        }
        let totalWeight = draftIngredients.compactMap { $0.activeWeight }
            .reduce(0, +)
        return totalWeight > 0 ? totalWeight : nil
    }

    var availableUnits: [String] {
        var units: [String] = [baseUnit]
        if activeServingWeight != nil && baseServingWeightUnit != baseUnit {
            units.append(portionWeightUnit)
        }
        return units
    }

    private var measuresVolume: Bool {
        !isRecipe && baseServingWeightUnit == VolumeUnit.milliliters.rawValue
    }

    private var measuresDrinkVolume: Bool {
        entry.entryType == .drink && measuresVolume
    }

    private var showsFluidOunces: Bool {
        measuresVolume
            && (volumeUnit == .fluidOunces || portionUnitSelection == VolumeUnit.fluidOunces.rawValue)
    }

    private var portionWeightUnit: String {
        showsFluidOunces ? VolumeUnit.fluidOunces.rawValue : baseServingWeightUnit
    }

    private var portionVolumeUnit: VolumeUnit? {
        measuresVolume ? VolumeUnit(rawValue: portionUnitSelection) : nil
    }

    private var resolvedPortion: (quantity: Double, unit: String) {
        let quantity = Double(portionQuantity.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard let unit = portionVolumeUnit else {
            return (quantity, portionUnitSelection)
        }
        if let chosenVolumeML, portionQuantity == unit.editableText(fromML: chosenVolumeML) {
            return (chosenVolumeML, VolumeUnit.milliliters.rawValue)
        }
        return (unit.milliliters(from: quantity), VolumeUnit.milliliters.rawValue)
    }

    private func showPortionInDisplayUnit() {
        guard measuresVolume else { return }
        let value = Double(portionQuantity.replacingOccurrences(of: ",", with: ".")) ?? 0
        let milliliters: Double
        if portionUnitSelection == VolumeUnit.milliliters.rawValue {
            milliliters = value
        } else if measuresDrinkVolume, portionUnitSelection == baseUnit, let servingVolume = activeServingWeight,
            baseServingSize > 0
        {
            milliliters = value / baseServingSize * servingVolume
        } else {
            return
        }
        let unit: VolumeUnit = volumeUnit == .fluidOunces ? .fluidOunces : .milliliters
        let text = unit.editableText(fromML: milliliters)
        guard portionUnitSelection != unit.rawValue || text != portionQuantity else { return }
        skipsPortionRescale = true
        chosenVolumeML = milliliters
        portionUnitSelection = unit.rawValue
        portionQuantity = text
        DispatchQueue.main.async {
            skipsPortionRescale = false
        }
    }

    private var activeMultiplier: Double {
        let portion = resolvedPortion
        let currentPortion = portion.quantity
        let basePortion: Double
        if portion.unit == baseServingWeightUnit,
            let weight = activeServingWeight
        {
            basePortion = weight
        } else {
            basePortion = baseServingSize
        }
        return EntryHelper.calculateMultiplier(
            targetPortion: currentPortion,
            basePortion: basePortion
        )
    }

    private var displayServingSize: String {
        let size = activeMultiplier * baseServingSize
        return size.formatted(.number.precision(.fractionLength(0...2)))
    }

    private var displayServingWeight: String {
        guard let weight = activeServingWeight else { return "" }
        let scaledWeight = activeMultiplier * weight
        if baseServingWeightUnit == VolumeUnit.milliliters.rawValue { return EntryHelper.format(scaledWeight) }
        return scaledWeight.formatted(.number.precision(.fractionLength(0...2)))
    }

    private var sizeChips: [HydrationChip] {
        guard measuresDrinkVolume, portionVolumeUnit != nil, let food = linkedFood, food.type == .drink
        else { return [] }
        return HydrationLogger.menuSizes(for: food)
    }

    private var visibleRecentAmounts: [Double] {
        guard !sizeChips.isEmpty else { return [] }
        let sizes = sizeChips.map(\.volumeML)
        return recentDrinkAmounts.filter { volume in
            !sizes.contains { HydrationLogger.isSameVolume($0, volume) }
        }
    }

    private var hasNoDrinkAmount: Bool {
        measuresDrinkVolume && resolvedPortion.quantity <= 0
    }

    private func isSelectedVolume(_ milliliters: Double) -> Bool {
        let volume = resolvedPortion.quantity
        return volume > 0 && HydrationLogger.isSameVolume(volume, milliliters)
    }

    private func selectVolume(_ milliliters: Double) {
        guard let unit = portionVolumeUnit else { return }
        chosenVolumeML = milliliters
        portionQuantity = unit.editableText(fromML: milliliters)
    }

    private func sizeLabel(_ size: HydrationChip) -> String {
        let amount = volumeUnit.formattedAmount(size.volumeML)
        guard let name = size.sizeName, !name.isEmpty else { return amount }
        return "\(name) · \(amount)"
    }

    private func loadRecentDrinkAmounts() {
        guard measuresDrinkVolume, let food = linkedFood, food.type == .drink else { return }
        recentDrinkAmounts = HydrationLogger.recentAmounts(
            for: food,
            includesEntries: true,
            excluding: entry,
            in: modelContext
        )
    }

    private var drinkAmountChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(sizeChips) { size in
                    Button(sizeLabel(size)) {
                        selectVolume(size.volumeML)
                    }
                    .buttonStyle(.filterChip(isSelected: isSelectedVolume(size.volumeML)))
                }

                ForEach(visibleRecentAmounts, id: \.self) { volume in
                    Button {
                        selectVolume(volume)
                    } label: {
                        Label(volumeUnit.formattedAmount(volume), systemImage: "clock.arrow.circlepath")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.filterChip(isSelected: isSelectedVolume(volume)))
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
        .chipScrollFade()
    }

    @ViewBuilder
    private var portionCard: some View {
        if measuresDrinkVolume {
            Card {
                VStack(spacing: 0) {
                    portionRow

                    if isEditing && !sizeChips.isEmpty {
                        drinkAmountChips
                            .padding(.bottom, 12)
                    }
                }
            }
        } else {
            Card {
                portionRow
                    .hidden()
                    .disabled(true)
            }
            .overlay(alignment: .top) {
                portionRow
            }
        }
    }

    private var portionRow: some View {
        PortionPillRow(
            title: measuresDrinkVolume ? "Amount" : "Portion",
            isEnabled: isEditing,
            showsUnitPicker: !measuresDrinkVolume,
            quantity: $portionQuantity,
            unit: $portionUnitSelection,
            availableUnits: availableUnits,
            servingUnits: portionUnitOptions
        )
    }

    private var isAvailable: Bool {
        !entry.isDeleted && entry.modelContext != nil
    }

    var body: some View {
        if isAvailable {
            content
        } else {
            Color.background
                .ignoresSafeArea()
                .onAppear {
                    guard !isDismissing else { return }
                    isDismissing = true
                    dismiss()
                }
        }
    }

    private var content: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            ScrollView {
                VStack {
                    Card {
                        RowGroup(.divider) {
                            TextInputRow(
                                title: "Name",
                                placeholder: "-",
                                text: $name,
                                isEnabled: isEditing,
                                maxWidth: nil
                            )
                            .padding(.trailing, 10)

                            DropdownPillRow(
                                title: "Source",
                                options: [""]
                                    + sourceOptions.visibleNames(
                                        keeping: sourceSelection
                                    ),
                                isEnabled: isEditing,
                                selection: $sourceSelection
                            )

                            if entry.entryType == .food || entry.entryType == .drink || isRecipe {
                                DropdownPillRow(
                                    title: "Category",
                                    options: [""]
                                        + categoryOptions.visibleNames(
                                            keeping: categorySelection
                                        ),
                                    isEnabled: isEditing,
                                    selection: $categorySelection
                                )
                            } else {
                                DropdownPillRow(
                                    title: "Food Group",
                                    options: [""]
                                        + foodGroupOptions.visibleNames(
                                            keeping: foodGroupSelection
                                        ),
                                    isEnabled: isEditing,
                                    selection: $foodGroupSelection
                                )
                            }

                            DateTimePillRow(
                                title: "Date & Time",
                                isEnabled: isEditing,
                                dateSelection: $date,
                                timeSelection: $time
                            )

                            LocationRow(
                                selection: $locationSelection,
                                food: linkedFood,
                                photos: selectedPhotos,
                                logDate: date,
                                isEnabled: isEditing,
                                promptsForPermission: false,
                                onShowOnMap: canShowOnMap ? { showingMap = true } : nil
                            )
                        }
                    }
                    .padding(.horizontal)

                    if showsNotesCard {
                        NotesCard(
                            pinnedNote: $pinnedNoteText,
                            logNote: $stickyNote,
                            pinnedUpdated: pinnedNoteUpdated,
                            allowsPinning: linkedFood != nil,
                            isEditable: isEditing,
                            onViewAll: linkedFood == nil || !showsActionsAndLinks || isEditing
                                ? nil : { showingAllNotes = true }
                        )
                        .padding([.top, .horizontal])
                    }

                    if showsPhotoCard {
                        PhotoPickerCard(
                            images: $selectedPhotos,
                            isLoading: $isLoadingPhotos,
                            isEditing: isEditing,
                            onViewAll: hasPhotoHistory && showsActionsAndLinks && !isEditing
                                ? { showingAllPhotos = true } : nil,
                            onUseTime: usePhotoTime,
                            onUseLocation: usePhotoLocation,
                            entryDate: date,
                            entryTime: time,
                            entryLocation: locationSelection.resolvedLocation
                        )
                    }

                    portionCard
                        .padding(.horizontal)
                    .padding(.top, showsPhotoCard ? 0 : nil)

                    if isRecipe && (isEditing || !draftIngredients.isEmpty) {
                        Card("Ingredients") {
                            ReorderableRows(items: $draftIngredients, isEnabled: isEditing) { $draft in
                                IngredientRowView(
                                    draft: $draft,
                                    portionUnitOptions: portionUnitOptions,
                                    shouldShowIngredientIcons:
                                        shouldShowIngredientIcons,
                                    isEnabled: isEditing,
                                    onDelete: {
                                        draftIngredients.removeAll {
                                            $0.id == draft.id
                                        }
                                    }
                                )
                            }

                            if isEditing {
                                ButtonRow(
                                    icon: .customSymbol("plus.circle.fill"),
                                    title: "Add Ingredient"
                                ) {
                                    showIngredientSelectionSheet = true
                                }
                            }
                        }
                        .padding([.top, .horizontal])
                    }

                    Card {
                        RowGroup(.divider) {
                            TextInputRow(
                                icon: .calorie,
                                title: "Calories",
                                titleExtension: "(kcal)",
                                text: $calorie,
                                keyboardType: .decimalPad,
                                isEnabled: isEditing && manualOverrideToggle
                            )
                            TextInputRow(
                                icon: .protein,
                                title: "Protein",
                                titleExtension: "(g)",
                                text: $protein,
                                keyboardType: .decimalPad,
                                isEnabled: isEditing && manualOverrideToggle
                            )
                            TextInputRow(
                                icon: .carbs,
                                title: "Carbohydrates",
                                titleExtension: "(g)",
                                text: $carbs,
                                keyboardType: .decimalPad,
                                isEnabled: isEditing && manualOverrideToggle
                            )
                            TextInputRow(
                                icon: .fat,
                                title: "Fat",
                                titleExtension: "(g)",
                                text: $fat,
                                keyboardType: .decimalPad,
                                isEnabled: isEditing && manualOverrideToggle
                            )
                            TextInputRow(
                                icon: .fiber,
                                title: "Fiber",
                                titleExtension: "(g)",
                                text: $fiber,
                                keyboardType: .decimalPad,
                                isEnabled: isEditing && manualOverrideToggle
                            )

                            if showsCaffeineRow {
                                TextInputRow(
                                    icon: .caffeine,
                                    title: "Caffeine",
                                    titleExtension: "(mg)",
                                    text: caffeineField,
                                    keyboardType: .decimalPad,
                                    isEnabled: isEditing && manualOverrideToggle
                                )
                            }

                            if showsAlcoholRow {
                                TextInputRow(
                                    icon: .alcohol,
                                    title: "Alcohol",
                                    titleExtension: "(% ABV)",
                                    text: abvField,
                                    keyboardType: .decimalPad,
                                    isEnabled: isEditing && manualOverrideToggle
                                )
                            }

                            if isEditing || manualOverrideToggle {
                                ToggleRow(
                                    title: "Manual Override",
                                    isOn: $manualOverrideToggle
                                )
                                .disabled(!isEditing)
                            }
                        }
                    }
                    .padding([.top, .horizontal])
                }
            }
            .tabBarScrollInsets(ignoring: .container)
            .safeAreaBar(edge: .top) {
                Card {
                    MealRow(
                        name: name.isEmpty ? "Unnamed Entry" : name,
                        source: sourceSelection,
                        isCustomDefaultServing: false,
                        customServingSize: "",
                        servingSize: displayServingSize,
                        servingSizeUnit: baseUnit,
                        servingWeight: displayServingWeight,
                        servingWeightUnit: baseServingWeightUnit,
                        servingUnits: portionUnitOptions,
                        calorie: calorie,
                        protein: protein,
                        carbs: carbs,
                        fat: fat,
                        fiber: fiber
                    )
                    .nameLineLimit(3)
                    .drink(drinkHeaderInfo)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .withCustomKeyboardToolbar()
        }
        .environment(focusManager)
        .sheet(isPresented: $showIngredientSelectionSheet) {
            IngredientSelectionView(
                inRecipeIDs: Set(draftIngredients.compactMap(\.ingredientItem?.id)),
                excludedRecipe: linkedFood
            ) { selectedItems in
                draftIngredients.append(
                    contentsOf: selectedItems.map { LogRecipeIngredient(item: $0) }
                )
            }
        }
        .navigationDestination(isPresented: $showingAllNotes) {
            if let food = linkedFood {
                NotesHistoryView(
                    food: food,
                    currentEntryID: entry.id,
                    isPushedView: true
                )
            }
        }
        .navigationDestination(isPresented: $showingMap) {
            if let food = linkedFood, let place = mappedLocation {
                FoodLocationsMapView(food: food, initialPlace: place)
            }
        }
        .navigationDestination(isPresented: $showingAllPhotos) {
            if let food = linkedFood {
                PhotoHistoryView(
                    food: food,
                    currentEntryID: entry.id,
                    isPushedView: true
                )
            }
        }
        .task(id: linkedFood?.id) {
            guard let food = linkedFood else {
                hasPhotoHistory = false
                return
            }
            hasPhotoHistory = FoodItemStore.hasPhotoHistory(
                for: food,
                excluding: entry.id,
                in: modelContext
            )
        }
        .sheet(item: $foodToLogAgain, onDismiss: {
            guard popAfterLogAgain else { return }
            popAfterLogAgain = false
            dismiss()
        }) { foodToLog in
            Group {
                if foodToLog.type == .recipe {
                    LogRecipeView(
                        recipe: foodToLog,
                        previousEntry: entry
                    )
                    .environment(\.rootDismiss) { finishLogAgain() }
                } else {
                    LogEntryView(
                        food: foodToLog,
                        previousEntry: entry
                    )
                    .environment(\.rootDismiss) { finishLogAgain() }
                }
            }
        }
        .sheet(isPresented: $showAddToLibrary) {
            if entry.libraryEntryType == .recipe {
                AddRecipeView(
                    offersLogNow: true,
                    prefill: entry.addRecipePrefill,
                    onCreate: linkToLibrary
                )
            } else {
                AddEntryView(
                    entryType: entry.libraryEntryType,
                    offersLogNow: true,
                    prefill: entry.addEntryPrefill,
                    onCreate: linkToLibrary
                )
            }
        }
        .sheet(item: $foodToView) { food in
            NavigationStack {
                FoodDetailView(food: food, isPushedView: false)
            }
            .environment(\.tabBarHeight, 0)
        }
        .navigationTitle(
            entry.entryType.map {
                String(localized: "Logged \($0.rawValue.capitalized)")
            } ?? String(localized: "Logged Entry")
        )
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isEditing)
        .toolbar {
            if !isEditing && allowsEditing {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit Entry", systemImage: "pencil") {
                        withAnimation {
                            isEditing = true
                        }
                    }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                if isEditing {
                    Button {
                        UIApplication.shared.dismissKeyboard()
                        attemptSave()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel("Save Changes")
                    .fontWeight(.semibold)
                    .disabled(isLoadingPhotos || hasNoDrinkAmount)
                    .savePromptPopover(
                        $savePrompt,
                        dismissesScreen: dismissesAfterEditing && !isPushedView
                    )
                } else if showsActionsAndLinks {
                    Menu {
                        if let originalFood = linkedFood {
                            if EntryActions.canLogAgain(entry, tracksHydration: tracksHydration) {
                                Button {
                                    if EntryActions.opensAsHydrationLog(entry, tracksHydration: tracksHydration) {
                                        EntryActions.logHydrationAgain(
                                            entry,
                                            dayStartMinutes: users.first?.dayStartMinutes ?? 0,
                                            unit: volumeUnit,
                                            in: modelContext,
                                            toastCenter: toastCenter
                                        )
                                    } else {
                                        foodToLogAgain = originalFood
                                    }
                                } label: {
                                    Label(
                                        "Log Again",
                                        systemImage: "plus.square.on.square"
                                    )
                                }
                            }

                            if showsLibraryLink {
                                Button {
                                    foodToView = originalFood
                                } label: {
                                    Label(originalFood.viewActionTitle, systemImage: "book.pages")
                                }
                            }
                        } else {
                            Button {
                                showAddToLibrary = true
                            } label: {
                                Label(
                                    "Add to Library",
                                    systemImage: "plus.square.dashed"
                                )
                            }
                        }

                        Divider()

                        Button(role: .destructive) {
                            deleteEntry()
                        } label: {
                            Label("Delete Entry", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Entry Options")
                }
            }

            ToolbarItem(placement: .topBarLeading) {
                if isEditing {
                    Button {
                        UIApplication.shared.dismissKeyboard()
                        if dismissesAfterEditing {
                            dismiss()
                            return
                        }
                        withAnimation {
                            discardChanges()
                            isEditing = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Discard Changes")
                } else if !isPushedView {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
        .interactiveDismissDisabled(isEditing)
        .onChange(of: linkedFood?.stickyNote?.text) { _, text in
            guard pinnedNoteText == originalPinnedNote else { return }
            pinnedNoteText = text ?? ""
            originalPinnedNote = pinnedNoteText
        }
        .onAppear {
            showPortionInDisplayUnit()
            loadRecentDrinkAmounts()
        }
        .onChange(of: portionUnitSelection) { oldUnit, newUnit in
            guard oldUnit != newUnit, !skipsPortionRescale, let servingWeight = activeServingWeight else {
                return
            }
            chosenVolumeML = nil
            let currentQuantity = Double(portionQuantity) ?? 0
            let weightUnit = portionWeightUnit
            let weight =
                weightUnit == VolumeUnit.fluidOunces.rawValue
                ? VolumeUnit.fluidOunces.value(fromML: servingWeight) : servingWeight

            if oldUnit == baseUnit && newUnit == weightUnit {
                let newQuantity = (currentQuantity / baseServingSize) * weight
                portionQuantity = EntryHelper.format(newQuantity)
            } else if oldUnit == weightUnit && newUnit == baseUnit {
                let newQuantity = (currentQuantity / weight) * baseServingSize
                portionQuantity = EntryHelper.format(newQuantity)
            }
        }
        .onChange(of: portionQuantity) { _, text in
            if let chosenVolumeML, text != portionVolumeUnit?.editableText(fromML: chosenVolumeML) {
                self.chosenVolumeML = nil
            }
            if !manualOverrideToggle && !skipsPortionRescale { updateMacrosFromMultiplier() }
        }
        .onChange(of: draftIngredients) { _, _ in
            // Skipped outside edit mode so discarding keeps the logged macros
            if isEditing && !manualOverrideToggle {
                updateMacrosFromMultiplier()
            }
        }
        .onChange(of: manualOverrideToggle) { _, isManual in
            if isManual {
                if !entry.isManualOverride {
                    caffeine = computedCaffeineText
                    abv = computedABVText
                }
                calorie = calorieDynamic
                protein = proteinDynamic
                carbs = carbsDynamic
                fat = fatDynamic
                fiber = fiberDynamic
            } else {
                updateMacrosFromMultiplier()
            }
        }
        .onChange(of: calorie) {
            if manualOverrideToggle { calorieDynamic = calorie }
        }
        .onChange(of: protein) {
            if manualOverrideToggle { proteinDynamic = protein }
        }
        .onChange(of: carbs) {
            if manualOverrideToggle { carbsDynamic = carbs }
        }
        .onChange(of: fat) { if manualOverrideToggle { fatDynamic = fat } }
        .onChange(of: fiber) {
            if manualOverrideToggle { fiberDynamic = fiber }
        }
    }

    private func usePhotoTime(_ capturedAt: Date) {
        withAnimation(.snappy(duration: 0.3)) {
            date = capturedAt
            time = capturedAt
        }
    }

    private func usePhotoLocation(_ location: EntryLocation) {
        withAnimation(.snappy(duration: 0.3)) {
            locationSelection = .place(location)
        }
    }

    private func updateMacrosFromMultiplier() {
        if isRecipe {
            // Recipes derive their macros from the logged ingredients rather
            // than the (possibly since-edited) recipe item
            calorie = EntryHelper.formatMacroField(totalIngredientCalories * activeMultiplier)
            protein = EntryHelper.formatMacroField(totalIngredientProtein * activeMultiplier)
            carbs = EntryHelper.formatMacroField(totalIngredientCarbs * activeMultiplier)
            fat = EntryHelper.formatMacroField(totalIngredientFat * activeMultiplier)
            fiber = EntryHelper.formatMacroField(totalIngredientFiber * activeMultiplier)
        } else {
            calorie = EntryHelper.scale(calorieStatic, by: activeMultiplier)
            protein = EntryHelper.scale(proteinStatic, by: activeMultiplier)
            carbs = EntryHelper.scale(carbsStatic, by: activeMultiplier)
            fat = EntryHelper.scale(fatStatic, by: activeMultiplier)
            fiber = EntryHelper.scale(fiberStatic, by: activeMultiplier)
        }

        calorieDynamic = calorie
        proteinDynamic = protein
        carbsDynamic = carbs
        fatDynamic = fat
        fiberDynamic = fiber
    }

    private func attemptSave() {
        let macrosChanged =
            [calorie, protein, carbs, fat]
            != [entry.calories, entry.protein, entry.carbs, entry.fat].map {
                EntryHelper.format($0)
            }
        let issue =
            macrosChanged
            ? MacroSanityCheck.issue(
                for: MacroSanityCheck.Values(
                    calories: calorie,
                    protein: protein,
                    carbs: carbs,
                    fat: fat,
                    fiber: fiber,
                    weight: activeServingWeight.map { $0 * activeMultiplier },
                    weightUnit: baseServingWeightUnit
                ),
                scope: manualOverrideToggle ? .full : .sizeOnly
            ) : nil
        if let issue {
            savePrompt = .macroCheck(issue, confirmTitle: "Save Anyway", onConfirm: commitChanges)
        } else {
            commitChanges()
        }
    }

    private func commitChanges() {
        if dismissesAfterEditing {
            if saveChanges() {
                if let onSaveDismiss {
                    onSaveDismiss()
                } else {
                    dismiss()
                }
            }
            return
        }
        withAnimation {
            if saveChanges() {
                isEditing = false
            }
        }
    }

    private func saveChanges() -> Bool {
        if let pendingDrink {
            entry.originalFoodItem = pendingDrink
            entry.typeRawValue = pendingDrink.type.rawValue
        }
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents(
            [.year, .month, .day],
            from: date
        )
        let timeComponents = calendar.dateComponents(
            [.hour, .minute, .second],
            from: time
        )

        var combinedComponents = DateComponents()
        combinedComponents.year = dateComponents.year
        combinedComponents.month = dateComponents.month
        combinedComponents.day = dateComponents.day
        combinedComponents.hour = timeComponents.hour
        combinedComponents.minute = timeComponents.minute
        combinedComponents.second = timeComponents.second

        entry.timestamp = calendar.date(from: combinedComponents) ?? Date()

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.name = trimmedName.isEmpty ? entry.name : trimmedName

        let trimmedNote = stickyNote.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        entry.logNote = trimmedNote.isEmpty ? nil : trimmedNote

        if let food = linkedFood, pinnedNoteText != originalPinnedNote {
            let trimmedPinned = pinnedNoteText.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            EntryHelper.applyPinnedNote(
                trimmedPinned.isEmpty ? nil : trimmedPinned,
                to: food,
                in: modelContext
            )
        }
        let previousLocation = entry.location
        let newLocation = locationSelection.resolvedLocation
        let awaitsCurrent = locationSelection.isCurrent && newLocation == nil
        if !awaitsCurrent, newLocation != entry.location {
            RecentLocationStore.record(newLocation, in: modelContext)
            entry.setLocation(newLocation, in: modelContext)
            for child in entry.childEntries ?? [] {
                child.setLocation(newLocation, in: modelContext)
            }
        }

        let trimmedSource = sourceSelection.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if !trimmedSource.isEmpty && trimmedSource != "-" {
            if let existing = sourceOptions.first(where: {
                $0.source == trimmedSource
            }) {
                entry.source = existing
            } else {
                let nextOrder =
                    (sourceOptions.map { $0.displayOrder }.max() ?? 0) + 1
                let newSource = EntrySource(
                    source: trimmedSource,
                    displayOrder: nextOrder
                )
                modelContext.insert(newSource)
                entry.source = newSource
            }
        } else {
            entry.source = nil
        }

        let trimmedCategory = categorySelection.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if !trimmedCategory.isEmpty && trimmedCategory != "-" {
            if let existing = categoryOptions.first(where: {
                $0.category == trimmedCategory
            }) {
                entry.category = existing
            } else {
                let nextOrder =
                    (categoryOptions.map { $0.displayOrder }.max() ?? 0) + 1
                let newCategory = CategorySource(
                    category: trimmedCategory,
                    displayOrder: nextOrder
                )
                modelContext.insert(newCategory)
                entry.category = newCategory
            }
        } else {
            entry.category = nil
        }

        let trimmedGroup = foodGroupSelection.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if !trimmedGroup.isEmpty && trimmedGroup != "-" {
            if let existing = foodGroupOptions.first(where: {
                $0.foodGroup == trimmedGroup
            }) {
                entry.foodGroup = existing
            } else {
                let nextOrder =
                    (foodGroupOptions.map { $0.displayOrder }.max() ?? 0) + 1
                let newGroup = FoodGroupSource(
                    foodGroup: trimmedGroup,
                    displayOrder: nextOrder
                )
                modelContext.insert(newGroup)
                entry.foodGroup = newGroup
            }
        } else {
            entry.foodGroup = nil
        }

        let portion = resolvedPortion
        entry.loggedQuantity = portion.quantity
        entry.loggedUnit = portion.unit
        entry.isManualOverride = manualOverrideToggle
        if !isRecipe {
            let override = overriddenDrinkAmounts
            let clearsOverride = clearsDrinkOverride
            let clearedAmounts = portionDrinkAmounts
            entry.updateDrinkAmounts(from: drinkSnapshot)
            if clearsOverride {
                entry.caffeineMg = clearedAmounts.caffeineMg
                entry.alcoholGrams = clearedAmounts.alcoholGrams
            }
            entry.drinkAmounts = entry.drinkAmounts.overriding(caffeineMg: override.caffeineMg, abv: override.abv)
        }

        entry.calories =
            Double(calorie.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        entry.protein =
            Double(protein.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        entry.carbs =
            Double(carbs.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        entry.fat = Double(fat.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        entry.fiber =
            Double(fiber.replacingOccurrences(of: ",", with: ".")) ?? 0.0

        let removesPhotos = (entry.photos ?? []).contains { photo in
            !selectedPhotos.contains { $0.sourcePhoto === photo }
        }
        entry.photos = EntryHelper.applyPhotos(
            selectedPhotos,
            replacing: entry.photos,
            in: modelContext
        )
        EntryHelper.linkPhotos(&selectedPhotos, to: entry.photos)

        let changesLocation = awaitsCurrent || entry.location != previousLocation
        let hasDetails = entry.logNote != nil || changesLocation || !(entry.photos ?? []).isEmpty
        if tracksHydration || hasDetails {
            entry.isHydrationLog = false
        }

        if isRecipe {
            var oldSnapshots = (entry.childEntries ?? [])
                .sorted { $0.displayOrder < $1.displayOrder }
                .map { DrinkSnapshot($0) }
            if let oldChildren = entry.childEntries {
                for child in oldChildren {
                    modelContext.delete(child)
                }
            }

            // Child entries store the amounts actually eaten, so scale the
            // per-recipe drafts by the current portion
            let multiplier = activeMultiplier
            entry.childEntries = draftIngredients.enumerated().map {
                index, draft in
                LoggedEntry(
                    name: draft.name,
                    typeRawValue: EntryType.ingredient.rawValue,
                    originalFoodItem: draft.ingredientItem,
                    timestamp: entry.timestamp,
                    location: entry.location,
                    savedLocation: entry.savedLocation,
                    loggedQuantity:
                        (Double(
                            draft.quantity.replacingOccurrences(
                                of: ",",
                                with: "."
                            )
                        ) ?? 0.0) * multiplier,
                    loggedUnit: draft.unit,
                    calories: draft.activeCalories * multiplier,
                    protein: draft.activeProtein * multiplier,
                    carbs: draft.activeCarbs * multiplier,
                    fat: draft.activeFat * multiplier,
                    fiber: draft.activeFiber * multiplier,
                    displayOrder: index
                )
            }
            let children = entry.childEntries ?? []
            for child in children {
                let foodID = child.originalFoodItem?.id
                if let index = oldSnapshots.firstIndex(where: { foodID != nil && $0.foodID == foodID }) {
                    child.updateDrinkAmounts(from: oldSnapshots.remove(at: index))
                } else {
                    child.snapshotDrinkAmounts(children: [])
                }
            }
            entry.drinkAmounts = children.reduce(.zero) { $0 + $1.drinkAmounts }
            entry.sizeName = nil
        }

        do {
            try modelContext.save()
            QuickLogger.finishLocation(
                of: entry,
                awaitingCurrent: awaitsCurrent,
                replacing: entry.storedLocation,
                in: modelContext
            )
            originalPinnedNote = pinnedNoteText
            if removesPhotos { onRemovePhotos?() }
            return true
        } catch {
            toastCenter?.show(
                .failure(String(localized: "Couldn't Save Changes"), message: name)
            )
            modelContext.rollback()
            savePrompt = nil
            return false
        }
    }

    private func deleteEntry() {
        isDismissing = true
        let snapshot: MacroBackup.LogRecord?
        do {
            snapshot = try withAnimation {
                try EntryDeleter.delete(entry, in: modelContext)
            }
        } catch {
            isDismissing = false
            toastCenter?.show(
                .failure(String(localized: "Couldn't Delete Entry"), message: entry.name)
            )
            return
        }
        guard let snapshot else {
            isDismissing = false
            return
        }
        dismiss()
        toastCenter?.show(.entryDeleted(snapshot, in: modelContext, presenter: toastCenter))
    }

    private func finishLogAgain() {
        if isPushedView {
            popAfterLogAgain = true
            foodToLogAgain = nil
        } else {
            dismiss()
        }
    }

    private func linkToLibrary(_ food: FoodItem) {
        entry.originalFoodItem = food
        guard save(failureTitle: String(localized: "Couldn't Link to Library")) else { return }
        pinnedNoteText = food.stickyNote?.text ?? ""
        originalPinnedNote = pinnedNoteText
    }

    private func save(failureTitle: String) -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            savePrompt = nil
            toastCenter?.show(.failure(failureTitle))
            return false
        }
    }

    private func discardChanges() {
        name = entry.name
        sourceSelection = entry.source?.source ?? ""
        categorySelection = entry.category?.category ?? ""
        foodGroupSelection = entry.foodGroup?.foodGroup ?? ""

        date = entry.timestamp
        time = entry.timestamp
        locationSelection = LocationSelection(entry.location)

        portionQuantity = EntryHelper.format(entry.loggedQuantity)
        portionUnitSelection = entry.loggedUnit
        showPortionInDisplayUnit()

        manualOverrideToggle = entry.isManualOverride
        caffeine = Self.caffeineText(for: entry)
        abv = Self.abvText(for: entry)

        calorie = EntryHelper.formatLoggedMacro(entry.calories, of: entry, food: entry.originalFoodItem)
        protein = EntryHelper.formatLoggedMacro(entry.protein, of: entry, food: entry.originalFoodItem)
        carbs = EntryHelper.formatLoggedMacro(entry.carbs, of: entry, food: entry.originalFoodItem)
        fat = EntryHelper.formatLoggedMacro(entry.fat, of: entry, food: entry.originalFoodItem)
        fiber = EntryHelper.formatLoggedMacro(entry.fiber, of: entry, food: entry.originalFoodItem)

        stickyNote = entry.logNote ?? ""
        pinnedNoteText = linkedFood?.stickyNote?.text ?? ""
        originalPinnedNote = pinnedNoteText

        selectedPhotos = EntryHelper.loggedPhotos(from: entry.photos)
        isLoadingPhotos = false

        draftIngredients = LogRecipeIngredient.makeDrafts(for: entry)
    }
}

#Preview {
    { () -> AnyView in

        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try! ModelContainer(
            for: LoggedEntry.self,
            FoodItem.self,
            EntrySource.self,
            CategorySource.self,
            FoodGroupSource.self,
            ServingSizeUnit.self,
            configurations: config
        )

        let mockSource = EntrySource(
            source: "Favorite Recipes",
            displayOrder: 1
        )
        let mockCategory = CategorySource(
            category: "Breakfast",
            displayOrder: 1
        )

        let servingUnit = ServingSizeUnit(
            unit: "serving",
            pluralVariant: "servings",
            isDefault: true,
            displayOrder: 1
        )
        let gramUnit = ServingSizeUnit(
            unit: "g",
            pluralVariant: "g",
            isDefault: false,
            displayOrder: 2
        )

        let mockFood = FoodItem(
            name: "Oatmeal",
            type: .food,
            source: mockSource,
            category: mockCategory,
            foodGroup: nil,
            servingSize: 1.0,
            servingUnit: servingUnit,
            servingWeight: 45.0,
            servingWeightUnit: "g",
            isAIEstimated: false,
            calories: 150.0,
            protein: 5.0,
            carbs: 27.0,
            fat: 2.5,
            fiber: 4.0,
            isCustomDefaultServing: false,
            customServingSize: nil,
            stickyNote: Note(text: "Great for pre-workout")
        )

        let mockLog = LoggedEntry(
            name: mockFood.name,
            typeRawValue: mockFood.type.rawValue,
            originalFoodItem: mockFood,
            source: mockSource,
            category: mockCategory,
            foodGroup: nil,
            timestamp: Date(),
            location: EntryLocation(name: "Home Kitchen"),
            loggedQuantity: 1.5,
            loggedUnit: "serving",
            calories: 225.0,
            protein: 7.5,
            carbs: 40.5,
            fat: 3.75,
            fiber: 6.0,
            isManualOverride: false,
            logNote: "Added extra blueberries this time"
        )

        container.mainContext.insert(mockSource)
        container.mainContext.insert(mockCategory)
        container.mainContext.insert(servingUnit)
        container.mainContext.insert(gramUnit)
        container.mainContext.insert(mockFood)
        container.mainContext.insert(mockLog)

        return AnyView(
            NavigationStack {
                LoggedEntryDetailView(entry: mockLog, isPushedView: false)
            }
            .modelContainer(container)
        )

    }()
}
