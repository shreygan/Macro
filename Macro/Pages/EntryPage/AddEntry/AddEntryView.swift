//
//  AddEntryView.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/10/26.
//

import SwiftData
import SwiftUI

struct AddEntryView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.rootDismiss) var rootDismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.tracksHydration) private var tracksHydration
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.toastCenter) private var toastCenter

    let entryType: EntryType
    var isPushedView: Bool = false

    var onSelectInstantly: ((FoodItem) -> Void)?

    var offersLogNow: Bool
    var isDuplicate: Bool
    var onCreate: ((FoodItem) -> Void)?

    @Query(sort: \EntrySource.displayOrder) var savedSources: [EntrySource]
    @Query(sort: \CategorySource.displayOrder) var savedCategories:
        [CategorySource]
    @Query(sort: \FoodGroupSource.displayOrder) var savedFoodGroups:
        [FoodGroupSource]
    @Query(sort: \ServingSizeUnit.displayOrder) var servingUnits:
        [ServingSizeUnit]
    @Query private var users: [User]

    @State private var drinkForm = DrinkFormState(unit: .localeDefault)
    @State private var focusManager = SwipeFocusManager()

    @State private var name: String = ""
    @State private var source: String = ""
    @State private var defaultLocation: EntryLocation?
    @State private var category: String = ""
    @State private var foodGroup: String = ""

    @State private var servingSize: String = "1"
    @State private var servingSizeUnit: String = "serving"

    @State private var servingWeight: String = ""
    @State private var servingWeightUnit: String = "g"

    @State private var isAIEstimated: Bool = false

    @State private var calorieValue: String = ""
    @State private var proteinValue: String = ""
    @State private var carbsValue: String = ""
    @State private var fatValue: String = ""
    @State private var fiberValue: String = ""

    @State private var isCustomDefaultServing: Bool = false
    @State private var customServingSize: String = "1"

    @State private var stickyNote: String = ""

    @State private var draftID: UUID
    private let isResumedDraft: Bool
    private let initialDraftState: AddEntryDraftState
    @State private var didFinishAdding = false
    @State private var savePrompt: SavePromptStep?
    @State private var hasStartFromItems = false
    @State private var showsStartFrom = false
    @State private var showsDrinkIcon = false
    @State private var filledDetails: AddEntryDraftState
    @State private var copiedItem: AddEntryDraftState?
    @State private var selectsNameAfterPick = false
    @State private var nameSelectRequest = 0
    @State private var filledFromID: UUID?
    @State private var pendingSuggestion: NameSuggestions.Match?
    @State private var nameCursorRequest = 0
    @State private var filledName: String?
    @State private var isNameFocused = false
    @State private var confirmsClear = false
    private let pinsDrinkByDefault: Bool
    @State private var dismissedSuggestionName: String?
    @State private var nameMatches: [NameSuggestions.Match] = []

    init(
        entryType: EntryType,
        isPushedView: Bool = false,
        onSelectInstantly: ((FoodItem) -> Void)? = nil,
        offersLogNow: Bool = false,
        draft: EntryDraft? = nil,
        prefill: AddEntryDraftState? = nil,
        pinsDrink: Bool = false,
        duplicateOf: UUID? = nil,
        onCreate: ((FoodItem) -> Void)? = nil
    ) {
        self.entryType = entryType
        self.isPushedView = isPushedView
        self.onSelectInstantly = onSelectInstantly
        self.offersLogNow = offersLogNow
        self.isDuplicate = duplicateOf != nil
        self.pinsDrinkByDefault = pinsDrink
        _filledFromID = State(initialValue: duplicateOf)
        _filledName = State(initialValue: duplicateOf != nil ? prefill?.name : nil)
        _dismissedSuggestionName = State(initialValue: duplicateOf != nil ? prefill?.name : nil)
        self.onCreate = onCreate

        _draftID = State(initialValue: draft?.id ?? UUID())
        _drinkForm = State(initialValue: DrinkFormState(unit: .localeDefault, isPinned: pinsDrink))
        self.isResumedDraft = draft != nil
        self.initialDraftState = prefill ?? .empty
        var filled = Self.details(of: prefill ?? .empty)
        if duplicateOf == nil { filled.source = "" }
        _filledDetails = State(initialValue: filled)
        _copiedItem = State(initialValue: isDuplicate ? prefill : nil)

        if let state = draft?.decodeState(AddEntryDraftState.self) ?? prefill {
            _name = State(initialValue: state.name)
            _source = State(initialValue: state.source)
            _defaultLocation = State(initialValue: state.defaultLocation)
            _category = State(initialValue: state.category)
            _foodGroup = State(initialValue: state.foodGroup)
            _servingSize = State(initialValue: state.servingSize)
            _servingSizeUnit = State(initialValue: state.servingSizeUnit)
            _servingWeight = State(initialValue: state.servingWeight)
            _servingWeightUnit = State(initialValue: state.servingWeightUnit)
            _isAIEstimated = State(initialValue: state.isAIEstimated)
            _calorieValue = State(initialValue: state.macros.calories)
            _proteinValue = State(initialValue: state.macros.protein)
            _carbsValue = State(initialValue: state.macros.carbs)
            _fatValue = State(initialValue: state.macros.fat)
            _fiberValue = State(initialValue: state.macros.fiber)
            _isCustomDefaultServing = State(
                initialValue: state.isCustomDefaultServing
            )
            _customServingSize = State(initialValue: state.customServingSize)
            _stickyNote = State(initialValue: state.stickyNote)
            if let drink = state.drink {
                _drinkForm = State(initialValue: drink)
            }
        }
    }

    private var isDrink: Bool {
        entryType == .drink
    }

    private var isDraftEnabled: Bool {
        onSelectInstantly == nil && onCreate == nil
    }

    private var draftState: AddEntryDraftState {
        AddEntryDraftState(
            name: name,
            source: source,
            category: category,
            foodGroup: foodGroup,
            servingSize: servingSize,
            servingSizeUnit: servingSizeUnit,
            servingWeight: servingWeight,
            servingWeightUnit: servingWeightUnit,
            isAIEstimated: isAIEstimated,
            macros: DraftMacroValues(
                calories: calorieValue,
                protein: proteinValue,
                carbs: carbsValue,
                fat: fatValue,
                fiber: fiberValue
            ),
            isCustomDefaultServing: isCustomDefaultServing,
            customServingSize: customServingSize,
            stickyNote: stickyNote,
            defaultLocation: defaultLocation,
            drink: isDrink && !drinkForm.isPristine ? drinkForm : nil
        )
    }

    private static func details(of state: AddEntryDraftState) -> AddEntryDraftState {
        var details = state
        details.name = ""
        details.stickyNote = ""
        return details
    }

    private var hasTypedDetails: Bool {
        Self.details(of: draftState) != filledDetails
    }

    private func refreshNameMatches() {
        guard NameSuggestions.hasEnoughText(name) else {
            if !nameMatches.isEmpty { nameMatches = [] }
            return
        }
        let foods = (try? modelContext.fetch(FoodItem.descriptor(for: entryType))) ?? []
        nameMatches = NameSuggestions.suggestions(for: name, type: entryType, in: foods, excluding: filledFromID)
    }

    private var panelMatches: [NameSuggestions.Match] {
        guard isNameFocused, name != dismissedSuggestionName else { return [] }
        return nameMatches
    }

    private func applySuggestion(_ match: NameSuggestions.Match) {
        if hasTypedDetails {
            pendingSuggestion = match
        } else {
            fillFromSuggestion(match)
        }
    }

    private var keepsName: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name != filledName
    }

    private var typedSource: String? {
        let isTyped = !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && source != filledDetails.source
        return isTyped ? source : nil
    }

    private func fillFromSuggestion(_ match: NameSuggestions.Match) {
        startFrom(match.food)
        selectsNameAfterPick = false
        if match.fillsName {
            name = match.food.name
            filledName = match.food.name
            nameCursorRequest += 1
        }
        dismissedSuggestionName = name
    }

    private func startFrom(_ food: FoodItem) {
        let unit = users.first?.volumeUnit ?? drinkForm.unit
        let state = food.duplicatePrefill(unit: unit, pinsDrink: drinkForm.isPinned)
        if !keepsName {
            name = state.name
            filledName = state.name
            selectsNameAfterPick = true
        }
        source = state.source
        defaultLocation = state.defaultLocation
        category = state.category
        foodGroup = state.foodGroup
        servingSize = state.servingSize
        servingSizeUnit = state.servingSizeUnit
        servingWeight = state.servingWeight
        servingWeightUnit = state.servingWeightUnit
        isAIEstimated = state.isAIEstimated
        calorieValue = state.macros.calories
        proteinValue = state.macros.protein
        carbsValue = state.macros.carbs
        fatValue = state.macros.fat
        fiberValue = state.macros.fiber
        isCustomDefaultServing = state.isCustomDefaultServing
        customServingSize = state.customServingSize
        drinkForm = state.drink ?? DrinkFormState(unit: unit, isPinned: drinkForm.isPinned)
        filledDetails = Self.details(of: state)
        copiedItem = state
        filledFromID = food.id
        dismissedSuggestionName = name
    }

    private var canClearForm: Bool {
        draftState != .empty || (isDrink && drinkForm.isPinned != pinsDrinkByDefault)
    }

    private func clearForm() {
        let unit = users.first?.volumeUnit ?? drinkForm.unit
        let empty = AddEntryDraftState.empty
        name = empty.name
        source = empty.source
        defaultLocation = nil
        category = empty.category
        foodGroup = empty.foodGroup
        servingSize = empty.servingSize
        servingSizeUnit = empty.servingSizeUnit
        servingWeight = empty.servingWeight
        servingWeightUnit = empty.servingWeightUnit
        isAIEstimated = empty.isAIEstimated
        calorieValue = empty.macros.calories
        proteinValue = empty.macros.protein
        carbsValue = empty.macros.carbs
        fatValue = empty.macros.fat
        fiberValue = empty.macros.fiber
        isCustomDefaultServing = empty.isCustomDefaultServing
        customServingSize = empty.customServingSize
        stickyNote = empty.stickyNote
        drinkForm = DrinkFormState(unit: unit, isPinned: pinsDrinkByDefault)
        filledDetails = Self.details(of: empty)
        copiedItem = nil
        filledFromID = nil
        filledName = nil
        dismissedSuggestionName = nil
    }

    private func selectNameAfterPick() {
        guard selectsNameAfterPick else { return }
        selectsNameAfterPick = false
        nameSelectRequest += 1
    }

    @discardableResult
    private func saveDraft() -> Bool {
        let state = draftState
        guard state != .empty else {
            DraftStore.delete(id: draftID, in: modelContext)
            return false
        }

        do {
            try DraftStore.upsert(
                id: draftID,
                kind: .addFood,
                type: entryType,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                state: state,
                in: modelContext
            )
            return true
        } catch {
            toastCenter?.show(.failure(String(localized: "Couldn't Save Draft")))
            return false
        }
    }

    private func handleClose() {
        guard isDraftEnabled && !didFinishAdding else { return }
        didFinishAdding = true

        if isResumedDraft {
            saveDraft()
        } else {
            saveDraftOnClose()
        }
    }

    private func saveDraftOnClose() {
        guard draftState != initialDraftState, saveDraft() else {
            DraftStore.delete(id: draftID, in: modelContext)
            return
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        toastCenter?.show(
            .draftSaved(
                id: draftID,
                name: trimmedName.isEmpty
                    ? String(localized: "New \(entryType.rawValue.capitalized)")
                    : trimmedName,
                in: modelContext,
                presenter: toastCenter
            )
        )
    }

    private var activeMultiplier: Double {
        guard isCustomDefaultServing,
            let target = Double(customServingSize),
            let base = Double(servingSize)
        else {
            return 1.0
        }
        return EntryHelper.calculateMultiplier(
            targetPortion: target,
            basePortion: base
        )
    }

    private func attemptAdd() {
        if isDrink && !drinkForm.details.contains(.nutrition) {
            addEntry()
            return
        }
        let alcoholCalories = isDrink ? drinkForm.alcoholCaloriesPerServing?.rounded() : nil
        let issue = MacroSanityCheck.issue(
            for: MacroSanityCheck.Values(
                calories: calorieValue,
                protein: proteinValue,
                carbs: carbsValue,
                fat: fatValue,
                fiber: fiberValue,
                weight: isDrink
                    ? drinkForm.servingVolumeML
                    : Double(
                        servingWeight.replacingOccurrences(of: ",", with: ".")
                    ),
                weightUnit: isDrink ? VolumeUnit.milliliters.rawValue : servingWeightUnit
            ),
            alcoholCalories: alcoholCalories
        )
        if let issue, let alcoholCalories,
            issue == MacroSanityCheck.alcoholIssue(
                calories: Double(calorieValue.replacingOccurrences(of: ",", with: ".")) ?? 0,
                alcoholCalories: alcoholCalories
            )
        {
            savePrompt = .alcoholCheck(
                issue,
                alcoholCalories: alcoholCalories,
                onUse: {
                    calorieValue = EntryHelper.format(alcoholCalories)
                    addEntry()
                },
                onSaveAnyway: addEntry
            )
        } else if let issue {
            savePrompt = .macroCheck(issue, confirmTitle: "Save Anyway", onConfirm: addEntry)
        } else {
            addEntry()
        }
    }

    private func addEntry() {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            print("Validation Error: Name is required.")
            return
        }

        // SOURCE
        var resolvedSource: EntrySource? = nil
        let trimmedSource = source.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if !trimmedSource.isEmpty && trimmedSource != "-" {
            if let existing = savedSources.first(where: {
                $0.source == trimmedSource
            }) {
                resolvedSource = existing
            } else {
                let nextOrder =
                    (savedSources.map { $0.displayOrder }.max() ?? 0) + 1
                let newSource = EntrySource(
                    source: trimmedSource,
                    displayOrder: nextOrder
                )
                modelContext.insert(newSource)
                resolvedSource = newSource
            }
        }

        // CATEGORY
        var resolvedCategory: CategorySource? = nil
        if entryType == .food || isDrink {
            let trimmedCategory = category.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            if !trimmedCategory.isEmpty && trimmedCategory != "-" {
                if let existing = savedCategories.first(where: {
                    $0.category == trimmedCategory
                }) {
                    resolvedCategory = existing
                } else {
                    let nextOrder =
                        (savedCategories.map { $0.displayOrder }.max() ?? 0) + 1
                    let newCategory = CategorySource(
                        category: trimmedCategory,
                        displayOrder: nextOrder
                    )
                    modelContext.insert(newCategory)
                    resolvedCategory = newCategory
                }
            }
        }

        // FOOD GROUP
        var resolvedFoodGroup: FoodGroupSource? = nil
        if entryType == .ingredient {
            let trimmedGroup = foodGroup.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            if !trimmedGroup.isEmpty && trimmedGroup != "-" {
                if let existing = savedFoodGroups.first(where: {
                    $0.foodGroup == trimmedGroup
                }) {
                    resolvedFoodGroup = existing
                } else {
                    let nextOrder =
                        (savedFoodGroups.map { $0.displayOrder }.max() ?? 0) + 1
                    let newGroup = FoodGroupSource(
                        foodGroup: trimmedGroup,
                        isDefault: false,
                        displayOrder: nextOrder
                    )
                    modelContext.insert(newGroup)
                    resolvedFoodGroup = newGroup
                }
            }
        }

        // UNIT
        var resolvedUnit: ServingSizeUnit? = nil
        let trimmedUnit = servingSizeUnit.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if !trimmedUnit.isEmpty {
            if let existing = servingUnits.first(where: {
                $0.unit == trimmedUnit
            }) {
                resolvedUnit = existing
            } else {
                let nextOrder =
                    (servingUnits.map { $0.displayOrder }.max() ?? 0) + 1
                let newUnit = ServingSizeUnit(
                    unit: trimmedUnit,
                    displayOrder: nextOrder
                )
                modelContext.insert(newUnit)
                resolvedUnit = newUnit
            }
        }

        func parseDouble(_ string: String) -> Double {
            let normalized = string.replacingOccurrences(of: ",", with: ".")
            return Double(normalized) ?? 0.0
        }

        func parseOptionalDouble(_ string: String) -> Double? {
            let normalized = string.replacingOccurrences(of: ",", with: ".")
            return string.isEmpty ? nil : Double(normalized)
        }

        let trimmedNote = stickyNote.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let resolvedStickyNote =
            trimmedNote.isEmpty ? nil : Note(text: trimmedNote)

        let newEntry = FoodItem(
            name: name,
            type: entryType,
            source: resolvedSource,
            category: resolvedCategory,
            foodGroup: resolvedFoodGroup,
            servingSize: parseDouble(servingSize),
            servingUnit: resolvedUnit,
            servingWeight: parseOptionalDouble(servingWeight),
            servingWeightUnit: servingWeightUnit,
            isAIEstimated: isAIEstimated,
            calories: parseDouble(calorieValue),
            protein: parseDouble(proteinValue),
            carbs: parseDouble(carbsValue),
            fat: parseDouble(fatValue),
            fiber: parseDouble(fiberValue),
            isCustomDefaultServing: isCustomDefaultServing,
            customServingSize: parseOptionalDouble(customServingSize),
            defaultLocation: defaultLocation,
            stickyNote: resolvedStickyNote
        )

        modelContext.insert(newEntry)
        if isDrink {
            drinkForm.apply(to: newEntry, in: modelContext)
        }

        DraftStore.delete(id: draftID, in: modelContext, save: false)

        do {
            try modelContext.save()
            didFinishAdding = true

            if offersLogNow, let toastCenter {
                toastCenter.show(
                    .foodSaved(newEntry, in: modelContext, presenter: toastCenter)
                )
            }
            onCreate?(newEntry)
            if offersLogNow {
                if let rootDismiss {
                    rootDismiss()
                } else {
                    dismiss()
                }
            } else if let onSelectInstantly {
                onSelectInstantly(newEntry)
            } else {
                dismiss()
            }
        } catch {
            toastCenter?.show(
                .failure(String(localized: "Couldn't Save Food"), message: newEntry.name)
            )
            modelContext.rollback()
            savePrompt = nil
        }
    }

    @ViewBuilder
    private var libraryRows: some View {
        FullWidthDropdownRow(
            placeholder: "Source",
            options: [""]
                + savedSources.visibleNames(keeping: source).filter {
                    !$0.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty
                },
            selection: $source
        )

        DefaultLocationRow(
            location: $defaultLocation,
            sourceName: source
        )

        if entryType == .food || isDrink {
            FullWidthDropdownRow(
                placeholder: "Category",
                options: [""]
                    + savedCategories.visibleNames(keeping: category)
                    .filter {
                        !$0.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty
                    },
                selection: $category
            )
        } else {
            FullWidthDropdownRow(
                placeholder: "Food Group",
                options: [""]
                    + savedFoodGroups.visibleNames(keeping: foodGroup)
                    .filter {
                        !$0.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty
                    },
                selection: $foodGroup
            )
        }
    }

    private var pinnedNoteCard: some View {
        Card {
            WrappedInputRow(
                placeholder: "Pinned Note",
                text: $stickyNote,
                isEditable: true,
                characterLimit: 2000
            )
        }
        .padding([.top, .leading, .trailing])
    }

    var content: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            ScrollView {
                VStack {
                    Text(
                        entryType == .ingredient
                            ? "ingredient_description"
                            : isDrink ? "drink_description" : "food_description"
                    )
                    .font(.subtitle)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                    .multilineTextAlignment(.center)

                    Card {
                        RowGroup(.divider) {
                            if isDrink {
                                FullWidthInputRow(
                                    placeholder: "Drink Name",
                                    text: $name,
                                    focusOnAppear: isDuplicate,
                                    selectRequest: nameSelectRequest,
                                    cursorToEndRequest: nameCursorRequest,
                                    onFocusChange: { isNameFocused = $0 }
                                ) {
                                    DrinkIconButton(form: drinkForm, isPicking: $showsDrinkIcon)
                                }
                                .nameSuggestionAnchor()
                                if tracksHydration {
                                    DrinkPinRow(form: $drinkForm)
                                    DrinkWaterGoalRow(form: $drinkForm)
                                }
                            } else {
                                FullWidthInputRow(
                                    placeholder: "Name",
                                    text: $name,
                                    focusOnAppear: isDuplicate,
                                    selectRequest: nameSelectRequest,
                                    cursorToEndRequest: nameCursorRequest,
                                    onFocusChange: { isNameFocused = $0 }
                                )
                                .nameSuggestionAnchor()
                                libraryRows
                            }
                        }
                    }
                    .padding([.leading, .trailing])

                    if isDrink {
                        DrinkFormCards(
                            form: $drinkForm,
                            calories: $calorieValue,
                            protein: $proteinValue,
                            carbs: $carbsValue,
                            fat: $fatValue,
                            fiber: $fiberValue,
                            isAIEstimated: $isAIEstimated
                        )

                        Card {
                            RowGroup(.divider) {
                                libraryRows
                            }
                        }
                        .padding([.top, .leading, .trailing])

                        pinnedNoteCard
                    } else {
                        pinnedNoteCard

                    Card {
                        RowGroup(.divider) {
                            BaseRowLayout(title: "Serving Size") {
                                InputPill(
                                    text: $servingSize,
                                    keyboardType: .decimalPad
                                )
                                DropdownPill(
                                    options: servingUnits.map { $0.unit },
                                    selection: $servingSizeUnit
                                )
                            }

                            BaseRowLayout(title: "Serving Weight") {
                                AmountUnitPills(
                                    amount: $servingWeight,
                                    unit: $servingWeightUnit
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
                                titleExtension: "(kcal)",
                                placeholder: "-",
                                text: $calorieValue,
                                keyboardType: .decimalPad
                            )
                            TextInputRow(
                                icon: .protein,
                                title: "Protein",
                                titleExtension: "(g)",
                                placeholder: "-",
                                text: $proteinValue,
                                keyboardType: .decimalPad
                            )
                            TextInputRow(
                                icon: .carbs,
                                title: "Carbohydrates",
                                titleExtension: "(g)",
                                placeholder: "-",
                                text: $carbsValue,
                                keyboardType: .decimalPad
                            )
                            TextInputRow(
                                icon: .fat,
                                title: "Fat",
                                titleExtension: "(g)",
                                placeholder: "-",
                                text: $fatValue,
                                keyboardType: .decimalPad
                            )
                            TextInputRow(
                                icon: .fiber,
                                title: "Fiber",
                                titleExtension: "(g)",
                                placeholder: "-",
                                text: $fiberValue,
                                keyboardType: .decimalPad
                            )

                            ToggleRow(
                                title: "AI Estimated Macros",
                                isOn: $isAIEstimated
                            )
                        }
                    }
                    .padding([.top, .leading, .trailing])

                    Card {
                        RowGroup(.divider) {
                            ToggleRow(
                                title: "Set Custom Default Serving",
                                isOn: $isCustomDefaultServing
                            )

                            if isCustomDefaultServing {
                                BaseRowLayout(
                                    title: "Serving Size",
                                    titleExtension: "(\(servingSizeUnit))"
                                ) {
                                    InputPill(
                                        text: $customServingSize,
                                        keyboardType: .decimalPad
                                    )
                                }
                            }
                        }
                    }
                    .padding([.top, .leading, .trailing])
                    }

                    Spacer()
                }
                .animation(.snappy, value: drinkForm.details)
                .animation(.snappy, value: drinkForm.optionalLines)
                .nameSuggestionPanel(panelMatches, onSelect: applySuggestion)
            }
            .withCustomKeyboardToolbar()
            .navigationTitle("Add New \(entryType.rawValue.capitalized)")
            .toolbarTitleMenu {
                StartFromMenuItem(
                    type: entryType,
                    hasItems: hasStartFromItems
                ) {
                    UIApplication.shared.dismissKeyboard()
                    showsStartFrom = true
                }
                ClearFormMenuItem(isEnabled: canClearForm) { confirmsClear = true }
            }
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

                ToolbarItem(placement: .confirmationAction) {
                    let isAddDisabled =
                        name.trimmingCharacters(in: .whitespacesAndNewlines)
                        .isEmpty
                        || (Double(
                            servingSize.replacingOccurrences(of: ",", with: ".")
                        ) ?? 0) <= 0
                        || (isDrink && (!drinkForm.hasValidVolume || drinkForm.hasIncompleteSizes))
                        || draftState == copiedItem

                    Button {
                        attemptAdd()
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(.primary)
                    }
                    .disabled(isAddDisabled)
                    .tint(Color.accentColor)
                    .buttonStyle(.glassProminent)
                    .savePromptPopover(
                        $savePrompt,
                        dismissesScreen: offersLogNow && rootDismiss != nil
                    )
                }
            }
            .safeAreaBar(edge: .top) {
                Card {
                    MealRow(
                        name: name.isEmpty
                            ? "New \(entryType.rawValue.capitalized)"
                            : name,
                        source: source,
                        isCustomDefaultServing: isCustomDefaultServing,
                        customServingSize: customServingSize,
                        servingSize: servingSize,
                        servingSizeUnit: servingSizeUnit,
                        servingWeight: isDrink ? drinkForm.volume : servingWeight,
                        servingWeightUnit: isDrink ? drinkForm.unit.rawValue : servingWeightUnit,
                        servingUnits: servingUnits,
                        calorie: EntryHelper.scale(
                            isDrink && !drinkForm.details.contains(.nutrition) ? "0" : calorieValue,
                            by: activeMultiplier
                        ),
                        protein: EntryHelper.scale(
                            proteinValue,
                            by: activeMultiplier
                        ),
                        carbs: EntryHelper.scale(
                            carbsValue,
                            by: activeMultiplier
                        ),
                        fat: EntryHelper.scale(
                            fatValue,
                            by: activeMultiplier
                        ),
                        fiber: EntryHelper.scale(
                            fiberValue,
                            by: activeMultiplier
                        )
                    )
                    .nameLineLimit(3)
                    .drink(
                        isDrink
                            ? drinkForm.rowInfo(
                                multiplier: activeMultiplier,
                                calories: calorieValue,
                                protein: proteinValue,
                                carbs: carbsValue,
                                fat: fatValue,
                                fiber: fiberValue
                            ) : nil
                    )
                }
                .padding([.leading, .trailing])
                .padding(.bottom, 24)
            }

        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background && isDraftEnabled && !didFinishAdding {
                saveDraft()
            }
        }
        .environment(focusManager)
        .clearFormAlert(isPresented: $confirmsClear, onClear: clearForm)
        .alert(
            "Replace Details?",
            isPresented: Binding(
                get: { pendingSuggestion != nil },
                set: { if !$0 { pendingSuggestion = nil } }
            ),
            presenting: pendingSuggestion
        ) { match in
            Button("Replace", role: .destructive) { fillFromSuggestion(match) }
            Button("Cancel", role: .cancel) {}
        } message: { match in
            ReplaceDetailsMessage.text(
                from: match.food,
                keepsName: keepsName && !match.fillsName,
                replacesSource: ReplaceDetailsMessage.replaces(typedSource, with: match.food)
            )
        }
        .sheet(isPresented: $showsStartFrom, onDismiss: selectNameAfterPick) {
            StartFromPickerView(
                type: entryType,
                name: name,
                confirmsReplace: hasTypedDetails,
                keepsName: keepsName,
                typedSource: typedSource,
                onSelect: startFrom
            )
        }
        .drinkIconSheet(isPresented: $showsDrinkIcon, form: $drinkForm)
        .onChange(of: name, initial: true) { refreshNameMatches() }
        .onChange(of: filledFromID) { refreshNameMatches() }
        .onAppear {
            hasStartFromItems = entryType == .drink
                || ((try? modelContext.fetchCount(FoodItem.descriptor(for: entryType))) ?? 0) > 0
            if let unit = users.first?.volumeUnit, drinkForm.isPristine, drinkForm.unit != unit {
                drinkForm = DrinkFormState(unit: unit, isPinned: drinkForm.isPinned)
            }
        }
        .onLeave { handleClose() }
        .onDisappear { handleClose() }
        .onDraftDeleted(id: draftID, isEnabled: isResumedDraft) {
            guard !didFinishAdding else { return }
            didFinishAdding = true
            dismiss()
        }
    }

    var body: some View {
        if isPushedView {
            content
        } else {
            NavigationStack {
                content
            }
        }
    }
}

#Preview {
    AddEntryView(entryType: .ingredient)
}
