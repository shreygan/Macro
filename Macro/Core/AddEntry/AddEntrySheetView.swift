//
//  AddFoodSheetView.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/10/26.
//

import SwiftData
import SwiftUI

struct AddEntrySheetView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext

    let entryType: EntryType
    var isPushedView: Bool = false

    var onSelectInstantly: ((FoodItem) -> Void)?

    var onLogInstantly: ((FoodItem) -> Void)?
    @State private var showSuccessAlert: Bool = false
    @State private var newlySavedEntry: FoodItem? = nil

    @Query(sort: \EntrySource.displayOrder) var savedSources: [EntrySource]
    @Query(sort: \CategorySource.displayOrder) var savedCategories:
        [CategorySource]
    @Query(sort: \FoodGroupSource.displayOrder) var savedFoodGroups:
        [FoodGroupSource]
    @Query(sort: \ServingSizeUnit.displayOrder) var servingUnits:
        [ServingSizeUnit]

    @State private var name: String = ""
    @State private var source: String = ""
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

    var formattedSubtitle: String {
        let activeSize =
            isCustomDefaultServing ? customServingSize : servingSize

        let matchedUnitObject = servingUnits.first(where: {
            $0.unit == servingSizeUnit
        })
        let displayUnit =
            matchedUnitObject?.displayString(for: activeSize) ?? servingSizeUnit

        var text =
            source.isEmpty
            ? "\(activeSize) \(displayUnit)"
            : "\(source), \(activeSize) \(displayUnit)"

        if !servingWeight.isEmpty {
            var activeWeightText = servingWeight

            if isCustomDefaultServing,
                let originalSizeNum = Double(servingSize),
                let customSizeNum = Double(customServingSize),
                let originalWeightNum = Double(servingWeight),
                originalSizeNum > 0
            {
                let multiplier = customSizeNum / originalSizeNum
                let scaledWeight = originalWeightNum * multiplier

                activeWeightText = String(format: "%g", scaledWeight)
            }

            text += " (\(activeWeightText) \(servingWeightUnit))"
        }

        return text
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
        if entryType == .food {
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
        if entryType == .ingredient {
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

        func parseDouble(_ string: String) -> Double {
            let normalized = string.replacingOccurrences(of: ",", with: ".")
            return Double(normalized) ?? 0.0
        }

        func parseOptionalDouble(_ string: String) -> Double? {
            let normalized = string.replacingOccurrences(of: ",", with: ".")
            return string.isEmpty ? nil : Double(normalized)
        }

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
            customServingSize: parseOptionalDouble(customServingSize)
        )

        modelContext.insert(newEntry)

        do {
            try modelContext.save()

            newlySavedEntry = newEntry
            if onLogInstantly != nil {
                showSuccessAlert = true
            } else if onSelectInstantly != nil {
                onSelectInstantly?(newlySavedEntry!)
            } else {
                dismiss()
            }
        } catch {
        }
    }

    var content: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            ScrollView {
                VStack {
                    Text(
                        entryType == .ingredient
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

                            if entryType == .food {
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
            .navigationTitle("Add New \(entryType.rawValue.capitalized)")
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
                    if name.trimmingCharacters(in: .whitespacesAndNewlines)
                        .isEmpty
                    {
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
                            addEntry()
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
                            ? "New \(entryType.rawValue.capitalized)"
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
    AddEntrySheetView(entryType: .ingredient)
}
