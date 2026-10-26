//
//  LogEntryView.swift
//  Macro
//
//  Created by Priyanka Sangha on 2026-05-10.
//

import PhotosUI
import SwiftData
import SwiftUI

struct LogEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.rootDismiss) var rootDismiss
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.toastCenter) private var toastCenter

    @Query(sort: \EntrySource.displayOrder) var sourceOptions: [EntrySource]
    @Query(sort: \CategorySource.displayOrder) var categoryOptions:
        [CategorySource]
    @Query(sort: \FoodGroupSource.displayOrder) var foodGroupOptions:
        [FoodGroupSource]
    @Query(sort: \ServingSizeUnit.displayOrder) var portionUnitOptions:
        [ServingSizeUnit]
    @Query private var users: [User]

    let food: FoodItem
    @State private var name: String
    var isPushedView: Bool = false

    private let isCustomDefaultServing: Bool
    private let isAddingDetails: Bool
    private let customServingSize: String
    private let servingWeight: String
    private let servingWeightUnit: String

    @State private var sourceSelection: String
    @State private var categorySelection: String
    @State private var foodGroupSelection: String

    @State private var date = Date()
    @State private var time = Date()
    @State private var locationSelection: LocationSelection
    private let initialLocationSelection: LocationSelection

    @State private var portionQuantity: String
    @State private var portionUnitSelection: String

    @State private var originalPortionQuantity: String
    @State private var originalPortionUnitSelection: String
    @State private var originalVolumeML: Double?

    private let calorieStatic: String
    private let proteinStatic: String
    private let carbsStatic: String
    private let fatStatic: String
    private let fiberStatic: String
    private let previousMacros: MacroSanityCheck.Values?

    @State private var calorieDynamic: String
    @State private var proteinDynamic: String
    @State private var carbsDynamic: String
    @State private var fatDynamic: String
    @State private var fiberDynamic: String

    @State private var calorie: String
    @State private var protein: String
    @State private var carbs: String
    @State private var fat: String
    @State private var fiber: String

    @State private var manualOverrideToggle: Bool
    @State private var caffeine: String
    @State private var abv: String

    @State private var stickyNote: String
    @State private var pinnedNoteBase: String

    @State private var newNote: String

    @State private var showingAllNotes: Bool = false
    @State private var showingAllPhotos: Bool = false
    @State private var hasPhotoHistory: Bool = false

    @State private var selectedPhotos: [LoggedPhoto]
    @State private var isLoadingPhotos = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var pendingCameraCapture: CameraCapture?
    @State private var isPhotoCoverShown = false

    @State private var dateAdded: Date

    @State private var saveOption: LogSaveOption = .logOnly

    @State private var isResettingPortion = false
    @State private var skipsPortionRescale = false
    @State private var chosenVolumeML: Double?
    @State private var recentDrinkAmounts: [Double] = []
    @State private var isSavingSize = false
    @State private var newSizeName = ""
    @State private var pendingSizes: [PendingDrinkSize] = []

    @State private var draftID: UUID
    private let isResumedDraft: Bool
    @State private var didFinishLogging = false
    @State private var savePrompt: SavePromptStep?

    @State private var initialDraftState: LogEntryDraftState?
    @State private var initialPhotoData: [Data] = []
    @State private var initialLocation: LocationSelection?

    var isEdited: Bool {
        sourceSelection != (food.source?.source ?? "")
            || categorySelection != (food.category?.category ?? "")
            || foodGroupSelection != (food.foodGroup?.foodGroup ?? "")
            || manualOverrideToggle
    }

    private var hasChangedFromOriginal: Bool {
        isEdited
            || name != food.name
            || portionQuantity != originalPortionQuantity
            || portionUnitSelection != originalPortionUnitSelection
            || stickyNote != pinnedNoteBase
            || !newNote.isEmpty
            || !selectedPhotos.isEmpty
            || !pendingSizes.isEmpty
    }

    private var resolvedPinnedNote: String? {
        let trimmed = stickyNote.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var hasPinnedNoteChanged: Bool {
        stickyNote != pinnedNoteBase && resolvedPinnedNote != food.stickyNote?.text
    }

    private var pinnedNoteUpdated: Date? {
        stickyNote == pinnedNoteBase ? food.stickyNote?.lastUpdated : .now
    }

    var mappedSourceOptions: [String] {
        sourceOptions.map { $0.source }
    }

    var mappedCategoryOptions: [String] {
        categoryOptions.map { $0.category }
    }

    var mappedUnitOptions: [String] {
        portionUnitOptions.map { $0.unit }
    }

    var availableUnits: [String] {
        var units: [String] = []
        let baseUnit = food.servingUnit?.unit ?? "serving"

        units.append(baseUnit)

        if food.servingWeight != nil && food.servingWeightUnit != baseUnit {
            units.append(portionWeightUnit)
        }

        return units
    }

    private var showsFluidOunces: Bool {
        food.servingWeightUnit == VolumeUnit.milliliters.rawValue
            && (volumeUnit == .fluidOunces || portionUnitSelection == VolumeUnit.fluidOunces.rawValue)
    }

    private var portionWeightUnit: String {
        showsFluidOunces ? VolumeUnit.fluidOunces.rawValue : food.servingWeightUnit
    }

    private var portionVolumeUnit: VolumeUnit? {
        guard food.servingWeightUnit == VolumeUnit.milliliters.rawValue else { return nil }
        return VolumeUnit(rawValue: portionUnitSelection)
    }

    private var resolvedPortion: (quantity: Double, unit: String) {
        let quantity = parseDouble(portionQuantity)
        guard let unit = portionVolumeUnit else {
            return (quantity, portionUnitSelection)
        }
        if let chosenVolumeML, portionQuantity == unit.editableText(fromML: chosenVolumeML) {
            return (chosenVolumeML, VolumeUnit.milliliters.rawValue)
        }
        return (unit.milliliters(from: quantity), VolumeUnit.milliliters.rawValue)
    }

    private var activeMultiplier: Double {
        let portion = resolvedPortion
        return EntryHelper.portionMultiplier(
            quantity: portion.quantity,
            unit: portion.unit,
            servingSize: food.servingSize,
            servingWeight: food.servingWeight,
            servingWeightUnit: food.servingWeightUnit
        ) ?? 0
    }

    private var isDrink: Bool {
        food.type == .drink
    }

    private var volumeUnit: VolumeUnit {
        users.first?.volumeUnit ?? .localeDefault
    }

    private var showsMacroRows: Bool {
        !isDrink || food.hasNutrition || manualOverrideToggle
    }

    private var showsCaffeineRow: Bool {
        isDrink && food.caffeineMg != nil
    }

    private var showsAlcoholRow: Bool {
        isDrink && food.abv != nil
    }

    private var showsMacros: Bool {
        showsMacroRows || showsCaffeineRow || showsAlcoholRow
    }

    private var foodDrinkAmounts: DrinkAmounts {
        let portion = resolvedPortion
        return DrinkAmounts(food: food, quantity: portion.quantity, unit: portion.unit)
    }

    private var drinkAmounts: DrinkAmounts {
        guard manualOverrideToggle else { return foodDrinkAmounts }
        return foodDrinkAmounts.overriding(
            caffeineMg: showsCaffeineRow ? parseDouble(caffeine) : nil,
            abv: showsAlcoholRow ? parseDouble(abv) : nil
        )
    }

    private var computedCaffeineText: String {
        EntryHelper.format(foodDrinkAmounts.caffeineMg.rounded())
    }

    private var caffeineText: Binding<String> {
        Binding(
            get: { manualOverrideToggle ? caffeine : computedCaffeineText },
            set: { caffeine = $0 }
        )
    }

    private var abvText: Binding<String> {
        Binding(
            get: { manualOverrideToggle ? abv : EntryHelper.format(food.abv) },
            set: { abv = $0 }
        )
    }

    private func selectVolume(_ milliliters: Double) {
        isResettingPortion = true
        portionUnitSelection = portionWeightUnit
        chosenVolumeML = milliliters
        portionQuantity = (portionVolumeUnit ?? .milliliters).editableText(fromML: milliliters)
        DispatchQueue.main.async {
            isResettingPortion = false
        }
    }

    private var usesVolumeAmount: Bool {
        isDrink && food.servingVolumeML != nil
    }

    private func displayPortion(
        quantity: String,
        unit: String
    ) -> (quantity: String, unit: String, volumeML: Double)? {
        guard let servingVolume = food.servingVolumeML,
            isDrink || unit == VolumeUnit.milliliters.rawValue
        else { return nil }
        let value = parseDouble(quantity)
        let milliliters: Double
        switch unit {
        case VolumeUnit.milliliters.rawValue:
            milliliters = value
        case food.servingUnit?.unit ?? "serving":
            guard food.servingSize > 0 else { return nil }
            milliliters = value / food.servingSize * servingVolume
        default:
            return nil
        }
        let displayUnit: VolumeUnit = volumeUnit == .fluidOunces ? .fluidOunces : .milliliters
        let text = displayUnit.editableText(fromML: milliliters)
        guard unit != displayUnit.rawValue || text != quantity else { return nil }
        return (text, displayUnit.rawValue, milliliters)
    }

    private var sizeChips: [HydrationChip] {
        HydrationLogger.menuSizes(for: food)
            + pendingSizes.map { HydrationChip(food: food, volumeML: $0.volumeML, sizeName: $0.name) }
    }

    private var headerDrinkInfo: DrinkRowInfo? {
        guard isDrink else { return nil }
        var info = DrinkRowInfo(
            food: food,
            amounts: drinkAmounts,
            hasMacros: [calorie, protein, carbs, fat, fiber].contains { parseDouble($0) > 0 }
        )
        if let pending = pendingSizes.first(where: {
            HydrationLogger.isSameVolume($0.volumeML, drinkAmounts.volumeML)
        }) {
            info.sizeName = pending.name
        }
        return info
    }

    private var visibleRecentAmounts: [Double] {
        let sizes = sizeChips.map(\.volumeML)
        return recentDrinkAmounts.filter { volume in
            !sizes.contains { HydrationLogger.isSameVolume($0, volume) }
        }
    }

    private var canSaveSize: Bool {
        let volume = drinkAmounts.volumeML
        return volume > 0
            && !sizeChips.contains { HydrationLogger.isSameVolume($0.volumeML, volume) }
    }

    private func saveSize() {
        let volume = drinkAmounts.volumeML
        guard volume > 0 else { return }
        let trimmed = newSizeName.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingSizes.append(
            PendingDrinkSize(foodID: food.id, name: trimmed.isEmpty ? nil : trimmed, volumeML: volume)
        )
        newSizeName = ""
    }

    private func showPortionInDisplayUnit() {
        if let original = displayPortion(
            quantity: originalPortionQuantity,
            unit: originalPortionUnitSelection
        ) {
            originalPortionQuantity = original.quantity
            originalPortionUnitSelection = original.unit
            originalVolumeML = original.volumeML
        }
        guard let portion = displayPortion(quantity: portionQuantity, unit: portionUnitSelection)
        else { return }
        isResettingPortion = true
        skipsPortionRescale = true
        chosenVolumeML = portion.volumeML
        portionUnitSelection = portion.unit
        portionQuantity = portion.quantity
        DispatchQueue.main.async {
            isResettingPortion = false
            skipsPortionRescale = false
        }
    }

    private func isSelectedVolume(_ milliliters: Double) -> Bool {
        drinkAmounts.volumeML > 0 && HydrationLogger.isSameVolume(drinkAmounts.volumeML, milliliters)
    }

    private func sizeLabel(_ size: HydrationChip) -> String {
        let amount = volumeUnit.formattedAmount(size.volumeML)
        guard let name = size.sizeName, !name.isEmpty else { return amount }
        return "\(name) · \(amount)"
    }

    private var displayServingSize: String {
        let size = activeMultiplier * food.servingSize
        return size.formatted(.number.precision(.fractionLength(0...2)))
    }

    private var displayServingWeight: String {
        guard let weight = food.servingWeight else { return "" }
        let scaledWeight = activeMultiplier * weight
        if food.servingVolumeML != nil { return EntryHelper.format(scaledWeight) }
        return scaledWeight.formatted(.number.precision(.fractionLength(0...2)))
    }

    private func combineDateAndTime(date: Date, time: Date) -> Date {
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

        return calendar.date(from: combinedComponents) ?? Date()
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

    private func parseDouble(_ string: String) -> Double {
        let normalized = string.replacingOccurrences(of: ",", with: ".")
        return Double(normalized) ?? 0.0
    }

    private func attemptSave() {
        let values = MacroSanityCheck.Values(
            calories: calorie,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: fiber,
            weight: food.servingWeight.map { $0 * activeMultiplier },
            weightUnit: food.servingWeightUnit
        )
        let matchesPrevious = values.hasSameMacros(as: previousMacros)
        let isUntouched =
            matchesPrevious
            || values.hasSameMacros(as: .init(food, multiplier: activeMultiplier))
        let isDefaultLog =
            matchesPrevious
            || values.hasSameMacros(
                as: .init(food, multiplier: EntryHelper.defaultPortionMultiplier(for: food))
            )

        let issue: String?
        if manualOverrideToggle && !isUntouched {
            issue = MacroSanityCheck.issue(for: values)
        } else if isDefaultLog {
            issue = nil
        } else {
            issue = MacroSanityCheck.issue(for: values, scope: .sizeOnly)
        }

        if let issue {
            savePrompt = .macroCheck(issue, confirmTitle: "Log Anyway", onConfirm: saveEntry)
        } else {
            saveEntry()
        }
    }

    private func saveEntry() {
        let combinedDate = combineDateAndTime(date: date, time: time)
        let location = locationSelection.resolvedLocation

        let trimmedNote = newNote.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let resolvedNote = trimmedNote.isEmpty ? nil : trimmedNote
        let pinnedNote = resolvedPinnedNote

        let updatesOriginalPin = saveOption != .saveAsNew && hasPinnedNoteChanged
        let addsSizesToOriginal = saveOption != .saveAsNew && !pendingSizes.isEmpty
        let originalFood =
            saveOption == .updateOriginal || updatesOriginalPin || addsSizesToOriginal
            ? MacroBackup.foodRecord(food) : nil
        var createdListItems: [any PersistentModel] = []
        var createdFood: FoodItem? = nil

        var resolvedSource: EntrySource? = nil
        let trimmedSource = sourceSelection.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if !trimmedSource.isEmpty && trimmedSource != "-" {
            if let existing = sourceOptions.first(where: {
                $0.source == trimmedSource
            }) {
                resolvedSource = existing
            } else {
                let nextOrder =
                    (sourceOptions.map { $0.displayOrder }.max() ?? 0) + 1
                let newSource = EntrySource(
                    source: trimmedSource,
                    displayOrder: nextOrder
                )
                modelContext.insert(newSource)
                createdListItems.append(newSource)
                resolvedSource = newSource
            }
        }

        var resolvedCategory: CategorySource? = nil
        let trimmedCategory = categorySelection.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if !trimmedCategory.isEmpty && trimmedCategory != "-" {
            if let existing = categoryOptions.first(where: {
                $0.category == trimmedCategory
            }) {
                resolvedCategory = existing
            } else {
                let nextOrder =
                    (categoryOptions.map { $0.displayOrder }.max() ?? 0) + 1
                let newCategory = CategorySource(
                    category: trimmedCategory,
                    displayOrder: nextOrder
                )
                modelContext.insert(newCategory)
                createdListItems.append(newCategory)
                resolvedCategory = newCategory
            }
        }

        var resolvedFoodGroup: FoodGroupSource? = nil
        let trimmedGroup = foodGroupSelection.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if !trimmedGroup.isEmpty && trimmedGroup != "-" {
            if let existing = foodGroupOptions.first(where: {
                $0.foodGroup == trimmedGroup
            }) {
                resolvedFoodGroup = existing
            } else {
                let nextOrder =
                    (foodGroupOptions.map { $0.displayOrder }.max() ?? 0)
                    + 1
                let newGroup = FoodGroupSource(
                    foodGroup: trimmedGroup,
                    displayOrder: nextOrder
                )
                modelContext.insert(newGroup)
                createdListItems.append(newGroup)
                resolvedFoodGroup = newGroup
            }
        }

        let newLog = LoggedEntry(
            name: name,
            typeRawValue: food.type.rawValue,
            originalFoodItem: food,
            source: resolvedSource,
            category: resolvedCategory,
            foodGroup: resolvedFoodGroup,
            timestamp: combinedDate,
            location: location,
            savedLocation: SavedLocation.find(
                id: location?.savedLocationID,
                in: modelContext
            ),
            loggedQuantity: resolvedPortion.quantity,
            loggedUnit: resolvedPortion.unit,
            calories: parseDouble(calorie),
            protein: parseDouble(protein),
            carbs: parseDouble(carbs),
            fat: parseDouble(fat),
            fiber: parseDouble(fiber),
            isManualOverride: manualOverrideToggle,
            logNote: resolvedNote
        )

        let draft = DraftStore.fetch(id: draftID, in: modelContext)
        let draftRecord = draft.map(MacroBackup.draftRecord)
        newLog.photos = EntryHelper.applyPhotos(
            selectedPhotos,
            replacing: draft?.photos,
            in: modelContext
        )
        draft?.photos = []

        modelContext.insert(newLog)
        RecentLocationStore.record(location, in: modelContext)

        if saveOption == .updateOriginal || saveOption == .saveAsNew {
            let safeMultiplier = activeMultiplier > 0 ? activeMultiplier : 1.0
            let baseCal =
                manualOverrideToggle
                ? (parseDouble(calorie) / safeMultiplier) : food.calories
            let basePro =
                manualOverrideToggle
                ? (parseDouble(protein) / safeMultiplier) : food.protein
            let baseCarb =
                manualOverrideToggle
                ? (parseDouble(carbs) / safeMultiplier) : food.carbs
            let baseFat =
                manualOverrideToggle
                ? (parseDouble(fat) / safeMultiplier) : food.fat
            let baseFib =
                manualOverrideToggle
                ? (parseDouble(fiber) / safeMultiplier) : food.fiber

            if saveOption == .updateOriginal {
                food.source = resolvedSource
                food.category = resolvedCategory
                food.foodGroup = resolvedFoodGroup

                if manualOverrideToggle {
                    food.calories = baseCal
                    food.protein = basePro
                    food.carbs = baseCarb
                    food.fat = baseFat
                    food.fiber = baseFib
                    if showsCaffeineRow { food.caffeineMg = parseDouble(caffeine) / safeMultiplier }
                    if showsAlcoholRow { food.abv = parseDouble(abv) }
                }
            } else if saveOption == .saveAsNew {
                let newFood = FoodItem(
                    name: name.isEmpty ? "New Entry" : name,
                    type: food.type,
                    source: resolvedSource,
                    category: resolvedCategory,
                    foodGroup: resolvedFoodGroup,
                    servingSize: food.servingSize,
                    servingUnit: food.servingUnit,
                    servingWeight: food.servingWeight,
                    servingWeightUnit: food.servingWeightUnit,
                    isAIEstimated: false,
                    calories: baseCal,
                    protein: basePro,
                    carbs: baseCarb,
                    fat: baseFat,
                    fiber: baseFib,
                    isCustomDefaultServing: food.isCustomDefaultServing,
                    customServingSize: food.customServingSize,
                    defaultLocation: food.defaultLocation,
                    stickyNote: pinnedNote.map { Note(text: $0) }
                )
                modelContext.insert(newFood)
                if isDrink {
                    var drinkForm = DrinkFormState(food: food, unit: .milliliters)
                    if manualOverrideToggle {
                        drinkForm.add(.nutrition)
                        if showsCaffeineRow {
                            drinkForm.caffeine = EntryHelper.format(parseDouble(caffeine) / safeMultiplier)
                        }
                        if showsAlcoholRow {
                            drinkForm.abv = EntryHelper.format(parseDouble(abv))
                            drinkForm.isCustomABV = AlcoholStrength.matching(parseDouble(abv)) == nil
                        }
                    }
                    drinkForm.isPinned = false
                    drinkForm.apply(to: newFood, in: modelContext, asCopy: true)
                }
                createdFood = newFood

                newLog.originalFoodItem = newFood
            }
        }

        if updatesOriginalPin {
            EntryHelper.applyPinnedNote(pinnedNote, to: food, in: modelContext)
        }
        HydrationLogger.addSizes(pendingSizes, to: createdFood ?? food, in: modelContext)
        newLog.snapshotDrinkAmounts(children: [])
        if isDrink, manualOverrideToggle {
            newLog.drinkAmounts = newLog.drinkAmounts.overriding(
                caffeineMg: showsCaffeineRow ? parseDouble(caffeine) : nil,
                abv: showsAlcoholRow ? parseDouble(abv) : nil
            )
        }

        DraftStore.delete(id: draftID, in: modelContext, save: false)

        do {
            try modelContext.save()
            didFinishLogging = true
            QuickLogger.finishLocation(
                of: newLog,
                awaitingCurrent: locationSelection.isCurrent && location == nil,
                in: modelContext
            )

            if let toastCenter {
                toastCenter.show(
                    .entryLogged(
                        LogUndoRecord(
                            entry: newLog,
                            originalFood: originalFood,
                            createdFood: createdFood,
                            createdListItems: createdListItems,
                            draft: draftRecord
                        ),
                        title: loggedTitle(for: newLog),
                        in: modelContext,
                        presenter: toastCenter
                    )
                )
            }

            if let rootDismiss {
                rootDismiss()
            } else {
                dismiss()
            }
        } catch {
            toastCenter?.show(
                .failure(String(localized: "Couldn't Log Entry"), message: newLog.name)
            )
            modelContext.rollback()
            savePrompt = nil
        }
    }

    private func loggedTitle(for entry: LoggedEntry) -> String {
        guard isDrink else { return String(localized: "\(food.type.rawValue.capitalized) Logged") }
        let dayStartMinutes = users.first?.dayStartMinutes ?? 0
        let calendar = Calendar.current
        return HydrationLogger.loggedTitle(
            forDay: calendar.logicalDay(for: entry.timestamp, dayStartMinutes: dayStartMinutes),
            logicalToday: calendar.logicalDay(for: .now, dayStartMinutes: dayStartMinutes)
        )
    }

    private var draftState: LogEntryDraftState {
        let draftLocation = locationSelection.draftLocation
        return LogEntryDraftState(
            name: name,
            sourceSelection: sourceSelection,
            categorySelection: categorySelection,
            foodGroupSelection: foodGroupSelection,
            date: date,
            time: time,
            location: draftLocation.location,
            usesCurrentLocation: draftLocation.usesCurrentLocation,
            portionQuantity: portionQuantity,
            portionUnitSelection: portionUnitSelection,
            macros: DraftMacroValues(
                calories: calorie,
                protein: protein,
                carbs: carbs,
                fat: fat,
                fiber: fiber
            ),
            dynamicMacros: DraftMacroValues(
                calories: calorieDynamic,
                protein: proteinDynamic,
                carbs: carbsDynamic,
                fat: fatDynamic,
                fiber: fiberDynamic
            ),
            manualOverrideToggle: manualOverrideToggle,
            caffeine: manualOverrideToggle && showsCaffeineRow ? caffeine : nil,
            abv: manualOverrideToggle && showsAlcoholRow ? abv : nil,
            pendingSizes: pendingSizes.isEmpty ? nil : pendingSizes,
            notes: DraftNoteState(
                stickyNote: stickyNote,
                newNote: newNote,
                pinnedBase: pinnedNoteBase
            ),
            saveOptionRawValue: saveOption.rawValue
        )
    }

    @discardableResult
    private func saveDraft() -> Bool {
        do {
            let draft = try DraftStore.upsert(
                id: draftID,
                kind: .logFood,
                type: food.type,
                name: name.isEmpty ? food.name : name,
                timestamp: combineDateAndTime(date: date, time: time),
                foodItem: food,
                state: draftState,
                photos: selectedPhotos,
                in: modelContext
            )
            EntryHelper.linkPhotos(&selectedPhotos, to: draft.photos)
            return true
        } catch {
            toastCenter?.show(.failure(String(localized: "Couldn't Save Draft")))
            return false
        }
    }

    private func finishLoadingDraftPhotos() {
        guard isLoadingPhotos else { return }

        let id = draftID
        let items = pickerItems
        let loadedPhotos = selectedPhotos
        let cameraCapture = pendingCameraCapture
        let context = modelContext
        let toastCenter = toastCenter

        Task {
            guard
                let photos = await PhotoPickerCard.loadPhotos(
                    for: items,
                    keeping: loadedPhotos,
                    adding: cameraCapture
                )
            else { return }

            do {
                try DraftStore.replacePhotos(ofDraft: id, with: photos, in: context)
            } catch {
                toastCenter?.show(.failure(String(localized: "Couldn't Save Draft Photos")))
            }
        }
    }

    private func handleClose() {
        guard !didFinishLogging, !isPhotoCoverShown else { return }
        didFinishLogging = true

        if isResumedDraft {
            if saveDraft() { finishLoadingDraftPhotos() }
        } else {
            saveDraftOnClose()
        }
    }

    private func saveDraftOnClose() {
        guard hasDraftChanges || isLoadingPhotos, saveDraft() else {
            DraftStore.delete(id: draftID, in: modelContext)
            return
        }
        finishLoadingDraftPhotos()

        toastCenter?.show(
            .draftSaved(
                id: draftID,
                name: name.isEmpty ? food.name : name,
                in: modelContext,
                presenter: toastCenter
            )
        )
    }

    private var hasDraftChanges: Bool {
        guard let initialDraftState, let initialLocation else { return false }
        var state = draftState
        state.location = initialDraftState.location
        state.usesCurrentLocation = initialDraftState.usesCurrentLocation
        return state != initialDraftState
            || locationSelection.isChosenDifferently(from: initialLocation)
            || selectedPhotos.map(\.originalData) != initialPhotoData
    }

    private func autoSaveDraft() {
        if isResumedDraft || hasDraftChanges {
            saveDraft()
        } else {
            DraftStore.delete(id: draftID, in: modelContext)
        }
    }

    init(
        food: FoodItem,
        previousEntry: LoggedEntry? = nil,
        draft: EntryDraft? = nil,
        isPushedView: Bool = false,
        drinkPrefill: DrinkLogPrefill? = nil
    ) {
        self.food = food
        self.isPushedView = isPushedView
        self.isAddingDetails = drinkPrefill != nil

        _name = State(initialValue: previousEntry?.name ?? food.name)

        _sourceSelection = State(
            initialValue: previousEntry?.source?.source
                ?? food.source?.source ?? ""
        )
        _categorySelection = State(
            initialValue: previousEntry?.category?.category
                ?? food.category?.category ?? ""
        )
        _foodGroupSelection = State(
            initialValue: previousEntry?.foodGroup?.foodGroup
                ?? food.foodGroup?.foodGroup ?? ""
        )

        let startingLocation = LocationSelection.defaultForNewLog(
            food: food,
            repeating: previousEntry
        )
        self.initialLocationSelection = startingLocation
        _locationSelection = State(initialValue: startingLocation)

        let startingPortionDouble: Double
        if food.isCustomDefaultServing, let custom = food.customServingSize {
            startingPortionDouble = custom
        } else {
            startingPortionDouble = food.servingSize
        }

        let defaultVolumeML =
            food.type == .drink && food.servingWeightUnit == VolumeUnit.milliliters.rawValue
            ? food.servingWeight.map { $0 * EntryHelper.defaultPortionMultiplier(for: food) }
            : nil
        let defaultPortionQuantity =
            defaultVolumeML.map { EntryHelper.format($0) }
            ?? String(format: "%g", startingPortionDouble)
        let defaultPortionUnit =
            defaultVolumeML != nil
            ? VolumeUnit.milliliters.rawValue : food.servingUnit?.unit ?? "serving"

        _originalPortionQuantity = State(initialValue: defaultPortionQuantity)
        _originalPortionUnitSelection = State(initialValue: defaultPortionUnit)

        _portionQuantity = State(
            initialValue: previousEntry.map {
                EntryHelper.format($0.loggedQuantity)
            } ?? defaultPortionQuantity
        )
        _portionUnitSelection = State(
            initialValue: previousEntry?.loggedUnit ?? defaultPortionUnit
        )

        self.isCustomDefaultServing = food.isCustomDefaultServing
        self.customServingSize = EntryHelper.format(food.customServingSize)
        self.servingWeight = EntryHelper.format(food.servingWeight)
        self.servingWeightUnit = food.servingWeightUnit

        let calStr = EntryHelper.format(food.calories)
        let proStr = EntryHelper.format(food.protein)
        let carbStr = EntryHelper.format(food.carbs)
        let fatStr = EntryHelper.format(food.fat)
        let fibStr = EntryHelper.format(food.fiber)

        self.calorieStatic = calStr
        self.proteinStatic = proStr
        self.carbsStatic = carbStr
        self.fatStatic = fatStr
        self.fiberStatic = fibStr
        self.previousMacros = previousEntry.map { MacroSanityCheck.Values($0) }

        let defaultMultiplier = EntryHelper.defaultPortionMultiplier(for: food)

        let initialCalorie =
            previousEntry.map { EntryHelper.formatLoggedMacro($0.calories, of: $0, food: food) }
            ?? EntryHelper.scale(calStr, by: defaultMultiplier)
        let initialProtein =
            previousEntry.map { EntryHelper.formatLoggedMacro($0.protein, of: $0, food: food) }
            ?? EntryHelper.scale(proStr, by: defaultMultiplier)
        let initialCarbs =
            previousEntry.map { EntryHelper.formatLoggedMacro($0.carbs, of: $0, food: food) }
            ?? EntryHelper.scale(carbStr, by: defaultMultiplier)
        let initialFat =
            previousEntry.map { EntryHelper.formatLoggedMacro($0.fat, of: $0, food: food) }
            ?? EntryHelper.scale(fatStr, by: defaultMultiplier)
        let initialFiber =
            previousEntry.map { EntryHelper.formatLoggedMacro($0.fiber, of: $0, food: food) }
            ?? EntryHelper.scale(fibStr, by: defaultMultiplier)

        _calorieDynamic = State(initialValue: initialCalorie)
        _proteinDynamic = State(initialValue: initialProtein)
        _carbsDynamic = State(initialValue: initialCarbs)
        _fatDynamic = State(initialValue: initialFat)
        _fiberDynamic = State(initialValue: initialFiber)

        _calorie = State(initialValue: initialCalorie)
        _protein = State(initialValue: initialProtein)
        _carbs = State(initialValue: initialCarbs)
        _fat = State(initialValue: initialFat)
        _fiber = State(initialValue: initialFiber)

        _manualOverrideToggle = State(
            initialValue: previousEntry?.isManualOverride ?? false
        )
        let overriddenAmounts = previousEntry.flatMap { $0.isManualOverride ? $0.drinkAmounts : nil }
        _caffeine = State(
            initialValue: overriddenAmounts.map { EntryHelper.format($0.caffeineMg.rounded()) } ?? ""
        )
        _abv = State(
            initialValue: overriddenAmounts.map { EntryHelper.formatMacroField($0.abv ?? 0) } ?? ""
        )

        let currentPinnedNote = food.stickyNote?.text ?? ""
        _stickyNote = State(initialValue: currentPinnedNote)
        _pinnedNoteBase = State(initialValue: currentPinnedNote)

        _newNote = State(initialValue: "")

        _selectedPhotos = State(initialValue: [])

        _dateAdded = State(initialValue: food.dateAdded)

        if let drinkPrefill {
            let serving = food.servingWeight ?? 0
            let multiplier = serving > 0 ? drinkPrefill.volumeML / serving : 0
            _portionQuantity = State(initialValue: EntryHelper.format(drinkPrefill.volumeML))
            _portionUnitSelection = State(initialValue: VolumeUnit.milliliters.rawValue)
            let prefillCalorie = EntryHelper.scale(calStr, by: multiplier)
            let prefillProtein = EntryHelper.scale(proStr, by: multiplier)
            let prefillCarbs = EntryHelper.scale(carbStr, by: multiplier)
            let prefillFat = EntryHelper.scale(fatStr, by: multiplier)
            let prefillFiber = EntryHelper.scale(fibStr, by: multiplier)
            _calorie = State(initialValue: prefillCalorie)
            _protein = State(initialValue: prefillProtein)
            _carbs = State(initialValue: prefillCarbs)
            _fat = State(initialValue: prefillFat)
            _fiber = State(initialValue: prefillFiber)
            _calorieDynamic = State(initialValue: prefillCalorie)
            _proteinDynamic = State(initialValue: prefillProtein)
            _carbsDynamic = State(initialValue: prefillCarbs)
            _fatDynamic = State(initialValue: prefillFat)
            _fiberDynamic = State(initialValue: prefillFiber)
            _date = State(initialValue: drinkPrefill.timestamp)
            _time = State(initialValue: drinkPrefill.timestamp)
            _pendingSizes = State(initialValue: drinkPrefill.pendingSizes)
        }

        _draftID = State(initialValue: draft?.id ?? UUID())
        self.isResumedDraft = draft != nil

        if let draft, let state = draft.decodeState(LogEntryDraftState.self) {
            _name = State(initialValue: state.name)
            _sourceSelection = State(initialValue: state.sourceSelection)
            _categorySelection = State(initialValue: state.categorySelection)
            _foodGroupSelection = State(initialValue: state.foodGroupSelection)

            _date = State(initialValue: state.date)
            _time = State(initialValue: state.time)
            _locationSelection = State(
                initialValue: LocationSelection(
                    state.location,
                    usesCurrentLocation: state.usesCurrentLocation ?? false
                )
            )

            _portionQuantity = State(initialValue: state.portionQuantity)
            _portionUnitSelection = State(
                initialValue: state.portionUnitSelection
            )

            _manualOverrideToggle = State(
                initialValue: state.manualOverrideToggle
            )
            if let caffeine = state.caffeine {
                _caffeine = State(initialValue: caffeine)
            }
            if let abv = state.abv {
                _abv = State(initialValue: abv)
            }
            _pendingSizes = State(initialValue: state.pendingSizes ?? [])

            let macros: DraftMacroValues
            let dynamicMacros: DraftMacroValues
            if state.manualOverrideToggle {
                macros = state.macros
                dynamicMacros = state.dynamicMacros
            } else {
                let isFluidOunces = state.portionUnitSelection == VolumeUnit.fluidOunces.rawValue
                let isWeightSelected =
                    (state.portionUnitSelection == food.servingWeightUnit || isFluidOunces)
                    && food.servingWeight != nil
                let restoredQuantity = Double(state.portionQuantity) ?? 0
                let multiplier = EntryHelper.calculateMultiplier(
                    targetPortion: isFluidOunces
                        ? VolumeUnit.fluidOunces.milliliters(from: restoredQuantity)
                        : restoredQuantity,
                    basePortion: isWeightSelected
                        ? (food.servingWeight ?? food.servingSize)
                        : food.servingSize
                )
                macros = DraftMacroValues(
                    calories: EntryHelper.scale(calStr, by: multiplier),
                    protein: EntryHelper.scale(proStr, by: multiplier),
                    carbs: EntryHelper.scale(carbStr, by: multiplier),
                    fat: EntryHelper.scale(fatStr, by: multiplier),
                    fiber: EntryHelper.scale(fibStr, by: multiplier)
                )
                dynamicMacros = macros
            }

            _calorie = State(initialValue: macros.calories)
            _protein = State(initialValue: macros.protein)
            _carbs = State(initialValue: macros.carbs)
            _fat = State(initialValue: macros.fat)
            _fiber = State(initialValue: macros.fiber)

            _calorieDynamic = State(initialValue: dynamicMacros.calories)
            _proteinDynamic = State(initialValue: dynamicMacros.protein)
            _carbsDynamic = State(initialValue: dynamicMacros.carbs)
            _fatDynamic = State(initialValue: dynamicMacros.fat)
            _fiberDynamic = State(initialValue: dynamicMacros.fiber)

            if state.notes.stickyNote != state.notes.pinnedBase {
                _stickyNote = State(initialValue: state.notes.stickyNote)
                _pinnedNoteBase = State(
                    initialValue: state.notes.pinnedBase ?? currentPinnedNote
                )
            }
            _newNote = State(initialValue: state.notes.newNote)

            _selectedPhotos = State(
                initialValue: EntryHelper.loggedPhotos(from: draft.photos)
            )

            _saveOption = State(
                initialValue: LogSaveOption(
                    rawValue: state.saveOptionRawValue
                ) ?? .logOnly
            )
        }
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

                if canSaveSize {
                    Button("Save as Size", systemImage: "plus") {
                        isSavingSize = true
                    }
                    .labelStyle(.titleAndIcon)
                    .buttonStyle(.filterChip(isSelected: false))
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 16)
            .animation(.easeInOut(duration: 0.2), value: canSaveSize)
        }
        .scrollIndicators(.hidden)
        .chipScrollFade()
    }

    @ViewBuilder
    private var portionCard: some View {
        if usesVolumeAmount {
            Card {
                VStack(spacing: 0) {
                    BaseRowLayout(title: "Amount") {
                        InputPill(
                            text: $portionQuantity,
                            unit: portionUnitSelection,
                            keyboardType: .decimalPad
                        )
                    }

                    drinkAmountChips
                        .padding(.bottom, 12)
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
        BaseRowLayout(title: "Portion") {
            HStack(spacing: 8) {
                InputPill(
                    text: $portionQuantity,
                    keyboardType: .decimalPad
                )
                DropdownPill(
                    options: availableUnits,
                    displayCustomOption: false,
                    selection: $portionUnitSelection,
                )
            }
        }
    }

    private var macrosCard: some View {
        Card {
            RowGroup(.divider) {
                if showsMacroRows {
                    TextInputRow(
                        icon: .calorie,
                        title: "Calories",
                        titleExtension: "(kcal)",
                        text: $calorie,
                        keyboardType: .decimalPad,
                        isEnabled: manualOverrideToggle
                    )

                    TextInputRow(
                        icon: .protein,
                        title: "Protein",
                        titleExtension: "(g)",
                        text: $protein,
                        keyboardType: .decimalPad,
                        isEnabled: manualOverrideToggle
                    )

                    TextInputRow(
                        icon: .carbs,
                        title: "Carbohydrates",
                        titleExtension: "(g)",
                        text: $carbs,
                        keyboardType: .decimalPad,
                        isEnabled: manualOverrideToggle
                    )

                    TextInputRow(
                        icon: .fat,
                        title: "Fat",
                        titleExtension: "(g)",
                        text: $fat,
                        keyboardType: .decimalPad,
                        isEnabled: manualOverrideToggle
                    )

                    TextInputRow(
                        icon: .fiber,
                        title: "Fiber",
                        titleExtension: "(g)",
                        text: $fiber,
                        keyboardType: .decimalPad,
                        isEnabled: manualOverrideToggle
                    )
                }

                if showsCaffeineRow {
                    TextInputRow(
                        icon: .caffeine,
                        title: "Caffeine",
                        titleExtension: "(mg)",
                        text: caffeineText,
                        keyboardType: .decimalPad,
                        isEnabled: manualOverrideToggle
                    )
                }

                if showsAlcoholRow {
                    TextInputRow(
                        icon: .alcohol,
                        title: "Alcohol",
                        titleExtension: "(% ABV)",
                        text: abvText,
                        keyboardType: .decimalPad,
                        isEnabled: manualOverrideToggle
                    )
                }

                ToggleRow(
                    title: "Manual Override",
                    isOn: $manualOverrideToggle
                )
            }
        }
        .padding([.leading, .trailing])
    }

    private var formContent: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            ScrollView {
                VStack {
                    portionCard
                        .padding([.leading, .trailing])

                    Card {
                        RowGroup(.divider) {
                            DropdownPillRow(
                                title: "Source",
                                options: [""]
                                    + sourceOptions.visibleNames(
                                        keeping: sourceSelection
                                    ).filter
                                {
                                    !$0.trimmingCharacters(
                                        in: .whitespacesAndNewlines
                                    ).isEmpty
                                },
                                selection: $sourceSelection
                            )

                            if food.type == .food || isDrink {
                                DropdownPillRow(
                                    title: "Category",
                                    options: [""]
                                        + categoryOptions.visibleNames(
                                            keeping: categorySelection
                                        ).filter {
                                            !$0.trimmingCharacters(
                                                in: .whitespacesAndNewlines
                                            ).isEmpty
                                        },
                                    selection: $categorySelection
                                )
                            } else {
                                DropdownPillRow(
                                    title: "Food Group",
                                    options: [""]
                                        + foodGroupOptions.visibleNames(
                                            keeping: foodGroupSelection
                                        ).filter {
                                            !$0.trimmingCharacters(
                                                in: .whitespacesAndNewlines
                                            ).isEmpty
                                        },
                                    selection: $foodGroupSelection
                                )
                            }

                            DateTimePillRow(
                                title: "Date & Time",
                                dateSelection: $date,
                                timeSelection: $time
                            )

                            LocationRow(
                                selection: $locationSelection,
                                food: food,
                                photos: selectedPhotos,
                                logDate: date,
                                nearbyName: DefaultLocationResolver.nearbyName(
                                    for: food,
                                    in: modelContext
                                )
                            )
                        }
                    }
                    .padding([.top, .leading, .trailing])

                    NotesCard(
                        pinnedNote: $stickyNote,
                        logNote: $newNote,
                        pinnedUpdated: pinnedNoteUpdated,
                        onViewAll: { showingAllNotes = true }
                    )
                    .padding([.top, .leading, .trailing])

                    PhotoPickerCard(
                        images: $selectedPhotos,
                        isLoading: $isLoadingPhotos,
                        onViewAll: hasPhotoHistory
                            ? { showingAllPhotos = true } : nil,
                        onUseTime: usePhotoTime,
                        onUseLocation: usePhotoLocation,
                        entryDate: date,
                        entryTime: time,
                        entryLocation: locationSelection.resolvedLocation,
                        onPickerItemsChange: { pickerItems = $0 },
                        onCameraCaptureChange: { pendingCameraCapture = $0 },
                        onCoverChange: { isPhotoCoverShown = $0 }
                    )

                    if showsMacros {
                        macrosCard
                    }

                    Spacer()
                }
            }
            .safeAreaBar(edge: .top) {
                Card {
                    MealRow(
                        name: name.isEmpty
                            ? "New \(food.type.rawValue.capitalized)"
                            : name,
                        source: sourceSelection,
                        isCustomDefaultServing: false,
                        customServingSize: "",
                        servingSize: displayServingSize,
                        servingSizeUnit: food.servingUnit?.unit
                            ?? "serving",
                        servingWeight: displayServingWeight,
                        servingWeightUnit: food.servingWeightUnit,
                        servingUnits: portionUnitOptions,
                        calorie: calorie,
                        protein: protein,
                        carbs: carbs,
                        fat: fat,
                        fiber: fiber
                    )
                    .nameLineLimit(3)
                    .drink(headerDrinkInfo)
                }
                .padding([.leading, .trailing])
                .padding(.bottom, 24)
            }
            .withCustomKeyboardToolbar()
            .navigationTitle(
                isAddingDetails
                    ? "Add Details" : isDrink ? "Log Drink" : food.type == .food ? "Log Food" : "Log Ingredient"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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

                ToolbarItemGroup(placement: .automatic) {
                    Menu {
                        ForEach(LogSaveOption.allCases) { option in
                            Button {
                                saveOption = option
                            } label: {
                                if saveOption == option {
                                    Label(
                                        option.rawValue,
                                        systemImage: "checkmark"
                                    )
                                } else {
                                    Text(option.rawValue)
                                }
                            }
                            .disabled(!isEdited && option != .logOnly)
                        }

                        if hasChangedFromOriginal {
                            Divider()

                            Button(role: .destructive) {
                                isResettingPortion = true
                                withAnimation {
                                    name = food.name
                                    sourceSelection =
                                        food.source?.source ?? ""
                                    categorySelection =
                                        food.category?.category ?? ""
                                    foodGroupSelection =
                                        food.foodGroup?.foodGroup ?? ""
                                    locationSelection = initialLocationSelection

                                    portionQuantity =
                                        originalPortionQuantity
                                    portionUnitSelection =
                                        originalPortionUnitSelection
                                    chosenVolumeML = originalVolumeML

                                    manualOverrideToggle = false
                                    calorie = EntryHelper.scale(
                                        calorieStatic,
                                        by: activeMultiplier
                                    )
                                    protein = EntryHelper.scale(
                                        proteinStatic,
                                        by: activeMultiplier
                                    )
                                    carbs = EntryHelper.scale(
                                        carbsStatic,
                                        by: activeMultiplier
                                    )
                                    fat = EntryHelper.scale(
                                        fatStatic,
                                        by: activeMultiplier
                                    )
                                    fiber = EntryHelper.scale(
                                        fiberStatic,
                                        by: activeMultiplier
                                    )
                                    calorieDynamic = calorie
                                    proteinDynamic = protein
                                    carbsDynamic = carbs
                                    fatDynamic = fat
                                    fiberDynamic = fiber

                                    stickyNote = food.stickyNote?.text ?? ""
                                    pinnedNoteBase = stickyNote
                                    newNote = ""

                                    selectedPhotos = []
                                    isLoadingPhotos = false
                                    pendingSizes = []

                                    saveOption = .logOnly
                                }
                                DispatchQueue.main.async {
                                    isResettingPortion = false
                                }
                            } label: {
                                Label(
                                    "Reset to Original",
                                    systemImage: "arrow.counterclockwise"
                                )
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.primary)
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        attemptSave()
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(.primary)
                    }
                    .tint(Color.accentColor)
                    .buttonStyle(.glassProminent)
                    .disabled(isLoadingPhotos || (usesVolumeAmount && drinkAmounts.volumeML <= 0))
                    .savePromptPopover(
                        $savePrompt,
                        dismissesScreen: rootDismiss != nil || !isPushedView
                    )
                }
            }
        }
    }

    private func withEditHandlers(_ content: some View) -> some View {
        content
            .onChange(of: isEdited) { oldVal, newVal in
                if !newVal && saveOption != .logOnly {
                    saveOption = .logOnly
                }
            }
            .onChange(of: portionUnitSelection) { oldUnit, newUnit in
                guard !isResettingPortion, oldUnit != newUnit,
                    let servingWeight = food.servingWeight
                else { return }
                chosenVolumeML = nil
                let currentQuantity = Double(portionQuantity) ?? 0
                let baseUnit = food.servingUnit?.unit ?? "serving"
                let weightUnit = portionWeightUnit
                let weight =
                    weightUnit == VolumeUnit.fluidOunces.rawValue
                    ? VolumeUnit.fluidOunces.value(fromML: servingWeight) : servingWeight

                if oldUnit == baseUnit && newUnit == weightUnit
                {
                    let newQuantity =
                        (currentQuantity / food.servingSize) * weight
                    portionQuantity = newQuantity.formatted(
                        .number.precision(.fractionLength(0...2)).grouping(.never)
                    )

                } else if oldUnit == weightUnit
                    && newUnit == baseUnit
                {
                    let newQuantity =
                        (currentQuantity / weight) * food.servingSize
                    portionQuantity = newQuantity.formatted(
                        .number.precision(.fractionLength(0...2)).grouping(.never)
                    )
                }
            }
            .onChange(of: portionQuantity) { _, text in
                if let chosenVolumeML, text != portionVolumeUnit?.editableText(fromML: chosenVolumeML) {
                    self.chosenVolumeML = nil
                }
                if !manualOverrideToggle && !skipsPortionRescale {
                    calorie = EntryHelper.scale(
                        calorieStatic,
                        by: activeMultiplier
                    )
                    protein = EntryHelper.scale(
                        proteinStatic,
                        by: activeMultiplier
                    )
                    carbs = EntryHelper.scale(
                        carbsStatic,
                        by: activeMultiplier
                    )
                    fat = EntryHelper.scale(fatStatic, by: activeMultiplier)
                    fiber = EntryHelper.scale(
                        fiberStatic,
                        by: activeMultiplier
                    )

                    calorieDynamic = calorie
                    proteinDynamic = protein
                    carbsDynamic = carbs
                    fatDynamic = fat
                    fiberDynamic = fiber
                }
            }
            .onChange(of: manualOverrideToggle) { oldValue, isManual in
                if isManual {
                    caffeine = computedCaffeineText
                    abv = EntryHelper.format(food.abv)
                    calorie = calorieDynamic
                    protein = proteinDynamic
                    carbs = carbsDynamic
                    fat = fatDynamic
                    fiber = fiberDynamic
                } else {
                    calorie = EntryHelper.scale(
                        calorieStatic,
                        by: activeMultiplier
                    )
                    protein = EntryHelper.scale(
                        proteinStatic,
                        by: activeMultiplier
                    )
                    carbs = EntryHelper.scale(
                        carbsStatic,
                        by: activeMultiplier
                    )
                    fat = EntryHelper.scale(fatStatic, by: activeMultiplier)
                    fiber = EntryHelper.scale(
                        fiberStatic,
                        by: activeMultiplier
                    )
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
            .onChange(of: fat) {
                if manualOverrideToggle { fatDynamic = fat }
            }
            .onChange(of: fiber) {
                if manualOverrideToggle { fiberDynamic = fiber }
            }
    }

    private var form: some View {
        withEditHandlers(formContent)
            .onAppear {
                if initialDraftState == nil {
                    showPortionInDisplayUnit()
                    initialDraftState = draftState
                    initialPhotoData = selectedPhotos.map(\.originalData)
                    initialLocation = locationSelection
                }
                if isDrink {
                    recentDrinkAmounts = HydrationLogger.recentAmounts(
                        for: food,
                        includesEntries: true,
                        in: modelContext
                    )
                }
            }
            .alert("Save Size", isPresented: $isSavingSize) {
                TextField("Name (Optional)", text: $newSizeName)
                Button("Cancel", role: .cancel) { newSizeName = "" }
                Button("Save") { saveSize() }
            } message: {
                Text("Saves \(volumeUnit.formattedAmount(drinkAmounts.volumeML)) as a size for \(food.name)")
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background && !didFinishLogging {
                    autoSaveDraft()
                }
            }
            .onChange(of: food.stickyNote?.text) { _, text in
                guard stickyNote == pinnedNoteBase else { return }
                stickyNote = text ?? ""
                pinnedNoteBase = stickyNote
                initialDraftState?.notes.stickyNote = stickyNote
                initialDraftState?.notes.pinnedBase = stickyNote
            }
            .onLeave { handleClose() }
            .onDisappear { handleClose() }
            .onDraftDeleted(id: draftID, isEnabled: isResumedDraft) {
                guard !didFinishLogging else { return }
                didFinishLogging = true
                dismiss()
            }
            .sheet(isPresented: $showingAllNotes) {
                NotesHistoryView(food: food)
            }
            .sheet(isPresented: $showingAllPhotos) {
                PhotoHistoryView(food: food)
            }        .task {
                hasPhotoHistory = FoodItemStore.hasPhotoHistory(
                    for: food,
                    in: modelContext
                )
            }
    }

    var body: some View {
        if isPushedView {
            form
        } else {
            NavigationStack {
                form
            }
        }
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: FoodItem.self,
            EntrySource.self,
            CategorySource.self,
            ServingSizeUnit.self,
            configurations: config
        )

        let defaultSource = EntrySource(
            source: "Home",
            isDefault: true,
            displayOrder: 1
        )
        let defaultCategory = CategorySource(
            category: "Breakfast",
            isDefault: true,
            displayOrder: 1
        )
        let defaultUnit = ServingSizeUnit(
            unit: "serving",
            isDefault: true,
            displayOrder: 1
        )

        container.mainContext.insert(defaultSource)
        container.mainContext.insert(defaultCategory)
        container.mainContext.insert(defaultUnit)

        let dummyFood = FoodItem(
            name: "Oatmeal",
            source: defaultSource,
            category: defaultCategory,
            servingSize: 2,
            servingUnit: defaultUnit,
            servingWeight: 40,
            servingWeightUnit: "g",
            isAIEstimated: false,
            calories: 150,
            protein: 5,
            carbs: 27,
            fat: 2.5,
            fiber: 4,
            isCustomDefaultServing: false,
            stickyNote: Note(
                text: "Testing and sticky note!",
                lastUpdated: Date()
            )
        )

        container.mainContext.insert(dummyFood)

        return LogEntryView(food: dummyFood)
            .modelContainer(container)

    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
