//
//  LogEntryView.swift
//  Macro
//
//  Created by Priyanka Sangha on 2026-05-10.
//

import SwiftData
import SwiftUI

struct LogEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.rootDismiss) var rootDismiss
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var focusManager = SwipeFocusManager()

    @Query(sort: \EntrySource.displayOrder) var sourceOptions: [EntrySource]
    @Query(sort: \CategorySource.displayOrder) var categoryOptions:
        [CategorySource]
    @Query(sort: \FoodGroupSource.displayOrder) var foodGroupOptions:
        [FoodGroupSource]
    @Query(sort: \ServingSizeUnit.displayOrder) var portionUnitOptions:
        [ServingSizeUnit]

    let food: FoodItem
    @State private var name: String
    var isPushedView: Bool = true

    private let isCustomDefaultServing: Bool
    private let customServingSize: String
    private let servingWeight: String
    private let servingWeightUnit: String

    @State private var sourceSelection: String
    @State private var categorySelection: String
    @State private var foodGroupSelection: String

    @State private var date = Date()
    @State private var time = Date()
    @State private var location: String

    @State private var portionQuantity: String
    @State private var portionUnitSelection: String

    private let originalPortionQuantity: String
    private let originalPortionUnitSelection: String

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

    @State private var calorie: String
    @State private var protein: String
    @State private var carbs: String
    @State private var fat: String
    @State private var fiber: String

    @State private var manualOverrideToggle: Bool

    @State private var stickyNote: String
    @State private var stickyNoteDate: Date

    private let originalNoteText: String

    @State private var newNote: String
    @State private var isAddingNewNote: Bool
    @State private var isNewNotePinned: Bool = false
    @State private var isOriginalNotePinned: Bool

    @State private var showingAllNotes: Bool = false

    @State private var selectedPhotos: [LoggedPhoto]

    @State private var dateAdded: Date

    @State private var saveOption: LogSaveOption = .logOnly

    @State private var isResettingPortion = false

    @State private var draftID: UUID
    private let isResumedDraft: Bool
    @State private var didFinishLogging = false

    @State private var initialDraftState: LogEntryDraftState?
    @State private var initialPhotoData: [Data] = []

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
            || stickyNote != originalNoteText
            || isAddingNewNote
            || !selectedPhotos.isEmpty
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
            units.append(food.servingWeightUnit)
        }

        return units
    }

    private var activeMultiplier: Double {
        let currentPortion = Double(portionQuantity) ?? 0

        let isWeightSelected =
            (portionUnitSelection == food.servingWeightUnit
                && food.servingWeight != nil)
        let basePortion =
            isWeightSelected ? food.servingWeight! : food.servingSize

        return EntryHelper.calculateMultiplier(
            targetPortion: currentPortion,
            basePortion: basePortion
        )
    }

    private var displayServingSize: String {
        let size = activeMultiplier * food.servingSize
        return size.formatted(.number.precision(.fractionLength(0...2)))
    }

    private var displayServingWeight: String {
        guard let weight = food.servingWeight else { return "" }
        let scaledWeight = activeMultiplier * weight
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

    private func parseDouble(_ string: String) -> Double {
        let normalized = string.replacingOccurrences(of: ",", with: ".")
        return Double(normalized) ?? 0.0
    }

    private func saveEntry() {
        let combinedDate = combineDateAndTime(date: date, time: time)

        let noteToSave = isAddingNewNote ? newNote : stickyNote
        let trimmedNote = noteToSave.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let resolvedNote = trimmedNote.isEmpty ? nil : trimmedNote

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
            location: location.isEmpty ? nil : location,
            loggedQuantity: parseDouble(portionQuantity),
            loggedUnit: portionUnitSelection,
            calories: parseDouble(calorie),
            protein: parseDouble(protein),
            carbs: parseDouble(carbs),
            fat: parseDouble(fat),
            fiber: parseDouble(fiber),
            isManualOverride: manualOverrideToggle,
            logNote: resolvedNote
        )

        let photoEntities = selectedPhotos.enumerated().map { index, photo in
            EntryPhoto(
                imageData: photo.originalData,
                scale: Double(photo.scale),
                offsetX: Double(photo.offset.width),
                offsetY: Double(photo.offset.height),
                displayOrder: index,
            )
        }
        newLog.photos = photoEntities

        modelContext.insert(newLog)

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
                }

                if let resolvedNote = resolvedNote {
                    if let existingNote = food.stickyNote {
                        existingNote.text = resolvedNote
                    } else {
                        food.stickyNote = Note(text: resolvedNote)
                    }
                } else if let existingNote = food.stickyNote {
                    modelContext.delete(existingNote)
                    food.stickyNote = nil
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
                    stickyNote: resolvedNote != nil
                        ? Note(text: resolvedNote!) : nil
                )
                modelContext.insert(newFood)

                newLog.originalFoodItem = newFood
            }
        }

        DraftStore.delete(id: draftID, in: modelContext, save: false)

        do {
            try modelContext.save()
            didFinishLogging = true

            if let rootDismiss {
                rootDismiss()
            } else {
                dismiss()
            }
        } catch {
            print("Failed to save logged entry: \(error.localizedDescription)")
        }
    }

    private var draftState: LogEntryDraftState {
        LogEntryDraftState(
            name: name,
            sourceSelection: sourceSelection,
            categorySelection: categorySelection,
            foodGroupSelection: foodGroupSelection,
            date: date,
            time: time,
            location: location,
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
            notes: DraftNoteState(
                stickyNote: stickyNote,
                newNote: newNote,
                isAddingNewNote: isAddingNewNote,
                isNewNotePinned: isNewNotePinned,
                isOriginalNotePinned: isOriginalNotePinned
            ),
            saveOptionRawValue: saveOption.rawValue
        )
    }

    private func saveDraft() {
        DraftStore.upsert(
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
    }

    private var hasDraftChanges: Bool {
        guard let initialDraftState else { return false }
        return draftState != initialDraftState
            || selectedPhotos.map(\.originalData) != initialPhotoData
    }

    private func autoSaveDraft() {
        if isResumedDraft || hasDraftChanges {
            saveDraft()
        } else {
            DraftStore.delete(id: draftID, in: modelContext)
        }
    }

    private func saveDraftAndClose() {
        saveDraft()
        didFinishLogging = true
        dismiss()
    }

    private func discardAndClose() {
        DraftStore.delete(id: draftID, in: modelContext)
        didFinishLogging = true
        dismiss()
    }

    init(
        food: FoodItem,
        previousEntry: LoggedEntry? = nil,
        draft: EntryDraft? = nil,
        isPushedView: Bool = true,
    ) {
        self.food = food
        self.isPushedView = isPushedView

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

        _location = State(initialValue: previousEntry?.location ?? "TODO")

        let startingPortionDouble: Double
        if food.isCustomDefaultServing, let custom = food.customServingSize {
            startingPortionDouble = custom
        } else {
            startingPortionDouble = food.servingSize
        }

        let defaultPortionQuantity = String(format: "%g", startingPortionDouble)
        let defaultPortionUnit = food.servingUnit?.unit ?? "serving"

        self.originalPortionQuantity = defaultPortionQuantity
        self.originalPortionUnitSelection = defaultPortionUnit

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

        let initialCalorie =
            previousEntry.map { EntryHelper.format($0.calories) } ?? calStr
        let initialProtein =
            previousEntry.map { EntryHelper.format($0.protein) } ?? proStr
        let initialCarbs =
            previousEntry.map { EntryHelper.format($0.carbs) } ?? carbStr
        let initialFat =
            previousEntry.map { EntryHelper.format($0.fat) } ?? fatStr
        let initialFiber =
            previousEntry.map { EntryHelper.format($0.fiber) } ?? fibStr

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

        self.originalNoteText = food.stickyNote?.text ?? ""
        _stickyNote = State(initialValue: originalNoteText)
        _isOriginalNotePinned = State(initialValue: !originalNoteText.isEmpty)
        _stickyNoteDate = State(
            initialValue: food.stickyNote?.lastUpdated ?? Date()
        )

        let loggedNote = previousEntry?.logNote ?? ""
        let hasDistinctLoggedNote =
            !loggedNote.isEmpty && loggedNote != originalNoteText
        _newNote = State(initialValue: hasDistinctLoggedNote ? loggedNote : "")
        _isAddingNewNote = State(initialValue: hasDistinctLoggedNote)

        _selectedPhotos = State(
            initialValue: EntryHelper.loggedPhotos(from: previousEntry?.photos)
        )

        _dateAdded = State(initialValue: food.dateAdded)

        _draftID = State(initialValue: draft?.id ?? UUID())
        self.isResumedDraft = draft != nil

        if let draft, let state = draft.decodeState(LogEntryDraftState.self) {
            _name = State(initialValue: state.name)
            _sourceSelection = State(initialValue: state.sourceSelection)
            _categorySelection = State(initialValue: state.categorySelection)
            _foodGroupSelection = State(initialValue: state.foodGroupSelection)

            _date = State(initialValue: state.date)
            _time = State(initialValue: state.time)
            _location = State(initialValue: state.location)

            _portionQuantity = State(initialValue: state.portionQuantity)
            _portionUnitSelection = State(
                initialValue: state.portionUnitSelection
            )

            _manualOverrideToggle = State(
                initialValue: state.manualOverrideToggle
            )

            let macros: DraftMacroValues
            let dynamicMacros: DraftMacroValues
            if state.manualOverrideToggle {
                macros = state.macros
                dynamicMacros = state.dynamicMacros
            } else {
                let isWeightSelected =
                    state.portionUnitSelection == food.servingWeightUnit
                    && food.servingWeight != nil
                let multiplier = EntryHelper.calculateMultiplier(
                    targetPortion: Double(state.portionQuantity) ?? 0,
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

            _stickyNote = State(initialValue: state.notes.stickyNote)
            _newNote = State(initialValue: state.notes.newNote)
            _isAddingNewNote = State(initialValue: state.notes.isAddingNewNote)
            _isNewNotePinned = State(initialValue: state.notes.isNewNotePinned)
            _isOriginalNotePinned = State(
                initialValue: state.notes.isOriginalNotePinned
            )

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

    var body: some View {
        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()

                ScrollView {
                    VStack {
                        Card {
                            RowGroup(.divider) {
                                DropdownPillRow(
                                    title: "Source",
                                    options: [""]
                                        + sourceOptions.map { $0.source }.filter
                                    {
                                        !$0.trimmingCharacters(
                                            in: .whitespacesAndNewlines
                                        ).isEmpty
                                    },
                                    selection: $sourceSelection
                                )

                                if food.type == .food {
                                    DropdownPillRow(
                                        title: "Category",
                                        options: [""]
                                            + categoryOptions.map {
                                                $0.category
                                            }.filter {
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
                                            + foodGroupOptions.map {
                                                $0.foodGroup
                                            }.filter {
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

                                PillRow(title: "Location", text: $location)
                            }
                        }
                        .padding([.leading, .trailing])

                        // TODO: make view all notes button only appear if there is previously logged entries with notes (TODO after logging implemented)

                        // TODO: think deeply about how to handle time stamps and editing pinned / previous notes. Very complex problem. Like if i edit sticky note does timestamp update to latest? does it stay old? also, do we grey it out and have them swipe on row to edit / unpin

                        Card {
                            RowGroup(.divider) {
                                if !stickyNote.isEmpty {
                                    let deleteOriginalNoteAction: () -> Void = {
                                        withAnimation(
                                            .spring(
                                                response: 0.3,
                                                dampingFraction: 0.8
                                            )
                                        ) {
                                            stickyNote = ""
                                            isOriginalNotePinned = false
                                        }
                                    }

                                    let pinOriginalNoteAction: () -> Void = {
                                        withAnimation {
                                            isOriginalNotePinned.toggle()
                                            if isOriginalNotePinned {
                                                isNewNotePinned = false
                                            }
                                        }
                                    }

                                    CustomSwipeRow(
                                        content: {
                                            WrappedInputRow(
                                                placeholder: "Sticky Note",
                                                text: $stickyNote,
                                                isSticky: isOriginalNotePinned,
                                                timestamp: stickyNoteDate
                                            )
                                        },
                                        onDelete: deleteOriginalNoteAction,
                                        onPin: pinOriginalNoteAction,
                                        isPinned: isOriginalNotePinned
                                    )
                                    .transition(
                                        .opacity.combined(
                                            with: .move(edge: .top)
                                        )
                                    )
                                }

                                if isAddingNewNote {
                                    let deleteNoteAction: () -> Void = {
                                        withAnimation(
                                            .spring(
                                                response: 0.3,
                                                dampingFraction: 0.8
                                            )
                                        ) {
                                            isAddingNewNote = false
                                            newNote = ""
                                            isNewNotePinned = false
                                        }
                                    }

                                    let pinNoteAction: () -> Void = {
                                        withAnimation {
                                            isNewNotePinned.toggle()
                                            if isNewNotePinned {
                                                isOriginalNotePinned = false
                                            }
                                        }
                                    }

                                    CustomSwipeRow(
                                        content: {
                                            WrappedInputRow(
                                                placeholder: "Add a note...",
                                                text: $newNote,
                                                isSticky: isNewNotePinned,
                                                timestamp: Date()
                                            )
                                        },
                                        onDelete: deleteNoteAction,
                                        onPin: pinNoteAction,
                                        isPinned: isNewNotePinned
                                    )
                                    .transition(
                                        .opacity.combined(
                                            with: .move(edge: .top)
                                        )
                                    )

                                    ButtonRow(
                                        title: "View All Notes",
                                        topPadding: 16,
                                        action: { showingAllNotes = true }
                                    )
                                    .transition(.opacity)

                                } else {
                                    DoubleButtonRow(
                                        topPadding: 16,
                                        leftTitle: "Add New Note",
                                        leftAction: {
                                            withAnimation(
                                                .spring(
                                                    response: 0.3,
                                                    dampingFraction: 0.8
                                                )
                                            ) {
                                                isAddingNewNote = true
                                            }
                                        },
                                        rightTitle: "View All Notes",
                                        rightAction: {
                                            showingAllNotes = true
                                        }
                                    )
                                }
                            }
                        }
                        .padding([.top, .leading, .trailing])

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
                                        selection: $portionUnitSelection,
                                    )
                                }
                            }
                        }
                        .padding([.top, .leading, .trailing])

                        Card {
                            RowGroup(.divider) {
                                TextInputRow(
                                    icon: .calorie,
                                    title: "Calories",
                                    titleExtension: "(Kcal)",
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

                                ToggleRow(
                                    title: "Manual Override",
                                    isOn: $manualOverrideToggle
                                )
                            }
                        }
                        .padding([.top, .leading, .trailing])

                        PhotoPickerCard(images: $selectedPhotos)

                        Spacer()
                    }
                }
                .safeAreaInset(edge: .top) {
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
                    }
                    .padding([.leading, .trailing])
                    .padding(.bottom, 16)
                    .background(.ultraThinMaterial)
                }
                .withCustomKeyboardToolbar()
                .scrollDismissesKeyboard(.immediately)
                .navigationTitle(
                    food.type == .food ? "Log Food" : "Log Ingredient"
                )
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if !isPushedView {
                        ToolbarItem(placement: .topBarLeading) {
                            DraftCloseButton(
                                isResumedDraft: isResumedDraft,
                                onClose: { dismiss() },
                                onSaveDraft: saveDraftAndClose,
                                onDiscard: discardAndClose
                            )
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

                            Divider()

                            Button(
                                "Save as Draft",
                                systemImage: "square.and.arrow.down",
                                action: saveDraftAndClose
                            )

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
                                        location = "TODO"

                                        portionQuantity =
                                            originalPortionQuantity
                                        portionUnitSelection =
                                            originalPortionUnitSelection

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

                                        stickyNote = originalNoteText
                                        isOriginalNotePinned =
                                            !originalNoteText.isEmpty
                                        isAddingNewNote = false
                                        newNote = ""
                                        isNewNotePinned = false

                                        selectedPhotos = []

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
                            saveEntry()
                        } label: {
                            Image(systemName: "plus")
                                .foregroundStyle(.primary)
                        }
                        .tint(Color.blue)
                        .buttonStyle(.glassProminent)
                    }
                }
                .onChange(of: isEdited) { oldVal, newVal in
                    if !newVal && saveOption != .logOnly {
                        saveOption = .logOnly
                    }
                }
                .onChange(of: portionUnitSelection) { oldUnit, newUnit in
                    guard !isResettingPortion, oldUnit != newUnit,
                        let weight = food.servingWeight
                    else { return }
                    let currentQuantity = Double(portionQuantity) ?? 0
                    let baseUnit = food.servingUnit?.unit ?? "serving"

                    if oldUnit == baseUnit && newUnit == food.servingWeightUnit
                    {
                        let newQuantity =
                            (currentQuantity / food.servingSize) * weight
                        portionQuantity = newQuantity.formatted(
                            .number.precision(.fractionLength(0...2))
                        )

                    } else if oldUnit == food.servingWeightUnit
                        && newUnit == baseUnit
                    {
                        let newQuantity =
                            (currentQuantity / weight) * food.servingSize
                        portionQuantity = newQuantity.formatted(
                            .number.precision(.fractionLength(0...2))
                        )
                    }
                }
                .onChange(of: portionQuantity) { _, _ in
                    if !manualOverrideToggle {
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
                .onChange(of: isEdited) { oldVal, newVal in
                    if !newVal && saveOption != .logOnly {
                        saveOption = .logOnly
                    }
                }
            }
        }
        .environment(focusManager)
        .onAppear {
            if initialDraftState == nil {
                initialDraftState = draftState
                initialPhotoData = selectedPhotos.map(\.originalData)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background && !didFinishLogging {
                autoSaveDraft()
            }
        }
        .onDisappear {
            guard !didFinishLogging else { return }

            if isResumedDraft {
                saveDraft()
            } else {
                DraftStore.delete(id: draftID, in: modelContext)
            }
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
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
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
