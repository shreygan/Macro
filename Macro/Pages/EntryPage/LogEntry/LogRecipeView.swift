//
//  LogRecipeView.swift
//  Macro
//
//  Created by Shrey Gangwar on 2026-05-20.
//

import SwiftData
import SwiftUI

enum LogRecipeSaveOption: String, CaseIterable, Identifiable {
    case logOnly = "Log Only"
    case updateOriginal = "Log & Update Original"
    case saveAsNew = "Log & Save as New"
    var id: Self { self }
}

struct LogRecipeView: View {
    @Environment(\.dismiss) var dismiss

    @Query(sort: \EntrySource.displayOrder) var sourceOptions: [EntrySource]
    @Query(sort: \CategorySource.displayOrder) var categoryOptions:
        [CategorySource]
    @Query(sort: \ServingSizeUnit.displayOrder) var portionUnitOptions:
        [ServingSizeUnit]

    let recipe: FoodItem
    var name: String
    var isPushedView: Bool = true

    private let isCustomDefaultServing: Bool
    private let customServingSize: String
    private let servingWeight: String
    private let servingWeightUnit: String

    @State private var sourceSelection: String
    @State private var categorySelection: String

    @State private var date = Date()
    @State private var time = Date()
    @State private var location = "TODO"

    @State private var portionQuantity: String
    @State private var portionUnitSelection: String

    @State private var draftIngredients: [LogRecipeIngredient] = []
    @State private var showIngredientSelectionSheet = false

    private let initialSourceSelection: String
    private let initialCategorySelection: String
    private let initialPortionQuantity: String
    private let initialPortionUnitSelection: String
    @State private var initialIngredients: [LogRecipeIngredient] = []
    @State private var saveOption: LogRecipeSaveOption = .logOnly

    @State private var focusManager = SwipeFocusManager()

    var isEdited: Bool {
        draftIngredients != initialIngredients
            || sourceSelection != initialSourceSelection
            || categorySelection != initialCategorySelection
            || portionQuantity != initialPortionQuantity
            || portionUnitSelection != initialPortionUnitSelection
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

    // Dynamic Macro Calculations based on current ingredients
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

    init(recipe: FoodItem, isPushedView: Bool = true) {
        self.recipe = recipe
        self.name = recipe.name
        self.isPushedView = isPushedView

        let startSource = recipe.source?.source ?? "Home"
        let startCategory = recipe.category?.category ?? "Meal"

        self.initialSourceSelection = startSource
        self.initialCategorySelection = startCategory

        _sourceSelection = State(initialValue: startSource)
        _categorySelection = State(initialValue: startCategory)

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

        _portionQuantity = State(initialValue: startPortionQuantity)
        _portionUnitSelection = State(initialValue: startPortionUnit)

        self.isCustomDefaultServing = recipe.isCustomDefaultServing
        self.customServingSize = EntryHelper.format(recipe.customServingSize)
        self.servingWeight = EntryHelper.format(recipe.servingWeight)
        self.servingWeightUnit = recipe.servingWeightUnit

        // Load existing recipe ingredients into the editable draft array
        let existingIngredients =
            recipe.recipeIngredients?
            .sorted(by: { $0.displayOrder < $1.displayOrder })
            .map { LogRecipeIngredient(recipeIngredient: $0) } ?? []

        _initialIngredients = State(initialValue: existingIngredients)
        _draftIngredients = State(initialValue: existingIngredients)
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

                        MealPhotoGalleryCard()
                            .padding([.top, .leading, .trailing])

                        Spacer()
                    }
                }
                .withCustomKeyboardToolbar()
                .scrollDismissesKeyboard(.immediately)
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
                            Picker("Save Options", selection: $saveOption) {
                                ForEach(LogRecipeSaveOption.allCases) {
                                    option in
                                    Text(option.rawValue).tag(option)
                                }
                            }

                            if isEdited {
                                Divider()

                                Button(role: .destructive) {
                                    withAnimation {
                                        draftIngredients =
                                            initialIngredients
                                        sourceSelection =
                                            initialSourceSelection
                                        categorySelection =
                                            initialCategorySelection
                                        portionQuantity =
                                            initialPortionQuantity
                                        portionUnitSelection =
                                            initialPortionUnitSelection
                                        saveOption = .logOnly
                                    }
                                } label: {
                                    Label(
                                        "Reset to Original",
                                        systemImage:
                                            "arrow.counterclockwise"
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
                            // TODO: Implement actual Logging & Saving logic later
                            print(
                                "Log Triggered. Save action: \(saveOption.rawValue)"
                            )

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
            .onChange(of: portionUnitSelection) { oldUnit, newUnit in
                guard oldUnit != newUnit, totalRecipeWeight > 0 else { return }
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
