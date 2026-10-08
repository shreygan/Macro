//
//  EditRecipeView.swift
//  Macro
//
//  Created by Shrey Gangwar on 6/2/26.
//

import SwiftData
import SwiftUI

enum EditRecipeSaveMode: String, CaseIterable {
    case update = "Update Recipe"
    case updateWithLogs = "Update Recipe & Logs"
    case copy = "Save as Copy"

    var detail: LocalizedStringKey? {
        switch self {
        case .updateWithLogs:
            "Logs where you changed the ingredients won't be updated"
        default:
            nil
        }
    }
}

struct EditRecipeView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext

    var onSaveInstantly: ((FoodItem) -> Void)?
    @State private var showSuccessAlert: Bool = false
    @State private var newlySavedEntry: FoodItem? = nil

    @Query(sort: \EntrySource.displayOrder) var savedSources: [EntrySource]
    @Query(sort: \CategorySource.displayOrder) var savedCategories:
        [CategorySource]
    @Query(sort: \ServingSizeUnit.displayOrder) var servingUnits:
        [ServingSizeUnit]

    let recipe: FoodItem
    var isPushedView: Bool = false

    var isImportMode: Bool = false
    var onImportSave: ((DraftFoodItem) -> Void)?

    @State private var name: String
    @State private var source: String
    @State private var category: String

    @State private var servingSize: String
    @State private var servingSizeUnit: String

    @State private var servingWeight: String
    @State private var servingWeightUnit: String

    @State private var isCustomDefaultServing: Bool
    @State private var customServingSize: String

    @State private var stickyNote: String

    @State private var draftIngredients: [DraftRecipeIngredient]
    @State private var showIngredientSelectionSheet = false

    @State private var saveMode: EditRecipeSaveMode = .update

    @State private var focusManager = SwipeFocusManager()

    @State private var localIngredientToEdit: DraftRecipeIngredient?
    @State private var globalFoodItemToEdit: FoodItem?

    private static func exactString(for value: Double?) -> String {
        guard let value = value else { return "" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = 10
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    init(
        recipe: FoodItem,
        isPushedView: Bool = false,
        onSaveInstantly: ((FoodItem) -> Void)? = nil,
        isImportMode: Bool = false,
        onImportSave: ((DraftFoodItem) -> Void)? = nil
    ) {
        self.recipe = recipe
        self.isPushedView = isPushedView
        self.onSaveInstantly = onSaveInstantly
        self.isImportMode = isImportMode
        self.onImportSave = onImportSave

        _name = State(initialValue: recipe.name)
        _source = State(initialValue: recipe.source?.source ?? "")
        _category = State(initialValue: recipe.category?.category ?? "")

        _servingSize = State(
            initialValue: Self.exactString(for: recipe.servingSize)
        )
        _servingSizeUnit = State(
            initialValue: recipe.servingUnit?.unit ?? "serving"
        )

        _servingWeight = State(
            initialValue: Self.exactString(for: recipe.servingWeight)
        )
        _servingWeightUnit = State(initialValue: recipe.servingWeightUnit)

        _isCustomDefaultServing = State(
            initialValue: recipe.isCustomDefaultServing
        )
        if let customSize = recipe.customServingSize {
            _customServingSize = State(
                initialValue: Self.exactString(for: customSize)
            )
        } else {
            _customServingSize = State(initialValue: "1")
        }

        _stickyNote = State(initialValue: recipe.stickyNote?.text ?? "")

        let existingIngredients = (recipe.recipeIngredients ?? [])
            .sorted { $0.displayOrder < $1.displayOrder }
            .map { DraftRecipeIngredient(recipeIngredient: $0) }
        _draftIngredients = State(initialValue: existingIngredients)
    }

    var totalCalories: Double {
        draftIngredients.reduce(0) { $0 + $1.activeCalories }
    }
    var totalProtein: Double {
        draftIngredients.reduce(0) { $0 + $1.activeProtein }
    }
    var totalCarbs: Double {
        draftIngredients.reduce(0) { $0 + $1.activeCarbs }
    }
    var totalFat: Double { draftIngredients.reduce(0) { $0 + $1.activeFat } }
    var totalFiber: Double {
        draftIngredients.reduce(0) { $0 + $1.activeFiber }
    }

    var displayCalories: Double { totalCalories * recipeMacroMultiplier }
    var displayProtein: Double { totalProtein * recipeMacroMultiplier }
    var displayCarbs: Double { totalCarbs * recipeMacroMultiplier }
    var displayFat: Double { totalFat * recipeMacroMultiplier }
    var displayFiber: Double { totalFiber * recipeMacroMultiplier }

    var displayWeight: Double {
        return totalRecipeWeight * recipeMacroMultiplier
    }

    var defaultPortionSize: Double {
        guard isCustomDefaultServing,
            let custom = Double(customServingSize),
            custom > 0
        else { return 1.0 }
        return custom
    }

    var recipeMacroMultiplier: Double {
        return defaultPortionSize / (Double(servingSize) ?? 1.0)
    }

    var allIngredientsHaveWeight: Bool {
        !draftIngredients.isEmpty
            && draftIngredients.allSatisfy { $0.activeWeight != nil }
    }

    var availableWeightUnits: [String] {
        let units = Set(
            draftIngredients.compactMap {
                $0.baseServingWeightUnit.isEmpty
                    ? nil : $0.baseServingWeightUnit
            }
        )
        return units.isEmpty ? ["g", "ml"] : units.sorted()
    }

    var totalRecipeWeight: Double {
        if let manualWeight = Double(servingWeight) {
            return manualWeight
        }
        return calculatedTotalWeight
    }

    var calculatedTotalWeight: Double {
        draftIngredients.compactMap { $0.activeWeight }.reduce(0, +)
    }

    var shouldShowIngredientIcons: Bool {
        draftIngredients.contains { $0.displayType != .ingredient }
    }

    var isRecipeValid: Bool {
        let isNameValid = !name.trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        let hasIngredients = !draftIngredients.isEmpty
        return isNameValid && hasIngredients && parseDouble(servingSize) > 0
    }

    private func parseDouble(_ string: String) -> Double {
        let normalized = string.replacingOccurrences(of: ",", with: ".")
        return Double(normalized) ?? 0.0
    }

    private func parseOptionalDouble(_ string: String) -> Double? {
        let normalized = string.replacingOccurrences(of: ",", with: ".")
        return string.isEmpty ? nil : Double(normalized)
    }

    private func saveImportDraft() {
        let trimmedNote = stickyNote.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let trimmedUnit = servingSizeUnit.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let ingredients = draftIngredients.map { draft in
            DraftImportIngredient(
                linkedItemID: draft.item?.id,
                linkedItemType: draft.item?.type,
                linkedItemSource: draft.displaySource,
                name: draft.name,
                quantity: parseDouble(draft.quantity),
                unit: draft.unit,
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
        }

        let updatedDraft = DraftFoodItem(
            type: .recipe,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            source: source.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category.trimmingCharacters(in: .whitespacesAndNewlines),
            foodGroup: recipe.foodGroup?.foodGroup ?? "",
            servingSize: parseDouble(servingSize),
            servingUnit: trimmedUnit.isEmpty ? "serving" : trimmedUnit,
            servingWeight: parseOptionalDouble(servingWeight)
                ?? (calculatedTotalWeight > 0 ? calculatedTotalWeight : nil),
            servingWeightUnit: servingWeightUnit,
            isAIEstimated: recipe.isAIEstimated,
            calories: totalCalories,
            protein: totalProtein,
            carbs: totalCarbs,
            fat: totalFat,
            fiber: totalFiber,
            isCustomDefaultServing: isCustomDefaultServing,
            customServingSize: parseOptionalDouble(customServingSize),
            stickyNote: trimmedNote,
            ingredients: ingredients
        )

        onImportSave?(updatedDraft)
        dismiss()
    }

    private func saveRecipe() {
        guard !isImportMode else {
            saveImportDraft()
            return
        }

        // SOURCE
        var resolvedSource: EntrySource? = nil
        let trimmedSource = source.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if !trimmedSource.isEmpty {
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
        let trimmedCategory = category.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if !trimmedCategory.isEmpty {
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

        // SERVING UNIT
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

        let finalWeight =
            parseOptionalDouble(servingWeight)
            ?? (calculatedTotalWeight > 0 ? calculatedTotalWeight : nil)

        let trimmedNote = stickyNote.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        if saveMode != .copy {
            let previousSnapshot = FoodItemSnapshot(recipe)

            recipe.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            recipe.source = resolvedSource
            recipe.category = resolvedCategory
            recipe.servingSize = parseDouble(servingSize)
            recipe.servingUnit = resolvedUnit
            recipe.servingWeight = finalWeight
            recipe.servingWeightUnit = servingWeightUnit
            recipe.isCustomDefaultServing = isCustomDefaultServing
            recipe.customServingSize = parseOptionalDouble(customServingSize)

            if trimmedNote.isEmpty {
                recipe.stickyNote = nil
            } else {
                if let existingNote = recipe.stickyNote {
                    existingNote.text = trimmedNote
                    existingNote.lastUpdated = Date()
                } else {
                    recipe.stickyNote = Note(text: trimmedNote)
                }
            }

            recipe.calories = totalCalories
            recipe.protein = totalProtein
            recipe.carbs = totalCarbs
            recipe.fat = totalFat
            recipe.fiber = totalFiber

            if let oldIngredients = recipe.recipeIngredients {
                for old in oldIngredients {
                    modelContext.delete(old)
                }
            }
            recipe.recipeIngredients = []

            for (index, draft) in draftIngredients.enumerated() {
                let newIngredient = draft.makeRecipeIngredient(
                    quantity: parseDouble(draft.quantity),
                    displayOrder: index,
                    parentRecipe: recipe
                )

                modelContext.insert(newIngredient)
                recipe.recipeIngredients?.append(newIngredient)
            }

            if saveMode == .updateWithLogs {
                LoggedEntryUpdater.apply(
                    recipe,
                    from: previousSnapshot,
                    recipesUpdated: false,
                    in: modelContext
                )
            }

            do {
                try modelContext.save()
                onSaveInstantly?(recipe)
                dismiss()
            } catch {
                print(
                    "Failed to save edited recipe: \(error.localizedDescription)"
                )
            }

        } else {
            let resolvedStickyNote =
                trimmedNote.isEmpty ? nil : Note(text: trimmedNote)

            let newRecipe = FoodItem(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                type: .recipe,
                source: resolvedSource,
                category: resolvedCategory,
                foodGroup: nil,
                servingSize: parseDouble(servingSize),
                servingUnit: resolvedUnit,
                servingWeight: finalWeight,
                servingWeightUnit: servingWeightUnit,
                isAIEstimated: false,
                calories: totalCalories,
                protein: totalProtein,
                carbs: totalCarbs,
                fat: totalFat,
                fiber: totalFiber,
                isCustomDefaultServing: isCustomDefaultServing,
                customServingSize: parseOptionalDouble(customServingSize),
                stickyNote: resolvedStickyNote
            )

            modelContext.insert(newRecipe)

            for (index, draft) in draftIngredients.enumerated() {
                let newIngredient = draft.makeRecipeIngredient(
                    quantity: parseDouble(draft.quantity),
                    displayOrder: index,
                    parentRecipe: newRecipe
                )

                modelContext.insert(newIngredient)
                newRecipe.recipeIngredients?.append(newIngredient)
            }

            do {
                try modelContext.save()
                onSaveInstantly?(newRecipe)
                dismiss()
            } catch {
                print("Failed to clone recipe: \(error.localizedDescription)")
            }
        }
    }

    var content: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            ScrollView {
                VStack {
                    Text("recipe_description")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                        .multilineTextAlignment(.center)

                    Card {
                        RowGroup(.divider) {
                            FullWidthInputRow(
                                placeholder: "Name",
                                text: $name
                            )
                            FullWidthDropdownRow(
                                placeholder: "Source",
                                options: savedSources.visibleNames(keeping: source),
                                selection: $source
                            )
                            FullWidthDropdownRow(
                                placeholder: "Category",
                                options: savedCategories.visibleNames(
                                    keeping: category
                                ),
                                selection: $category
                            )
                        }
                    }
                    .padding([.leading, .trailing])

                    Card {
                        WrappedInputRow(
                            placeholder: "Pinned Note",
                            text: $stickyNote,
                            isEditable: true,
                            characterLimit: 2000
                        )
                    }
                    .padding([.top, .leading, .trailing])

                    Card {
                        RowGroup(.divider) {
                            BaseRowLayout(title: "Recipe Makes") {
                                InputPill(
                                    text: $servingSize,
                                    keyboardType: .decimalPad
                                )
                                DropdownPill(
                                    options: servingUnits.map { $0.unit },
                                    selection: $servingSizeUnit
                                )
                            }

                            BaseRowLayout(title: "Total Weight") {
                                InputPill(
                                    text: $servingWeight,
                                    keyboardType: .decimalPad,
                                    placeholder: calculatedTotalWeight > 0
                                        && allIngredientsHaveWeight
                                        ? String(
                                            format: "%g",
                                            calculatedTotalWeight
                                        )
                                        : "-"
                                )
                                DropdownPill(
                                    options: availableWeightUnits,
                                    displayCustomOption: false,
                                    selection: $servingWeightUnit
                                )
                            }
                        }
                    }
                    .padding([.top, .leading, .trailing])

                    Card("Ingredients") {
                        RowGroup(.divider) {
                            ForEach($draftIngredients) { $draft in
                                let unitConversionBinding = Binding<String>(
                                    get: { draft.unit },
                                    set: { draft.updateUnit(to: $0) }
                                )

                                CustomSwipeRow {
                                    MealRow(
                                        name: draft.name,
                                        source: draft.displaySource,
                                        isCustomDefaultServing: draft
                                            .isCustomDefaultServing,
                                        customServingSize: EntryHelper.format(
                                            draft.activeMultiplier
                                                * draft.baseServingSize
                                        ),
                                        servingSize: EntryHelper.format(
                                            draft.activeMultiplier
                                                * draft.baseServingSize
                                        ),
                                        servingSizeUnit: draft.servingUnitName,
                                        servingWeight: EntryHelper.format(
                                            draft.activeWeight
                                        ),
                                        servingWeightUnit: draft
                                            .baseServingWeightUnit,
                                        servingUnits: servingUnits,
                                        calorie: EntryHelper.format(
                                            draft.activeCalories
                                        ),
                                        protein: EntryHelper.format(
                                            draft.activeProtein
                                        ),
                                        carbs: EntryHelper.format(
                                            draft.activeCarbs
                                        ),
                                        fat: EntryHelper.format(
                                            draft.activeFat
                                        ),
                                        fiber: EntryHelper.format(
                                            draft.activeFiber
                                        ),
                                        icon: shouldShowIngredientIcons
                                            ? draft.displayType.appSymbol : nil
                                    ) {
                                        HStack(spacing: 8) {
                                            InputPill(
                                                text: $draft.quantity,
                                                keyboardType: .decimalPad
                                            )
                                            DropdownPill(
                                                options: draft.unitOptions,
                                                displayCustomOption: false,
                                                selection: unitConversionBinding
                                            )
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        localIngredientToEdit = draft
                                    }
                                } onDelete: {
                                    if let index = draftIngredients.firstIndex(
                                        where: { $0.id == draft.id })
                                    {
                                        draftIngredients.remove(at: index)
                                    }
                                }
                                .transition(
                                    .asymmetric(
                                        insertion: .identity,
                                        removal: .opacity.combined(
                                            with: .scale(scale: 0.9)
                                        )
                                    )
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

                    Spacer()
                }
            }
            .withCustomKeyboardToolbar()
            .navigationTitle("Edit Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showIngredientSelectionSheet) {
                IngredientSelectionView { selectedItem in
                    draftIngredients.append(
                        DraftRecipeIngredient(item: selectedItem)
                    )
                    showIngredientSelectionSheet = false
                }
            }
            //            .sheet(item: $localIngredientToEdit) { draftItem in // TODO: PLEASE GET RID OF THIS FULLY
            //                if let index = draftIngredients.firstIndex(where: {
            //                    $0.id == draftItem.id
            //                }) {
            //                    EditRecipeIngredientView(draft: $draftIngredients[index])
            //                }
            //            }
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

                ToolbarItemGroup(placement: .confirmationAction) {
                    if !isImportMode {
                        Menu {
                            Picker("Save Mode", selection: $saveMode) {
                                ForEach(
                                    EditRecipeSaveMode.allCases,
                                    id: \.self
                                ) { mode in
                                    VStack {
                                        Text(mode.rawValue)
                                        if let detail = mode.detail {
                                            Text(detail)
                                        }
                                    }
                                    .tag(mode)
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(.primary)
                        }
                    }

                    Button {
                        saveRecipe()
                    } label: {
                        Image(systemName: "checkmark")
                            .foregroundStyle(
                                isRecipeValid ? .primary : .tertiary
                            )
                    }
                    .disabled(!isRecipeValid)
                    .tint(isRecipeValid ? Color.blue : Color.tertiary)
                    .buttonStyle(.glassProminent)
                }
            }
            .safeAreaInset(edge: .top) {
                Card {
                    MealRow(
                        name: name.isEmpty ? "Edit Recipe" : name,
                        source: source,
                        isCustomDefaultServing: isCustomDefaultServing,
                        customServingSize: customServingSize,
                        servingSize: "1",
                        servingSizeUnit: servingSizeUnit,
                        servingWeight: allIngredientsHaveWeight
                            ? String(
                                format: "%g",
                                totalRecipeWeight / (Double(servingSize) ?? 1.0)
                            )
                            : "",
                        servingWeightUnit: servingWeightUnit,
                        servingUnits: servingUnits,
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
