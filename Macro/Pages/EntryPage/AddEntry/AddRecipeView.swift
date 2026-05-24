//
//  AddRecipeView.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/17/26.
//

import SwiftData
import SwiftUI

struct DraftRecipeIngredient: Identifiable {
    let id = UUID()
    let item: FoodItem

    var quantity: String = "1"
    var unit: String

    init(item: FoodItem) {
        self.item = item
        self.unit = item.servingUnit?.unit ?? "serving"

        let defaultQty =
            item.isCustomDefaultServing
            ? item.customServingSize : item.servingSize
        self.quantity = EntryHelper.format(defaultQty)
    }

    var activeMultiplier: Double {
        guard let qty = Double(quantity) else { return 0 }

        if unit == item.servingWeightUnit, let baseWeight = item.servingWeight {
            return qty / baseWeight
        }
        return qty / item.servingSize
    }

    var activeCalories: Double { item.calories * activeMultiplier }
    var activeProtein: Double { item.protein * activeMultiplier }
    var activeCarbs: Double { item.carbs * activeMultiplier }
    var activeFat: Double { item.fat * activeMultiplier }
    var activeFiber: Double { item.fiber * activeMultiplier }

    var activeWeight: Double? {
        if unit == item.servingWeightUnit {
            return Double(quantity)
        } else if let baseWeight = item.servingWeight {
            return baseWeight * activeMultiplier
        }
        return nil
    }
}

