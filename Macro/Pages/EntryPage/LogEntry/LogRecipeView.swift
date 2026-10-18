//
//  LogRecipeView.swift
//  Macro
//
//  Created by Shrey Gangwar on 2026-05-20.
//

import PhotosUI
import SwiftData
import SwiftUI

// TODO: FIX BUG WHERE ADDING FOOD WITH 2 DEFAULT SERVING THEN CHANGING IN LOG FOOD, IF CHANGE SERVING TO 1 THEN 2 IT DOUBLES SERVING FIX THIS

struct LogRecipeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.rootDismiss) var rootDismiss
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.toastCenter) private var toastCenter

    @Query(sort: \EntrySource.displayOrder) var sourceOptions: [EntrySource]
    @Query(sort: \CategorySource.displayOrder) var categoryOptions:
        [CategorySource]
    @Query(sort: \ServingSizeUnit.displayOrder) var portionUnitOptions:
        [ServingSizeUnit]

    let recipe: FoodItem
    @State private var name: String
    var isPushedView: Bool = false

    private let isCustomDefaultServing: Bool
    private let customServingSize: String
    private let servingWeight: String
    private let servingWeightUnit: String

    @State private var sourceSelection: String
    @State private var categorySelection: String

    @State private var date = Date()
    @State private var time = Date()
    @State private var locationSelection: LocationSelection
    private let initialLocationSelection: LocationSelection

    @State private var portionQuantity: String
    @State private var portionUnitSelection: String

    @State private var draftIngredients: [LogRecipeIngredient] = []
    @State private var showIngredientSelectionSheet = false

    private let initialSourceSelection: String
    private let initialCategorySelection: String
    private let initialPortionQuantity: String
    private let initialPortionUnitSelection: String
    @State private var initialIngredients: [LogRecipeIngredient] = []
    @State private var saveOption: LogSaveOption = .logOnly

    @State private var isResettingPortion = false

    @State private var draftID: UUID
    private let isResumedDraft: Bool
    private let previousMacros: MacroSanityCheck.Values?
    @State private var didFinishLogging = false
    @State private var savePrompt: SavePromptStep?

    @State private var initialDraftState: LogRecipeDraftState?
    @State private var initialPhotoData: [Data] = []
    @State private var initialLocation: LocationSelection?

    @State private var focusManager = SwipeFocusManager()

    @State private var stickyNote: String
    private let stickyNoteDate: Date?

    private let originalNoteText: String

    @State private var newNote: String

    @State private var showingAllNotes: Bool = false
    @State private var showingAllPhotos: Bool = false
    @State private var hasPhotoHistory: Bool = false
    @State private var dateAdded: Date

    @State private var selectedPhotos: [LoggedPhoto]
    @State private var isLoadingPhotos = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var pendingCameraCapture: CameraCapture?
    @State private var isPhotoCoverShown = false

    var isEdited: Bool {
        draftIngredients != initialIngredients
            || sourceSelection != initialSourceSelection
            || categorySelection != initialCategorySelection
            || portionQuantity != initialPortionQuantity
            || portionUnitSelection != initialPortionUnitSelection
    }

    private var hasChangedFromOriginal: Bool {
        isEdited
            || name != recipe.name
            || stickyNote != originalNoteText
            || !newNote.isEmpty
            || !selectedPhotos.isEmpty
    }

    private var resolvedPinnedNote: String? {
        let trimmed = stickyNote.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var hasPinnedNoteChanged: Bool {
        resolvedPinnedNote != recipe.stickyNote?.text
    }

    private var pinnedNoteUpdated: Date? {
        stickyNote == originalNoteText ? stickyNoteDate : .now
    }

    var mappedSourceOptions: [String] {
        [""]
            + sourceOptions.visibleNames(keeping: sourceSelection).filter {
                let trimmed = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                return !trimmed.isEmpty && trimmed != "-"
            }
    }

    var mappedCategoryOptions: [String] {
        [""]
            + categoryOptions.visibleNames(keeping: categorySelection).filter {
                let trimmed = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                return !trimmed.isEmpty && trimmed != "-"
            }
    }

    var mappedUnitOptions: [String] {
        portionUnitOptions.map { $0.unit }
    }

    var totalBaseCalories: Double {
        draftIngredients.reduce(0) { $0 + $1.activeCalories }
    }
    var totalBaseProtein: Double {
        draftIngredients.reduce(0) { $0 + $1.activeProtein }
    }
    var totalBaseCarbs: Double {
        draftIngredients.reduce(0) { $0 + $1.activeCarbs }
    }
    var totalBaseFat: Double {
        draftIngredients.reduce(0) { $0 + $1.activeFat }
    }
    var totalBaseFiber: Double {
        draftIngredients.reduce(0) { $0 + $1.activeFiber }
    }

    var displayCalories: Double { totalBaseCalories * activeMultiplier }
    var displayProtein: Double { totalBaseProtein * activeMultiplier }
    var displayCarbs: Double { totalBaseCarbs * activeMultiplier }
    var displayFat: Double { totalBaseFat * activeMultiplier }
    var displayFiber: Double { totalBaseFiber * activeMultiplier }

    var calculatedTotalWeight: Double {
        draftIngredients.compactMap { $0.activeWeight }.reduce(0, +)
    }

    var totalRecipeWeight: Double {
        if let manualWeight = Double(servingWeight) {
            return manualWeight
        }
        return calculatedTotalWeight
    }

    var displayWeight: Double {
        return totalRecipeWeight * activeMultiplier
    }

    var shouldShowIngredientIcons: Bool {
        draftIngredients.contains { $0.icon != nil }
    }

    private var activeMultiplier: Double {
        EntryHelper.portionMultiplier(
            quantity: Double(portionQuantity) ?? 0,
            unit: portionUnitSelection,
            servingSize: recipe.servingSize,
            servingWeight: totalRecipeWeight > 0 ? totalRecipeWeight : nil,
            servingWeightUnit: recipe.servingWeightUnit
        ) ?? 0
    }

    var availableUnits: [String] {
        var units: [String] = []
        let baseUnit = recipe.servingUnit?.unit ?? "serving"

        units.append(baseUnit)

        if totalRecipeWeight > 0 && recipe.servingWeightUnit != baseUnit {
            units.append(recipe.servingWeightUnit)
        }

        return units
    }

    private var displayServingSize: String {
        let size = activeMultiplier * recipe.servingSize
        return size.formatted(.number.precision(.fractionLength(0...2)))
    }

    private var displayServingWeight: String {
        guard totalRecipeWeight > 0 else { return "" }
        let scaledWeight = activeMultiplier * totalRecipeWeight
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
            calories: displayCalories,
            protein: displayProtein,
            carbs: displayCarbs,
            fat: displayFat
        )
        let isDefaultLog =
            values.hasSameMacros(as: previousMacros)
            || values.hasSameMacros(
                as: .init(recipe, multiplier: EntryHelper.defaultPortionMultiplier(for: recipe))
            )
        let issue = isDefaultLog ? nil : MacroSanityCheck.issue(for: values, scope: .sizeOnly)
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
        let originalRecipe =
            saveOption == .updateOriginal || updatesOriginalPin
            ? MacroBackup.foodRecord(recipe) : nil
        var createdListItems: [any PersistentModel] = []
        var createdRecipe: FoodItem? = nil

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

        let mainLog = LoggedEntry(
            name: name.isEmpty ? "New Recipe" : name,
            typeRawValue: recipe.type.rawValue,
            originalFoodItem: recipe,
            parentEntry: nil,
            source: resolvedSource,
            category: resolvedCategory,
            timestamp: combinedDate,
            location: location,
            savedLocation: SavedLocation.find(
                id: location?.savedLocationID,
                in: modelContext
            ),
            loggedQuantity: parseDouble(portionQuantity),
            loggedUnit: portionUnitSelection,
            calories: displayCalories,
            protein: displayProtein,
            carbs: displayCarbs,
            fat: displayFat,
            fiber: displayFiber,
            isManualOverride: false,
            logNote: resolvedNote
        )

        let draft = DraftStore.fetch(id: draftID, in: modelContext)
        let draftRecord = draft.map(MacroBackup.draftRecord)
        mainLog.photos = EntryHelper.applyPhotos(
            selectedPhotos,
            replacing: draft?.photos,
            in: modelContext
        )
        draft?.photos = []

        modelContext.insert(mainLog)
        RecentLocationStore.record(location, in: modelContext)

        for (index, draft) in draftIngredients.enumerated() {
            let baseDraftQuantity = parseDouble(draft.quantity)
            let scaledQuantity = baseDraftQuantity * activeMultiplier

            let ingredientLog = LoggedEntry(
                name: draft.name,
                typeRawValue: "ingredient",
                originalFoodItem: draft.ingredientItem,
                parentEntry: mainLog,
                timestamp: combinedDate,
                location: location,
                savedLocation: mainLog.savedLocation,
                loggedQuantity: scaledQuantity,
                loggedUnit: draft.unit,
                calories: draft.activeCalories * activeMultiplier,
                protein: draft.activeProtein * activeMultiplier,
                carbs: draft.activeCarbs * activeMultiplier,
                fat: draft.activeFat * activeMultiplier,
                fiber: draft.activeFiber * activeMultiplier,
                isManualOverride: false,
                logNote: nil,
                displayOrder: index
            )

            modelContext.insert(ingredientLog)
        }

        if saveOption == .updateOriginal || saveOption == .saveAsNew {
            if saveOption == .updateOriginal {
                recipe.source = resolvedSource
                recipe.category = resolvedCategory

                recipe.calories = totalBaseCalories
                recipe.protein = totalBaseProtein
                recipe.carbs = totalBaseCarbs
                recipe.fat = totalBaseFat
                recipe.fiber = totalBaseFiber
                recipe.servingWeight =
                    calculatedTotalWeight > 0 ? calculatedTotalWeight : nil

                let previousDates = RecipeIngredient.datesByItem(
                    recipe.recipeIngredients ?? []
                )
                if let existingIngredients = recipe.recipeIngredients {
                    for old in existingIngredients {
                        modelContext.delete(old)
                    }
                }
                recipe.recipeIngredients = []

                for (index, draft) in draftIngredients.enumerated() {
                    let newIngredient = RecipeIngredient(
                        quantity: parseDouble(draft.quantity),
                        unit: draft.unit,
                        displayOrder: index,
                        name: draft.name,
                        baseServingSize: draft.baseServingSize,
                        baseServingUnitName: draft.baseServingUnitName,
                        baseServingWeight: draft.baseServingWeight,
                        baseServingWeightUnit: draft.baseServingWeightUnit,
                        baseCalories: draft.baseCalories,
                        baseProtein: draft.baseProtein,
                        baseCarbs: draft.baseCarbs,
                        baseFat: draft.baseFat,
                        baseFiber: draft.baseFiber
                    )
                    newIngredient.ingredientItem = draft.ingredientItem
                    newIngredient.parentRecipe = recipe
                    if let id = draft.ingredientItem?.id,
                        let date = previousDates[id]
                    {
                        newIngredient.dateAdded = date
                    }
                    modelContext.insert(newIngredient)
                    recipe.recipeIngredients?.append(newIngredient)
                }

            } else if saveOption == .saveAsNew {
                let newRecipe = FoodItem(
                    name: name.isEmpty ? "New Recipe" : name,
                    type: recipe.type,
                    source: resolvedSource,
                    category: resolvedCategory,
                    foodGroup: recipe.foodGroup,
                    servingSize: recipe.servingSize,
                    servingUnit: recipe.servingUnit,
                    servingWeight: calculatedTotalWeight > 0
                        ? calculatedTotalWeight : nil,
                    servingWeightUnit: recipe.servingWeightUnit,
                    isAIEstimated: false,
                    calories: totalBaseCalories,
                    protein: totalBaseProtein,
                    carbs: totalBaseCarbs,
                    fat: totalBaseFat,
                    fiber: totalBaseFiber,
                    isCustomDefaultServing: recipe.isCustomDefaultServing,
                    customServingSize: recipe.customServingSize,
                    defaultLocation: recipe.defaultLocation,
                    stickyNote: pinnedNote.map { Note(text: $0) }
                )

                modelContext.insert(newRecipe)
                createdRecipe = newRecipe

                for (index, draft) in draftIngredients.enumerated() {
                    let newIngredient = RecipeIngredient(
                        quantity: parseDouble(draft.quantity),
                        unit: draft.unit,
                        displayOrder: index,
                        name: draft.name,
                        baseServingSize: draft.baseServingSize,
                        baseServingUnitName: draft.baseServingUnitName,
                        baseServingWeight: draft.baseServingWeight,
                        baseServingWeightUnit: draft.baseServingWeightUnit,
                        baseCalories: draft.baseCalories,
                        baseProtein: draft.baseProtein,
                        baseCarbs: draft.baseCarbs,
                        baseFat: draft.baseFat,
                        baseFiber: draft.baseFiber
                    )
                    newIngredient.ingredientItem = draft.ingredientItem
                    newIngredient.parentRecipe = newRecipe
                    modelContext.insert(newIngredient)
                    newRecipe.recipeIngredients?.append(newIngredient)
                }
            }
        }

        if updatesOriginalPin {
            EntryHelper.applyPinnedNote(pinnedNote, to: recipe, in: modelContext)
        }

        DraftStore.delete(id: draftID, in: modelContext, save: false)

        do {
            try modelContext.save()
            didFinishLogging = true
            QuickLogger.finishLocation(
                of: mainLog,
                awaitingCurrent: locationSelection.isCurrent && location == nil,
                in: modelContext
            )

            if let toastCenter {
                toastCenter.show(
                    .entryLogged(
                        LogUndoRecord(
                            entry: mainLog,
                            originalFood: originalRecipe,
                            createdFood: createdRecipe,
                            createdListItems: createdListItems,
                            draft: draftRecord
                        ),
                        title: String(localized: "Recipe Logged"),
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
                .failure(String(localized: "Couldn't Log Recipe"), message: mainLog.name)
            )
            modelContext.rollback()
            savePrompt = nil
        }
    }

    private var draftState: LogRecipeDraftState {
        let draftLocation = locationSelection.draftLocation
        return LogRecipeDraftState(
            name: name,
            sourceSelection: sourceSelection,
            categorySelection: categorySelection,
            date: date,
            time: time,
            location: draftLocation.location,
            usesCurrentLocation: draftLocation.usesCurrentLocation,
            portionQuantity: portionQuantity,
            portionUnitSelection: portionUnitSelection,
            ingredients: draftIngredients.map { DraftIngredientSnapshot($0) },
            notes: DraftNoteState(
                stickyNote: stickyNote,
                newNote: newNote
            ),
            saveOptionRawValue: saveOption.rawValue
        )
    }

    @discardableResult
    private func saveDraft() -> Bool {
        do {
            let draft = try DraftStore.upsert(
                id: draftID,
                kind: .logRecipe,
                type: recipe.type,
                name: name.isEmpty ? recipe.name : name,
                timestamp: combineDateAndTime(date: date, time: time),
                foodItem: recipe,
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
                name: name.isEmpty ? recipe.name : name,
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
        recipe: FoodItem,
        previousEntry: LoggedEntry? = nil,
        draft: EntryDraft? = nil,
        isPushedView: Bool = false,
    ) {
        self.recipe = recipe
        self.isPushedView = isPushedView

        _name = State(initialValue: previousEntry?.name ?? recipe.name)
        self.previousMacros = previousEntry.map { MacroSanityCheck.Values($0) }

        let startSource = recipe.source?.source ?? ""
        let startCategory = recipe.category?.category ?? ""

        self.initialSourceSelection = startSource
        self.initialCategorySelection = startCategory

        _sourceSelection = State(
            initialValue: previousEntry?.source?.source ?? startSource
        )
        _categorySelection = State(
            initialValue: previousEntry?.category?.category ?? startCategory
        )

        let startingLocation = LocationSelection.defaultForNewLog(
            food: recipe,
            repeating: previousEntry
        )
        self.initialLocationSelection = startingLocation
        _locationSelection = State(initialValue: startingLocation)

        let startingPortionDouble: Double
        if recipe.isCustomDefaultServing, let custom = recipe.customServingSize
        {
            startingPortionDouble = custom
        } else {
            startingPortionDouble = recipe.servingSize
        }

        let startPortionQuantity = String(format: "%g", startingPortionDouble)
        let startPortionUnit = recipe.servingUnit?.unit ?? "serving"

        self.initialPortionQuantity = startPortionQuantity
        self.initialPortionUnitSelection = startPortionUnit

        _portionQuantity = State(
            initialValue: previousEntry.map {
                EntryHelper.format($0.loggedQuantity)
            } ?? startPortionQuantity
        )
        _portionUnitSelection = State(
            initialValue: previousEntry?.loggedUnit ?? startPortionUnit
        )

        self.isCustomDefaultServing = recipe.isCustomDefaultServing
        self.customServingSize = EntryHelper.format(recipe.customServingSize)
        self.servingWeight = EntryHelper.format(recipe.servingWeight)
        self.servingWeightUnit = recipe.servingWeightUnit

        let existingIngredients =
            recipe.recipeIngredients?
            .sorted(by: { $0.displayOrder < $1.displayOrder })
            .map { LogRecipeIngredient(recipeIngredient: $0) } ?? []

        _initialIngredients = State(initialValue: existingIngredients)
        _draftIngredients = State(
            initialValue: previousEntry.map {
                LogRecipeIngredient.makeDrafts(for: $0)
            } ?? existingIngredients
        )

        self.originalNoteText = recipe.stickyNote?.text ?? ""
        _stickyNote = State(initialValue: originalNoteText)
        self.stickyNoteDate = recipe.stickyNote?.lastUpdated

        _newNote = State(initialValue: "")

        _dateAdded = State(initialValue: recipe.dateAdded)

        _selectedPhotos = State(initialValue: [])

        _draftID = State(initialValue: draft?.id ?? UUID())
        self.isResumedDraft = draft != nil

        if let draft, let state = draft.decodeState(LogRecipeDraftState.self) {
            _name = State(initialValue: state.name)
            _sourceSelection = State(initialValue: state.sourceSelection)
            _categorySelection = State(initialValue: state.categorySelection)

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

            let items = DraftStore.foodItems(
                for: state.ingredients,
                in: draft.modelContext
            )
            _draftIngredients = State(
                initialValue: state.ingredients.map { snapshot in
                    LogRecipeIngredient(
                        snapshot: snapshot,
                        item: snapshot.foodItemID.flatMap { items[$0] }
                    )
                }
            )

            _stickyNote = State(initialValue: state.notes.stickyNote)
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

    private var form: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            ScrollView {
                VStack {
                    Card {
                        RowGroup(.divider) {
                            DropdownPillRow(
                                title: "Source",
                                options: mappedSourceOptions,
                                selection: $sourceSelection
                            )
                            DropdownPillRow(
                                title: "Category",
                                options: mappedCategoryOptions,
                                selection: $categorySelection
                            )
                            DateTimePillRow(
                                title: "Date & Time",
                                dateSelection: $date,
                                timeSelection: $time
                            )
                            LocationRow(
                                selection: $locationSelection,
                                food: recipe,
                                photos: selectedPhotos,
                                logDate: date,
                                nearbyName: DefaultLocationResolver.nearbyName(
                                    for: recipe,
                                    in: modelContext
                                )
                            )
                        }
                    }
                    .padding([.leading, .trailing])

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

                    Card {
                        BaseRowLayout(title: "Portion") {
                            HStack(spacing: 8) {
                                InputPill(
                                    text: $portionQuantity,
                                    keyboardType: .decimalPad
                                )
                                DropdownPill(
                                    options: availableUnits,
                                    displayCustomOption: false,
                                    selection: $portionUnitSelection
                                )
                            }
                        }
                    }
                    .padding([.leading, .trailing])

                    Card("Ingredients") {
                        RowGroup(.divider) {
                            ForEach($draftIngredients) { $draft in
                                IngredientRowView(
                                    draft: $draft,
                                    portionUnitOptions: portionUnitOptions,
                                    shouldShowIngredientIcons:
                                        shouldShowIngredientIcons,
                                    onDelete: {
                                        if let index =
                                            draftIngredients.firstIndex(
                                                where: { $0.id == draft.id }
                                            )
                                        {
                                            withAnimation(.snappy) {
                                                _ = draftIngredients.remove(
                                                    at: index
                                                )
                                            }
                                        }
                                    }
                                )
                            }
                        } bottomContent: {
                            ButtonRow(
                                icon: .customSymbol("plus.circle.fill"),
                                title: "Add Ingredient"
                            ) {
                                showIngredientSelectionSheet = true
                            }
                        }
                    }
                    .padding([.top, .leading, .trailing])

                    Spacer()
                }
            }
            .withCustomKeyboardToolbar()
            .navigationTitle("Log Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showIngredientSelectionSheet) {
                IngredientSelectionView(
                    inRecipeIDs: Set(
                        draftIngredients.compactMap(\.ingredientItem?.id)
                    ),
                    excludedRecipe: recipe
                ) { selectedItems in
                    draftIngredients.append(
                        contentsOf: selectedItems.map {
                            LogRecipeIngredient(item: $0)
                        }
                    )
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .cancellationAction) {
                    if !isPushedView {
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
                                    name = recipe.name
                                    draftIngredients = initialIngredients
                                    sourceSelection = initialSourceSelection
                                    categorySelection =
                                        initialCategorySelection
                                    portionQuantity = initialPortionQuantity
                                    portionUnitSelection =
                                        initialPortionUnitSelection
                                    locationSelection = initialLocationSelection

                                    stickyNote = originalNoteText
                                    newNote = ""

                                    selectedPhotos = []
                                    isLoadingPhotos = false

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
                    .disabled(isLoadingPhotos)
                    .savePromptPopover(
                        $savePrompt,
                        dismissesScreen: rootDismiss != nil || !isPushedView
                    )
                }
            }
            .safeAreaBar(edge: .top) {
                Card {
                    MealRow(
                        name: name.isEmpty ? "New Recipe" : name,
                        source: sourceSelection,
                        isCustomDefaultServing: false,
                        customServingSize: "",
                        servingSize: displayServingSize,
                        servingSizeUnit: recipe.servingUnit?.unit
                            ?? "serving",
                        servingWeight: displayServingWeight,
                        servingWeightUnit: recipe.servingWeightUnit,
                        servingUnits: portionUnitOptions.filter {
                            availableUnits.contains($0.unit)
                        },
                        calorie: EntryHelper.format(displayCalories),
                        protein: EntryHelper.format(displayProtein),
                        carbs: EntryHelper.format(displayCarbs),
                        fat: EntryHelper.format(displayFat),
                        fiber: EntryHelper.format(displayFiber)
                    )
                    .nameLineLimit(3)
                }
                .padding([.leading, .trailing])
                .padding(.bottom, 24)
            }
        }
        .environment(focusManager)
        .onAppear {
            if initialDraftState == nil {
                initialDraftState = draftState
                initialPhotoData = selectedPhotos.map(\.originalData)
                initialLocation = locationSelection
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background && !didFinishLogging {
                autoSaveDraft()
            }
        }
        .onLeave { handleClose() }
        .onDisappear { handleClose() }
        .onDraftDeleted(id: draftID, isEnabled: isResumedDraft) {
            guard !didFinishLogging else { return }
            didFinishLogging = true
            dismiss()
        }
        .sheet(isPresented: $showingAllNotes) {
            NotesHistoryView(food: recipe)
        }
        .sheet(isPresented: $showingAllPhotos) {
            PhotoHistoryView(food: recipe)
        }            .task {
            hasPhotoHistory = FoodItemStore.hasPhotoHistory(
                for: recipe,
                in: modelContext
            )
        }
        .onChange(of: portionUnitSelection) { oldUnit, newUnit in
            guard !isResettingPortion, oldUnit != newUnit,
                totalRecipeWeight > 0
            else { return }
            let currentQuantity = Double(portionQuantity) ?? 0
            let baseUnit = recipe.servingUnit?.unit ?? "serving"

            if oldUnit == baseUnit && newUnit == recipe.servingWeightUnit {
                let newQuantity =
                    (currentQuantity / recipe.servingSize)
                    * totalRecipeWeight
                portionQuantity = newQuantity.formatted(
                    .number.precision(.fractionLength(0...2))
                )

            } else if oldUnit == recipe.servingWeightUnit
                && newUnit == baseUnit
            {
                let newQuantity =
                    (currentQuantity / totalRecipeWeight)
                    * recipe.servingSize
                portionQuantity = newQuantity.formatted(
                    .number.precision(.fractionLength(0...2))
                )
            }
        }
        .onChange(of: isEdited) { oldVal, newVal in
            if !newVal && saveOption != .logOnly {
                saveOption = .logOnly
            }
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
            category: "Lunch",
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

        let dummyIngredient = FoodItem(
            name: "Oatmeal",
            type: .food,
            source: defaultSource,
            category: defaultCategory,
            servingSize: 0.5,
            servingUnit: defaultUnit,
            servingWeight: 40,
            servingWeightUnit: "g",
            isAIEstimated: false,
            calories: 150,
            protein: 5,
            carbs: 27,
            fat: 2.5,
            fiber: 4,
            isCustomDefaultServing: false
        )

        container.mainContext.insert(dummyIngredient)

        let dummyRecipe = FoodItem(
            name: "Protein Oats",
            type: .recipe,
            source: defaultSource,
            category: defaultCategory,
            servingSize: 1,
            servingUnit: defaultUnit,
            servingWeight: nil,
            servingWeightUnit: "g",
            isAIEstimated: false,
            calories: 150,
            protein: 5,
            carbs: 27,
            fat: 2.5,
            fiber: 4,
            isCustomDefaultServing: false
        )

        let dummyRecipeIngredient = RecipeIngredient(
            quantity: 0.5,
            unit: "serving",
            displayOrder: 0,
            name: dummyIngredient.name,
            baseServingSize: dummyIngredient.servingSize,
            baseServingUnitName: dummyIngredient.servingUnit?.unit,
            baseServingWeight: dummyIngredient.servingWeight,
            baseServingWeightUnit: dummyIngredient.servingWeightUnit,
            baseCalories: dummyIngredient.calories,
            baseProtein: dummyIngredient.protein,
            baseCarbs: dummyIngredient.carbs,
            baseFat: dummyIngredient.fat,
            baseFiber: dummyIngredient.fiber
        )
        dummyRecipeIngredient.ingredientItem = dummyIngredient
        dummyRecipeIngredient.parentRecipe = dummyRecipe

        dummyRecipe.recipeIngredients = [dummyRecipeIngredient]

        container.mainContext.insert(dummyRecipe)
        container.mainContext.insert(dummyRecipeIngredient)

        return LogRecipeView(recipe: dummyRecipe)
            .modelContainer(container)

    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
