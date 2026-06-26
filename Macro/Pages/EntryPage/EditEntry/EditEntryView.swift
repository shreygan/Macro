//
//  EditEntryView.swift
//  Macro
//
//  Created by Shrey Gangwar on 6/2/26.
//

import SwiftData
import SwiftUI

enum EditSaveMode: String, CaseIterable {
    case update = "Update Existing"
    case copy = "Save as Copy"
}

struct EditEntryView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext

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

    @State private var type: EntryType

    @State private var name: String
    @State private var source: String
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

    @State private var saveMode: EditSaveMode = .update
    @State private var showUpdateRecipesAlert: Bool = false
    @State private var uniqueRecipesCount: Int = 0

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

        _type = State(initialValue: draftItem?.type ?? foodItem.type)
        _name = State(initialValue: draftItem?.name ?? foodItem.name)
        _source = State(
            initialValue: draftItem?.source ?? foodItem.source?.source ?? ""
        )
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
        if type == .food {
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

        if saveMode == .update {

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

            if cascade {
                let allRecipeIngredients =
                    (try? modelContext.fetch(
                        FetchDescriptor<RecipeIngredient>()
                    )) ?? []
                let usages = allRecipeIngredients.filter {
                    $0.ingredientItem?.id == foodItem.id
                }

                var affectedParentRecipes = Set<FoodItem>()

                for ingredient in usages {
                    ingredient.name = foodItem.name
                    ingredient.baseServingSize = foodItem.servingSize
                    ingredient.baseServingUnitName = foodItem.servingUnit?.unit
                    ingredient.baseServingWeight = foodItem.servingWeight
                    ingredient.baseServingWeightUnit =
                        foodItem.servingWeightUnit
                    ingredient.baseCalories = foodItem.calories
                    ingredient.baseProtein = foodItem.protein
                    ingredient.baseCarbs = foodItem.carbs
                    ingredient.baseFat = foodItem.fat
                    ingredient.baseFiber = foodItem.fiber

                    if let parent = ingredient.parentRecipe {
                        affectedParentRecipes.insert(parent)
                    }
                }

                for recipe in affectedParentRecipes {
                    var newCals = 0.0
                    var newPro = 0.0
                    var newCarbs = 0.0
                    var newFat = 0.0
                    var newFiber = 0.0

                    for ing in recipe.recipeIngredients ?? [] {
                        let baseSize =
                            (ing.unit == ing.baseServingWeightUnit
                                && ing.baseServingWeight != nil)
                            ? ing.baseServingWeight! : ing.baseServingSize
                        let activeMult = EntryHelper.calculateMultiplier(
                            targetPortion: ing.quantity,
                            basePortion: baseSize
                        )

                        newCals += ing.baseCalories * activeMult
                        newPro += ing.baseProtein * activeMult
                        newCarbs += ing.baseCarbs * activeMult
                        newFat += ing.baseFat * activeMult
                        newFiber += ing.baseFiber * activeMult
                    }

                    recipe.calories = newCals
                    recipe.protein = newPro
                    recipe.carbs = newCarbs
                    recipe.fat = newFat
                    recipe.fiber = newFiber
                }
            }

            do {
                try modelContext.save()
                onSaveInstantly?(foodItem)
                dismiss()
            } catch {
                print("Error saving edited entry")
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
                stickyNote: resolvedStickyNote
            )

            modelContext.insert(copiedEntry)
            do {
                try modelContext.save()
                onSaveInstantly?(copiedEntry)
                dismiss()
            } catch {
                print("Error saving cloned entry")
            }
        }
    }

    var content: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            ScrollView {
                VStack {
                    Text(
                        type == .ingredient
                            ? "ingredient_description"
                            : "food_description"
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

                            if type == .food {
                                FullWidthDropdownRow(
                                    placeholder: "Category",
                                    options: savedCategories.map {
                                        $0.category
                                    },
                                    selection: $category
                                )
                            } else {
                                FullWidthDropdownRow(
                                    placeholder: "Food Group",
                                    options: savedFoodGroups.map {
                                        $0.foodGroup
                                    },
                                    selection: $foodGroup
                                )
                            }
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
                                InputPill(
                                    text: $servingWeight,
                                    keyboardType: .decimalPad,
                                    placeholder: "-"
                                )
                                DropdownPill(
                                    options: ["g", "ml"],
                                    displayCustomOption: false,
                                    selection: $servingWeightUnit
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

                    Spacer()
                }
            }
            .withCustomKeyboardToolbar()
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Edit \(type.rawValue.capitalized)")
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
                            let trimmedNote = stickyNote.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )

                            let updatedDraft = DraftFoodItem(
                                type: type,
                                name: name,
                                source: source,
                                category: category,
                                foodGroup: foodGroup,
                                servingSize: parseDouble(servingSize),
                                servingUnit: servingSizeUnit,
                                servingWeight: parseOptionalDouble(
                                    servingWeight
                                ),
                                servingWeightUnit: servingWeightUnit,
                                isAIEstimated: isAIEstimated,
                                calories: parseDouble(calorieValue),
                                protein: parseDouble(proteinValue),
                                carbs: parseDouble(carbsValue),
                                fat: parseDouble(fatValue),
                                fiber: parseDouble(fiberValue),
                                isCustomDefaultServing: isCustomDefaultServing,
                                customServingSize: parseOptionalDouble(
                                    customServingSize
                                ),
                                stickyNote: trimmedNote
                            )
                            onImportSave?(updatedDraft)
                            dismiss()
                        } label: {
                            Image(systemName: "checkmark")
                                .foregroundStyle(
                                    isSaveDisabled ? .tertiary : .primary
                                )
                        }
                        .disabled(isSaveDisabled)
                        .tint(isSaveDisabled ? Color.tertiary : Color.blue)
                        .buttonStyle(.glassProminent)

                    } else {
                        Menu {
                            Picker("Save Mode", selection: $saveMode) {
                                ForEach(EditSaveMode.allCases, id: \.self) {
                                    mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }

                            Divider()

                            Button {
                                type =
                                    type == .food ? .ingredient : .food
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
                            if saveMode == .copy {
                                performSave(cascade: false)
                            } else {
                                let allRecipeIngredients =
                                    (try? modelContext.fetch(
                                        FetchDescriptor<RecipeIngredient>()
                                    )) ?? []
                                let usages = allRecipeIngredients.filter {
                                    $0.ingredientItem?.id == foodItem.id
                                }

                                if usages.isEmpty {
                                    performSave(cascade: false)
                                } else {
                                    let uniqueRecipes = Set(
                                        usages.compactMap { $0.parentRecipe }
                                    )
                                    uniqueRecipesCount = uniqueRecipes.count
                                    showUpdateRecipesAlert = true
                                }
                            }
                        } label: {
                            Image(systemName: "checkmark")
                                .foregroundStyle(
                                    isSaveDisabled ? .tertiary : .primary
                                )
                        }
                        .disabled(isSaveDisabled)
                        .tint(isSaveDisabled ? Color.tertiary : Color.blue)
                        .buttonStyle(.glassProminent)
                    }
                }
            }
            .alert("Update Recipes?", isPresented: $showUpdateRecipesAlert) {
                Button(
                    uniqueRecipesCount > 1
                        ? "Update All Recipes" : "Update Recipe"
                ) {
                    performSave(cascade: true)
                }

                Button("Keep Recipes Unchanged") {
                    performSave(cascade: false)
                }

                Button("Cancel", role: .cancel) {}
            } message: {
                let pluralText =
                    "This item is used in \(uniqueRecipesCount) recipes. Do you want to apply these changes to existing recipes, or leave them as is?"
                let singularText =
                    "This item is used in a recipe. Do you want to apply these changes to that recipe, or leave it as is?"

                Text(uniqueRecipesCount > 1 ? pluralText : singularText)
            }
            .safeAreaInset(edge: .top) {
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
                        servingWeight: servingWeight,
                        servingWeightUnit: servingWeightUnit,
                        servingUnits: servingUnits,
                        calorie: EntryHelper.scale(
                            calorieValue,
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
                }
                .padding([.leading, .trailing])
                .padding(.bottom, 16)
                .background(.ultraThinMaterial)
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
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
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
