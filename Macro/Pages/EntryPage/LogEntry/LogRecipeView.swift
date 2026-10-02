//
//  LogRecipeView.swift
//  Macro
//
//  Created by Shrey Gangwar on 2026-05-20.
//

import SwiftData
import SwiftUI

// TODO: FIX BUG WHERE ADDING FOOD WITH 2 DEFAULT SERVING THEN CHANGING IN LOG FOOD, IF CHANGE SERVING TO 1 THEN 2 IT DOUBLES SERVING FIX THIS

struct LogRecipeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.rootDismiss) var rootDismiss
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \EntrySource.displayOrder) var sourceOptions: [EntrySource]
    @Query(sort: \CategorySource.displayOrder) var categoryOptions:
        [CategorySource]
    @Query(sort: \ServingSizeUnit.displayOrder) var portionUnitOptions:
        [ServingSizeUnit]

    let recipe: FoodItem
    @State private var name: String
    var isPushedView: Bool = true

    private let isCustomDefaultServing: Bool
    private let customServingSize: String
    private let servingWeight: String
    private let servingWeightUnit: String

    @State private var sourceSelection: String
    @State private var categorySelection: String

    @State private var date = Date()
    @State private var time = Date()
    @State private var location: String

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
    @State private var didFinishLogging = false

    @State private var initialDraftState: LogRecipeDraftState?
    @State private var initialPhotoData: [Data] = []

    @State private var focusManager = SwipeFocusManager()

    @State private var stickyNote: String
    @State private var stickyNoteDate: Date

    private let originalNoteText: String

    @State private var newNote: String
    @State private var isAddingNewNote: Bool
    @State private var isNewNotePinned: Bool = false
    @State private var isOriginalNotePinned: Bool

    @State private var showingAllNotes: Bool = false
    @State private var dateAdded: Date

    @State private var selectedPhotos: [LoggedPhoto]

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
            || isAddingNewNote
            || !selectedPhotos.isEmpty
    }

    var mappedSourceOptions: [String] {
        [""]
            + sourceOptions.map { $0.source }.filter {
                let trimmed = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                return !trimmed.isEmpty && trimmed != "-"
            }
    }

    var mappedCategoryOptions: [String] {
        [""]
            + categoryOptions.map { $0.category }.filter {
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
        let currentPortion = Double(portionQuantity) ?? 0

        let isWeightSelected =
            (portionUnitSelection == recipe.servingWeightUnit
                && totalRecipeWeight > 0)
        let basePortion =
            isWeightSelected ? totalRecipeWeight : recipe.servingSize

        return EntryHelper.calculateMultiplier(
            targetPortion: currentPortion,
            basePortion: basePortion
        )
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

        let mainLog = LoggedEntry(
            name: name.isEmpty ? "New Recipe" : name,
            typeRawValue: recipe.type.rawValue,
            originalFoodItem: recipe,
            parentEntry: nil,
            source: resolvedSource,
            category: resolvedCategory,
            timestamp: combinedDate,
            location: location.isEmpty ? nil : location,
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

        let photoEntities = selectedPhotos.enumerated().map { index, photo in
            EntryPhoto(
                imageData: photo.originalData,
                scale: Double(photo.scale),
                offsetX: Double(photo.offset.width),
                offsetY: Double(photo.offset.height),
                displayOrder: index,
            )
        }
        mainLog.photos = photoEntities

        modelContext.insert(mainLog)

        for (index, draft) in draftIngredients.enumerated() {
            let baseDraftQuantity = parseDouble(draft.quantity)
            let scaledQuantity = baseDraftQuantity * activeMultiplier

            let ingredientLog = LoggedEntry(
                name: draft.name,
                typeRawValue: "ingredient",
                originalFoodItem: draft.ingredientItem,
                parentEntry: mainLog,
                timestamp: combinedDate,
                location: location.isEmpty ? nil : location,
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

                if let resolvedNote = resolvedNote {
                    if let existingNote = recipe.stickyNote {
                        existingNote.text = resolvedNote
                    } else {
                        recipe.stickyNote = Note(text: resolvedNote)
                    }
                } else if let existingNote = recipe.stickyNote {
                    modelContext.delete(existingNote)
                    recipe.stickyNote = nil
                }

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
                    stickyNote: resolvedNote != nil
                        ? Note(text: resolvedNote!) : nil
                )

                modelContext.insert(newRecipe)

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
            print("Failed to save recipe entry: \(error.localizedDescription)")
        }
    }

    private var draftState: LogRecipeDraftState {
        LogRecipeDraftState(
            name: name,
            sourceSelection: sourceSelection,
            categorySelection: categorySelection,
            date: date,
            time: time,
            location: location,
            portionQuantity: portionQuantity,
            portionUnitSelection: portionUnitSelection,
            ingredients: draftIngredients.map(DraftIngredientSnapshot.init),
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
            kind: .logRecipe,
            type: recipe.type,
            name: name.isEmpty ? recipe.name : name,
            timestamp: combineDateAndTime(date: date, time: time),
            foodItem: recipe,
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
        recipe: FoodItem,
        previousEntry: LoggedEntry? = nil,
        draft: EntryDraft? = nil,
        isPushedView: Bool = true,
    ) {
        self.recipe = recipe
        self.isPushedView = isPushedView

        _name = State(initialValue: previousEntry?.name ?? recipe.name)

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

        _location = State(initialValue: previousEntry?.location ?? "TODO")

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
        _isOriginalNotePinned = State(initialValue: !originalNoteText.isEmpty)
        _stickyNoteDate = State(
            initialValue: recipe.stickyNote?.lastUpdated ?? Date()
        )

        // The logged entry's own note is only a distinct "new" note if it
        // differs from the recipe's pinned note; otherwise it's just the
        // pinned note carried over unchanged
        let loggedNote = previousEntry?.logNote ?? ""
        let hasDistinctLoggedNote =
            !loggedNote.isEmpty && loggedNote != originalNoteText
        _newNote = State(initialValue: hasDistinctLoggedNote ? loggedNote : "")
        _isAddingNewNote = State(initialValue: hasDistinctLoggedNote)

        _dateAdded = State(initialValue: recipe.dateAdded)

        _selectedPhotos = State(
            initialValue: EntryHelper.loggedPhotos(from: previousEntry?.photos)
        )

        _draftID = State(initialValue: draft?.id ?? UUID())
        self.isResumedDraft = draft != nil

        if let draft, let state = draft.decodeState(LogRecipeDraftState.self) {
            _name = State(initialValue: state.name)
            _sourceSelection = State(initialValue: state.sourceSelection)
            _categorySelection = State(initialValue: state.categorySelection)

            _date = State(initialValue: state.date)
            _time = State(initialValue: state.time)
            _location = State(initialValue: state.location)

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
                                PillRow(title: "Location", text: $location)
                            }
                        }
                        .padding([.leading, .trailing])

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
                                        selection: $portionUnitSelection
                                    )
                                }
                            }
                        }
                        .padding([.top, .leading, .trailing])

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
                                                draftIngredients.remove(
                                                    at: index
                                                )
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

                        PhotoPickerCard(images: $selectedPhotos)

                        Spacer()
                    }
                }
                .withCustomKeyboardToolbar()
                .navigationTitle("Log Recipe")
                .navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $showIngredientSelectionSheet) {
                    IngredientSelectionView { selectedItem in
                        draftIngredients.append(
                            LogRecipeIngredient(item: selectedItem)
                        )
                        showIngredientSelectionSheet = false
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .cancellationAction) {
                        if !isPushedView {
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
                                        name = recipe.name
                                        draftIngredients = initialIngredients
                                        sourceSelection = initialSourceSelection
                                        categorySelection =
                                            initialCategorySelection
                                        portionQuantity = initialPortionQuantity
                                        portionUnitSelection =
                                            initialPortionUnitSelection
                                        location = "TODO"

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
                .safeAreaInset(edge: .top) {
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
                    }
                    .padding([.leading, .trailing])
                    .padding(.bottom, 16)
                    .background(.ultraThinMaterial)
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

        return LogRecipeView(recipe: dummyRecipe, isPushedView: false)
            .modelContainer(container)

    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
