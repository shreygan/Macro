//
//  EditEntryView.swift
//  Macro
//
//  Created by Shrey Gangwar on 6/2/26.
//

import SwiftData
import SwiftUI

enum EditSaveMode: String, CaseIterable {
    case update = "Update Item"
    case updateWithLogs = "Update Item & All Logs"
    case copy = "Save as Copy"
}

struct EditEntryView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.tracksHydration) private var tracksHydration
    @Environment(\.toastCenter) private var toastCenter

    let foodItem: FoodItem
    var isPushedView: Bool = false

    var onSaveInstantly: ((FoodItem) -> Void)?

    var isImportMode: Bool = false
    var initialSourceOverride: String? = nil
    var onImportSave: ((DraftFoodItem) -> Void)?

    @Query(sort: \EntrySource.displayOrder) var savedSources: [EntrySource]
    @Query(sort: \CategorySource.displayOrder) var savedCategories:
        [CategorySource]
    @Query(sort: \FoodGroupSource.displayOrder) var savedFoodGroups:
        [FoodGroupSource]
    @Query(sort: \ServingSizeUnit.displayOrder) var servingUnits:
        [ServingSizeUnit]
    @Query private var users: [User]

    @State private var type: EntryType
    @State private var drinkForm: DrinkFormState
    @State private var showsDrinkIcon = false
    @State private var focusManager = SwipeFocusManager()

    @State private var name: String
    @State private var source: String
    @State private var defaultLocation: EntryLocation?
    @State private var category: String
    @State private var foodGroup: String

    @State private var servingSize: String
    @State private var servingSizeUnit: String

    @State private var servingWeight: String
    @State private var servingWeightUnit: String

    @State private var isAIEstimated: Bool

    @State private var calorieValue: String
    @State private var proteinValue: String
    @State private var carbsValue: String
    @State private var fatValue: String
    @State private var fiberValue: String

    @State private var isCustomDefaultServing: Bool
    @State private var customServingSize: String

    @State private var stickyNote: String

    @State private var saveMode: EditSaveMode = .updateWithLogs
    @State private var savePrompt: SavePromptStep?
    private let initialMacroValues: MacroSanityCheck.Values
    private let initialAlcoholCalories: Double?
    private let initialHasNutrition: Bool
    private let draftItem: DraftFoodItem?

    init(
        foodItem: FoodItem,
        draftItem: DraftFoodItem? = nil,
        isPushedView: Bool = false,
        isImportMode: Bool = false,
        onSaveInstantly: ((FoodItem) -> Void)? = nil,
        onImportSave: ((DraftFoodItem) -> Void)? = nil
    ) {
        self.foodItem = foodItem
        self.isPushedView = isPushedView
        self.isImportMode = isImportMode
        self.onSaveInstantly = onSaveInstantly
        self.onImportSave = onImportSave
        self.draftItem = draftItem

        _type = State(initialValue: draftItem?.type ?? foodItem.type)
        let initialDrinkForm = Self.drinkForm(for: foodItem, draftItem: draftItem, unit: .localeDefault)
        _drinkForm = State(initialValue: initialDrinkForm)
        self.initialAlcoholCalories = initialDrinkForm.alcoholCaloriesPerServing?.rounded()
        self.initialHasNutrition = initialDrinkForm.isOn(.nutrition)
        _name = State(initialValue: draftItem?.name ?? foodItem.name)
        _source = State(
            initialValue: draftItem?.source ?? foodItem.source?.source ?? ""
        )
        _defaultLocation = State(initialValue: foodItem.defaultLocation)
        _category = State(
            initialValue: draftItem?.category ?? foodItem.category?.category
                ?? ""
        )
        _foodGroup = State(
            initialValue: draftItem?.foodGroup ?? foodItem.foodGroup?.foodGroup
                ?? ""
        )

        _servingSize = State(
            initialValue: Self.exactString(
                for: draftItem?.servingSize ?? foodItem.servingSize
            )
        )
        _servingSizeUnit = State(
            initialValue: draftItem?.servingUnit ?? foodItem.servingUnit?.unit
                ?? "serving"
        )

        _servingWeight = State(
            initialValue: Self.exactString(
                for: draftItem?.servingWeight ?? foodItem.servingWeight
            )
        )
        _servingWeightUnit = State(
            initialValue: draftItem?.servingWeightUnit
                ?? foodItem.servingWeightUnit
        )

        _isAIEstimated = State(
            initialValue: draftItem?.isAIEstimated ?? foodItem.isAIEstimated
        )

        _calorieValue = State(
            initialValue: Self.exactString(
                for: draftItem?.calories ?? foodItem.calories
            )
        )
        _proteinValue = State(
            initialValue: Self.exactString(
                for: draftItem?.protein ?? foodItem.protein
            )
        )
        _carbsValue = State(
            initialValue: Self.exactString(
                for: draftItem?.carbs ?? foodItem.carbs
            )
        )
        _fatValue = State(
            initialValue: Self.exactString(for: draftItem?.fat ?? foodItem.fat)
        )
        _fiberValue = State(
            initialValue: Self.exactString(
                for: draftItem?.fiber ?? foodItem.fiber
            )
        )

        _isCustomDefaultServing = State(
            initialValue: draftItem?.isCustomDefaultServing
                ?? foodItem.isCustomDefaultServing
        )

        if let customSize = draftItem?.customServingSize
            ?? foodItem.customServingSize
        {
            _customServingSize = State(
                initialValue: Self.exactString(for: customSize)
            )
        } else {
            _customServingSize = State(initialValue: "1")
        }

        let initialNoteText =
            draftItem?.stickyNote ?? foodItem.stickyNote?.text ?? ""
        _stickyNote = State(initialValue: initialNoteText)

        let initialWeight = Self.exactString(
            for: draftItem?.servingWeight ?? foodItem.servingWeight
        )
        self.initialMacroValues = MacroSanityCheck.Values(
            calories: Self.exactString(for: draftItem?.calories ?? foodItem.calories),
            protein: Self.exactString(for: draftItem?.protein ?? foodItem.protein),
            carbs: Self.exactString(for: draftItem?.carbs ?? foodItem.carbs),
            fat: Self.exactString(for: draftItem?.fat ?? foodItem.fat),
            fiber: Self.exactString(for: draftItem?.fiber ?? foodItem.fiber),
            weight: Double(initialWeight.replacingOccurrences(of: ",", with: ".")),
            weightUnit: draftItem?.servingWeightUnit ?? foodItem.servingWeightUnit
        )
    }

    private var macroValues: MacroSanityCheck.Values {
        MacroSanityCheck.Values(
            calories: calorieValue,
            protein: proteinValue,
            carbs: carbsValue,
            fat: fatValue,
            fiber: fiberValue,
            weight: parseOptionalDouble(servingWeight),
            weightUnit: servingWeightUnit
        )
    }

    private var isDrink: Bool {
        type == .drink
    }

    private static func drinkForm(
        for food: FoodItem,
        draftItem: DraftFoodItem?,
        unit: VolumeUnit
    ) -> DrinkFormState {
        guard let draftItem else { return DrinkFormState(food: food, unit: unit) }
        return DrinkFormState(
            record: draftItem.drink,
            servingVolumeML: draftItem.servingWeightUnit == VolumeUnit.milliliters.rawValue
                ? draftItem.servingWeight : nil,
            unit: unit
        )
    }

    private func convert(to newType: EntryType) {
        if newType == .drink {
            let macros = [calorieValue, proteinValue, carbsValue, fatValue, fiberValue]
            if macros.contains(where: { parseDouble($0) > 0 }) {
                drinkForm.add(.nutrition)
            }
            if !drinkForm.hasValidVolume, servingWeightUnit == VolumeUnit.milliliters.rawValue,
                let volume = parseOptionalDouble(servingWeight), volume > 0
            {
                drinkForm.volume = DrinkFormState.text(forML: volume, unit: drinkForm.unit)
                drinkForm.exactVolumeML = volume
            }
        } else if type == .drink, let volume = drinkForm.servingVolumeML {
            servingWeight = Self.exactString(for: volume)
            servingWeightUnit = VolumeUnit.milliliters.rawValue
        }
        type = newType
    }

    private var conversionTargets: [EntryType] {
        return [.food, .ingredient, .drink].filter { $0 != type }
    }

    private var builtInBase: FoodItem? {
        guard !isImportMode, let key = foodItem.seedKey else { return nil }
        return BuiltInCatalog.preview(for: key)
    }

    private func builtInForm(_ base: FoodItem) -> DrinkFormState {
        var form = DrinkFormState(food: base, unit: drinkForm.unit)
        form.isPinned = drinkForm.isPinned
        form.servingSizeID = drinkForm.servingSizeID
        form.sizes = form.sizes.map { DrinkSizeDraft(name: $0.name, volume: $0.volume, exactML: $0.exactML) }
        return form
    }

    private static func sameDrink(_ lhs: DrinkFormState, _ rhs: DrinkFormState) -> Bool {
        let sizes: (DrinkFormState) -> [[String]] = { $0.sizes.map { [$0.name, $0.volume] } }
        guard sizes(lhs) == sizes(rhs) else { return false }
        var lhs = lhs
        var rhs = rhs
        lhs.sizes = []
        rhs.sizes = []
        lhs.servingSizeID = nil
        rhs.servingSizeID = nil
        return lhs == rhs
    }

    private var matchesBuiltIn: Bool {
        guard let base = builtInBase else { return true }
        return type == base.type && name == base.name && isAIEstimated == base.isAIEstimated
            && parseDouble(calorieValue) == base.calories && parseDouble(proteinValue) == base.protein
            && parseDouble(carbsValue) == base.carbs && parseDouble(fatValue) == base.fat
            && parseDouble(fiberValue) == base.fiber
            && Self.sameDrink(drinkForm, builtInForm(base))
    }

    private func resetToBuiltIn() {
        guard let base = builtInBase else { return }
        type = base.type
        name = base.name
        isAIEstimated = base.isAIEstimated
        calorieValue = Self.exactString(for: base.calories)
        proteinValue = Self.exactString(for: base.protein)
        carbsValue = Self.exactString(for: base.carbs)
        fatValue = Self.exactString(for: base.fat)
        fiberValue = Self.exactString(for: base.fiber)
        drinkForm = builtInForm(base)
    }

    private func attemptSave() {
        let values = isDrink
            ? MacroSanityCheck.Values(
                calories: calorieValue,
                protein: proteinValue,
                carbs: carbsValue,
                fat: fatValue,
                fiber: fiberValue,
                weight: drinkForm.servingVolumeML,
                weightUnit: VolumeUnit.milliliters.rawValue
            )
            : macroValues
        let skipsCheck = isDrink && !drinkForm.details.contains(.nutrition)
        let alcoholCalories = isDrink ? drinkForm.alcoholCaloriesPerServing?.rounded() : nil
        let alcoholIssue = skipsCheck
            ? nil : MacroSanityCheck.alcoholIssue(calories: values.calories, alcoholCalories: alcoholCalories)
        let issue =
            skipsCheck
                || (!isImportMode && values == initialMacroValues && alcoholCalories == initialAlcoholCalories
                    && drinkForm.isOn(.nutrition) == initialHasNutrition)
            ? nil : MacroSanityCheck.issue(for: values, alcoholCalories: alcoholCalories)
        let recipeCount =
            isImportMode || saveMode == .copy ? 0 : recipeUsageCount()
        let recipesStep = recipeCount > 0 ? updateRecipesStep(recipeCount: recipeCount) : nil

        if let issue, issue == alcoholIssue, let alcoholCalories {
            savePrompt = .alcoholCheck(
                issue,
                alcoholCalories: alcoholCalories,
                next: recipesStep,
                onUse: {
                    calorieValue = EntryHelper.format(alcoholCalories)
                    if recipesStep == nil { confirmSave() }
                },
                onSaveAnyway: recipesStep == nil ? confirmSave : {}
            )
        } else if let issue {
            savePrompt = SavePromptStep(
                title: String(localized: "Check Macros?"),
                message: issue,
                actions: [
                    recipesStep.map {
                        SavePromptAction(title: String(localized: "Save Anyway"), next: $0)
                    } ?? SavePromptAction(title: String(localized: "Save Anyway"), action: confirmSave)
                ]
            )
        } else if let recipesStep {
            savePrompt = recipesStep
        } else {
            confirmSave()
        }
    }

    private func updateRecipesStep(recipeCount: Int) -> SavePromptStep {
        let isPlural = recipeCount > 1
        return SavePromptStep(
            title: String(localized: "Update Recipes?"),
            message: isPlural
                ? String(
                    localized:
                        "This item is used in \(recipeCount) recipes. Do you want to apply these changes to existing recipes, or leave them as is?"
                )
                : String(
                    localized:
                        "This item is used in a recipe. Do you want to apply these changes to that recipe, or leave it as is?"
                ),
            actions: [
                SavePromptAction(
                    title: isPlural
                        ? String(localized: "Update All Recipes")
                        : String(localized: "Update Recipe")
                ) {
                    performSave(cascade: true)
                },
                SavePromptAction(title: String(localized: "Keep Recipes Unchanged")) {
                    performSave(cascade: false)
                },
            ]
        )
    }

    private func recipeUsageCount() -> Int {
        let allRecipeIngredients =
            (try? modelContext.fetch(FetchDescriptor<RecipeIngredient>())) ?? []
        let usages = allRecipeIngredients.filter {
            $0.ingredientItem?.id == foodItem.id
        }
        return Set(usages.compactMap { $0.parentRecipe }).count
    }

    private func confirmSave() {
        if isImportMode {
            saveImportDraft()
        } else {
            performSave(cascade: false)
        }
    }

    private func saveImportDraft() {
        let trimmedNote = stickyNote.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        var updatedDraft = DraftFoodItem(
            type: type,
            name: name,
            source: source,
            category: category,
            foodGroup: foodGroup,
            servingSize: parseDouble(servingSize),
            servingUnit: servingSizeUnit,
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
            stickyNote: trimmedNote
        )
        if isDrink {
            let drink = drinkForm.record(keeping: draftItem?.drink)
            updatedDraft.servingWeight = drinkForm.servingVolumeML
            updatedDraft.servingWeightUnit = VolumeUnit.milliliters.rawValue
            updatedDraft.drink = drink
            if !drink.hasNutrition {
                updatedDraft.calories = 0
                updatedDraft.protein = 0
                updatedDraft.carbs = 0
                updatedDraft.fat = 0
                updatedDraft.fiber = 0
            }
        }
        onImportSave?(updatedDraft)
        dismiss()
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

    private func parseDouble(_ string: String) -> Double {
        let normalized = string.replacingOccurrences(of: ",", with: ".")
        return Double(normalized) ?? 0.0
    }

    private func parseOptionalDouble(_ string: String) -> Double? {
        let normalized = string.replacingOccurrences(of: ",", with: ".")
        return string.isEmpty ? nil : Double(normalized)
    }

    private static func exactString(for value: Double?) -> String {
        guard let value = value else { return "" }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = 10
        formatter.minimumFractionDigits = 0

        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private var isSaveDisabled: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || parseDouble(servingSize) <= 0
            || (isDrink && (!drinkForm.hasValidVolume || drinkForm.hasIncompleteSizes))
    }

    private func performSave(cascade: Bool) {
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
        if type == .food || isDrink {
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
        }

        // FOOD GROUP
        var resolvedFoodGroup: FoodGroupSource? = nil
        if type == .ingredient {
            let trimmedGroup = foodGroup.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            if !trimmedGroup.isEmpty {
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

        let trimmedNote = stickyNote.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        if saveMode != .copy {
            let previousSnapshot = FoodItemSnapshot(foodItem)

            foodItem.name = name
            foodItem.type = type
            foodItem.source = resolvedSource
            foodItem.category = resolvedCategory
            foodItem.foodGroup = resolvedFoodGroup
            foodItem.servingSize = parseDouble(servingSize)
            foodItem.servingUnit = resolvedUnit
            foodItem.servingWeight = parseOptionalDouble(servingWeight)
            foodItem.servingWeightUnit = servingWeightUnit
            foodItem.isAIEstimated = isAIEstimated
            foodItem.calories = parseDouble(calorieValue)
            foodItem.protein = parseDouble(proteinValue)
            foodItem.carbs = parseDouble(carbsValue)
            foodItem.fat = parseDouble(fatValue)
            foodItem.fiber = parseDouble(fiberValue)
            foodItem.isCustomDefaultServing = isCustomDefaultServing
            foodItem.customServingSize = parseOptionalDouble(customServingSize)
            foodItem.defaultLocation = defaultLocation
            if trimmedNote.isEmpty {
                foodItem.stickyNote = nil
            } else {
                if let existingNote = foodItem.stickyNote {
                    existingNote.text = trimmedNote
                    existingNote.lastUpdated = Date()
                } else {
                    foodItem.stickyNote = Note(text: trimmedNote)
                }
            }
            if isDrink {
                drinkForm.apply(to: foodItem, in: modelContext)
            } else {
                foodItem.hydrationOrder = nil
            }

            if cascade {
                LoggedEntryUpdater.updateRecipeIngredients(
                    using: foodItem,
                    from: previousSnapshot,
                    in: modelContext
                )
            }

            if saveMode == .updateWithLogs {
                LoggedEntryUpdater.apply(
                    foodItem,
                    from: previousSnapshot,
                    recipesUpdated: cascade,
                    in: modelContext
                )
            }

            do {
                try modelContext.save()
                onSaveInstantly?(foodItem)
                dismiss()
            } catch {
                toastCenter?.show(
                    .failure(String(localized: "Couldn't Save Changes"), message: name)
                )
                modelContext.rollback()
                savePrompt = nil
            }
        } else {
            let resolvedStickyNote =
                trimmedNote.isEmpty ? nil : Note(text: trimmedNote)

            let copiedEntry = FoodItem(
                name: name,
                type: type,
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

            modelContext.insert(copiedEntry)
            if isDrink {
                drinkForm.apply(to: copiedEntry, in: modelContext, asCopy: true)
            }
            do {
                try modelContext.save()
                onSaveInstantly?(copiedEntry)
                if let toastCenter {
                    toastCenter.show(
                        .foodSaved(
                            copiedEntry,
                            title: String(localized: "Saved as Copy"),
                            in: modelContext,
                            presenter: toastCenter
                        )
                    )
                }
                dismiss()
            } catch {
                toastCenter?.show(
                    .failure(String(localized: "Couldn't Save Copy"), message: name)
                )
                modelContext.rollback()
                savePrompt = nil
            }
        }
    }

    @ViewBuilder
    private var libraryRows: some View {
        FullWidthDropdownRow(
            placeholder: "Source",
            options: savedSources.visibleNames(keeping: source),
            selection: $source
        )

        if !isImportMode {
            DefaultLocationRow(
                location: $defaultLocation,
                sourceName: source,
                foodIDs: [foodItem.id]
            )
        }

        if type == .food || isDrink {
            FullWidthDropdownRow(
                placeholder: "Category",
                options: savedCategories.visibleNames(
                    keeping: category
                ),
                selection: $category
            )
        } else {
            FullWidthDropdownRow(
                placeholder: "Food Group",
                options: savedFoodGroups.visibleNames(
                    keeping: foodGroup
                ),
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
                        type == .ingredient
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
                                FullWidthInputRow(placeholder: "Drink Name", text: $name) {
                                    DrinkIconButton(form: drinkForm, isPicking: $showsDrinkIcon)
                                }
                                if !isImportMode, tracksHydration {
                                    DrinkPinRow(form: $drinkForm)
                                }
                                if tracksHydration {
                                    DrinkWaterGoalRow(form: $drinkForm)
                                }
                            } else {
                                FullWidthInputRow(
                                    placeholder: "Name",
                                    text: $name
                                )
                                libraryRows
                            }
                        }
                    }
                    .padding([.leading, .trailing])

                    if !isDrink {
                        pinnedNoteCard
                    }

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
                .animation(.snappy, value: drinkForm.optionalLines)            }
            .withCustomKeyboardToolbar()
            .navigationTitle("Edit \(type.rawValue.capitalized)")
            .navigationBarTitleDisplayMode(.inline)
            .titleMenu(isShown: builtInBase != nil) {
                Button("Reset to Built-In", systemImage: "arrow.counterclockwise") {
                    withAnimation(.snappy) {
                        resetToBuiltIn()
                    }
                }
                .disabled(matchesBuiltIn)
            }
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
                    if isImportMode {
                        Menu {
                            Button {
                                type = type == .food ? .ingredient : .food
                            } label: {
                                Text(
                                    type == .food
                                        ? "Convert to Ingredient"
                                        : "Convert to Food"
                                )
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(.primary)
                        }

                        Button {
                            attemptSave()
                        } label: {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.primary)
                        }
                        .disabled(isSaveDisabled)
                        .tint(Color.accentColor)
                        .buttonStyle(.glassProminent)
                        .savePromptPopover(
                            $savePrompt,
                            dismissesScreen: true
                        )

                    } else {
                        Menu {
                            Picker("Save Mode", selection: $saveMode) {
                                ForEach(EditSaveMode.allCases, id: \.self) {
                                    mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }

                            Divider()

                            ForEach(conversionTargets, id: \.self) { target in
                                Button {
                                    convert(to: target)
                                } label: {
                                    switch target {
                                    case .ingredient: Text("Convert to Ingredient")
                                    case .drink: Text("Convert to Drink")
                                    default: Text("Convert to Food")
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(.primary)
                        }

                        Button {
                            attemptSave()
                        } label: {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.primary)
                        }
                        .disabled(isSaveDisabled)
                        .tint(Color.accentColor)
                        .buttonStyle(.glassProminent)
                        .savePromptPopover(
                            $savePrompt,
                            dismissesScreen: true
                        )
                    }
                }
            }
            .safeAreaBar(edge: .top) {
                Card {
                    MealRow(
                        name: name.isEmpty
                            ? "Edit \(type.rawValue.capitalized)"
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
        .environment(focusManager)
        .drinkIconSheet(isPresented: $showsDrinkIcon, form: $drinkForm)
        .onAppear {
            if let unit = users.first?.volumeUnit, drinkForm.unit != unit,
                drinkForm == Self.drinkForm(for: foodItem, draftItem: draftItem, unit: drinkForm.unit)
            {
                drinkForm = Self.drinkForm(for: foodItem, draftItem: draftItem, unit: unit)
            }
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
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: FoodItem.self,
            EntrySource.self,
            CategorySource.self,
            FoodGroupSource.self,
            ServingSizeUnit.self,
            configurations: config
        )

        let context = container.mainContext

        let mockSource = EntrySource(source: "Chipotle", displayOrder: 1)
        let mockCategory = CategorySource(category: "Lunch", displayOrder: 1)
        let mockUnit = ServingSizeUnit(unit: "bowl", displayOrder: 1)

        context.insert(mockSource)
        context.insert(mockCategory)
        context.insert(mockUnit)

        let mockFood = FoodItem(
            name: "Double Chicken Bowl",
            type: .food,
            source: mockSource,
            category: mockCategory,
            foodGroup: nil,
            servingSize: 1.0,
            servingUnit: mockUnit,
            servingWeight: nil,
            servingWeightUnit: "g",
            isAIEstimated: false,
            calories: 850.0,
            protein: 65.0,
            carbs: 70.0,
            fat: 32.0,
            fiber: 10.0,
            isCustomDefaultServing: false
        )

        context.insert(mockFood)

        return EditEntryView(foodItem: mockFood)
            .modelContainer(container)

    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