struct AddRecipeView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext

    var onLogInstantly: ((FoodItem) -> Void)?
    @State private var showSuccessAlert: Bool = false
    @State private var newlySavedEntry: FoodItem? = nil

    @Query(sort: \EntrySource.displayOrder) var savedSources: [EntrySource]
    @Query(sort: \CategorySource.displayOrder) var savedCategories:
        [CategorySource]
    @Query(sort: \ServingSizeUnit.displayOrder) var servingUnits:
        [ServingSizeUnit]

    @State private var name: String = ""
    @State private var source: String = ""
    @State private var category: String = ""

    @State private var servingSize: String = "1"
    @State private var servingSizeUnit: String = "serving"

    @State private var servingWeight: String = ""
    @State private var servingWeightUnit: String = "g"

    @State private var isCustomDefaultServing: Bool = false
    @State private var customServingSize: String = "1"

    @State private var draftIngredients: [DraftRecipeIngredient] = []
    @State private var showIngredientSelectionSheet = false

    @State private var focusManager = SwipeFocusManager()

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
                $0.item.servingWeightUnit.isEmpty
                    ? nil : $0.item.servingWeightUnit
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
        draftIngredients.contains { $0.item.type != .ingredient }
    }

    var isRecipeValid: Bool {
        let isNameValid = !name.trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        let hasIngredients = !draftIngredients.isEmpty

        return isNameValid && hasIngredients
    }

    private func addRecipe() {
        guard isRecipeValid else {
            print(
                "Validation Error: Name and at least one ingredient are required."
            )
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

        func parseDouble(_ string: String) -> Double {
            let normalized = string.replacingOccurrences(of: ",", with: ".")
            return Double(normalized) ?? 0.0
        }

        func parseOptionalDouble(_ string: String) -> Double? {
            let normalized = string.replacingOccurrences(of: ",", with: ".")
            return string.isEmpty ? nil : Double(normalized)
        }

        let finalWeight =
            parseOptionalDouble(servingWeight)
            ?? (calculatedTotalWeight > 0 ? calculatedTotalWeight : nil)

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
            customServingSize: parseOptionalDouble(customServingSize)
        )

        modelContext.insert(newRecipe)

        for (index, draft) in draftIngredients.enumerated() {
            let ingredientQty = parseDouble(draft.quantity)
            let originalItem = draft.item

            let newIngredient = RecipeIngredient(
                quantity: ingredientQty,
                unit: draft.unit,
                displayOrder: index,

                name: originalItem.name,
                baseServingSize: originalItem.servingSize,
                baseServingUnitName: originalItem.servingUnit?.unit,
                baseServingWeight: originalItem.servingWeight,
                baseServingWeightUnit: originalItem.servingWeightUnit,
                baseCalories: originalItem.calories,
                baseProtein: originalItem.protein,
                baseCarbs: originalItem.carbs,
                baseFat: originalItem.fat,
                baseFiber: originalItem.fiber
            )

            newIngredient.ingredientItem = originalItem
            newIngredient.parentRecipe = newRecipe

            modelContext.insert(newIngredient)

            newRecipe.recipeIngredients?.append(newIngredient)
        }

        do {
            try modelContext.save()

            newlySavedEntry = newRecipe
            if onLogInstantly != nil {
                showSuccessAlert = true
            } else {
                dismiss()
            }
        } catch {
            print("Failed to save recipe: \(error.localizedDescription)")
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()

                ScrollView {
                    VStack {
                        Text(
                            "recipe_description"
                        )
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
                                    options: savedSources.map { $0.source },
                                    selection: $source
                                )

                                FullWidthDropdownRow(
                                    placeholder: "Category",
                                    options: savedCategories.map {
                                        $0.category
                                    },
                                    selection: $category
                                )

                            }
                        }
                        .padding([.leading, .trailing])

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
                                    let item = draft.item

                                    let baseUnit =
                                        item.servingUnit?.unit ?? "serving"
                                    let hasWeight = item.servingWeight != nil

                                    let unitConversionBinding = Binding<String>(
                                        get: { draft.unit },
                                        set: { newUnit in
                                            let oldUnit = draft.unit
                                            guard oldUnit != newUnit else {
                                                return
                                            }

                                            let currentMultiplier = draft
                                                .activeMultiplier

                                            if newUnit
                                                == item.servingWeightUnit,
                                                let baseWeight = item
                                                    .servingWeight
                                            {
                                                let convertedQuantity =
                                                    currentMultiplier
                                                    * baseWeight
                                                draft.quantity =
                                                    EntryHelper.format(
                                                        convertedQuantity
                                                    )
                                            } else {
                                                let convertedQuantity =
                                                    currentMultiplier
                                                    * item.servingSize
                                                draft.quantity =
                                                    EntryHelper.format(
                                                        convertedQuantity
                                                    )
                                            }

                                            draft.unit = newUnit
                                        }
                                    )

                                    CustomSwipeRow {
                                        MealRow(
                                            name: item.name,
                                            source: item.source?.source ?? "",
                                            isCustomDefaultServing: item
                                                .isCustomDefaultServing,
                                            customServingSize:
                                                EntryHelper.format(
                                                    draft.activeMultiplier
                                                        * item.servingSize
                                                ),
                                            servingSize: EntryHelper.format(
                                                draft.activeMultiplier
                                                    * item.servingSize
                                            ),
                                            servingSizeUnit: item.servingUnit?
                                                .unit
                                                ?? "serving",
                                            servingWeight: EntryHelper.format(
                                                draft.activeWeight
                                            ),
                                            servingWeightUnit: item
                                                .servingWeightUnit,
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
                                                ? item.type.appSymbol : nil
                                        ) {
                                            HStack(spacing: 8) {
                                                InputPill(
                                                    text: $draft.quantity,
                                                    keyboardType: .decimalPad
                                                )

                                                DropdownPill(
                                                    options: hasWeight
                                                        ? [
                                                            baseUnit,
                                                            item
                                                                .servingWeightUnit,
                                                        ] : [baseUnit],
                                                    displayCustomOption: false,
                                                    selection:
                                                        unitConversionBinding
                                                )
                                            }
                                        }
                                    } onDelete: {
                                        if let index =
                                            draftIngredients.firstIndex(where: {
                                                $0.id == draft.id
                                            })
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
                .scrollDismissesKeyboard(.immediately)
                .navigationTitle("Add New Recipe")
                .navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $showIngredientSelectionSheet) {
                    IngredientSelectionView { selectedItem in
                        draftIngredients.append(
                            DraftRecipeIngredient(item: selectedItem)
                        )
                        showIngredientSelectionSheet = false
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundStyle(.primary)
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        if !isRecipeValid {
                            Button {
                            } label: {
                                Image(systemName: "plus")
                                    .foregroundStyle(.primary)
                            }
                            .disabled(true)
                            .tint(Color.tertiary)
                            .buttonStyle(.borderless)

                        } else {
                            Button {
                                addRecipe()
                            } label: {
                                Image(systemName: "plus")
                                    .foregroundStyle(.primary)
                            }
                            .tint(Color.blue)
                            .buttonStyle(.glassProminent)

                        }
                    }
                }
                .safeAreaInset(edge: .top) {
                    Card {
                        MealRow(
                            name: name.isEmpty
                                ? "New Recipe"
                                : name,
                            source: source,
                            isCustomDefaultServing: isCustomDefaultServing,
                            customServingSize: customServingSize,
                            servingSize: "1",
                            servingSizeUnit: servingSizeUnit,
                            servingWeight: allIngredientsHaveWeight
                                ? String(
                                    format: "%g",
                                    totalRecipeWeight
                                        / (Double(servingSize) ?? 1.0)
                                ) : "",
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
        .alert(
            "\(name) Saved!",
            isPresented: $showSuccessAlert,
            presenting: newlySavedEntry
        ) { food in

            Button("Log Now", role: .confirm) {
                dismiss()
                onLogInstantly?(food)
            }

            Button("Done", role: .cancel) {
                dismiss()
            }

        }
    }
}

#Preview {
    AddRecipeView()
}
