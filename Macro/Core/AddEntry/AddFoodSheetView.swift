//
//  AddFoodSheetView.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/10/26.
//

import SwiftData
import SwiftUI

struct AddFoodSheetView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext

    var onLogInstantly: ((FoodItem) -> Void)?
    @State private var showSuccessAlert: Bool = false
    @State private var newlySavedFood: FoodItem? = nil

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

    @State private var isIngredientBased: Bool = false
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

    private func addFood() {
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

        let newFood = FoodItem(
            name: name,
            source: resolvedSource,
            category: resolvedCategory,
            servingSize: parseDouble(servingSize),
            servingUnit: resolvedUnit,
            servingWeight: parseOptionalDouble(servingWeight),
            servingWeightUnit: servingWeightUnit,
            isIngredientBased: isIngredientBased,
            isAIEstimated: isAIEstimated,
            calories: parseDouble(calorieValue),
            protein: parseDouble(proteinValue),
            carbs: parseDouble(carbsValue),
            fat: parseDouble(fatValue),
            fiber: parseOptionalDouble(fiberValue),
            isCustomDefaultServing: isCustomDefaultServing,
            customServingSize: parseOptionalDouble(customServingSize)
        )

        modelContext.insert(newFood)

        do {
            try modelContext.save()

            newlySavedFood = newFood
            showSuccessAlert = true
        } catch {
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

                        ButtonRow(
                            icon: .system("document.viewfinder"),
                            title: "Scan Nutrition Label",
                            topPadding: 15,
                            bottomPadding: 5
                        ) {

                        }

                        Card {
                            RowGroup(.divider) {
                                ToggleRow(
                                    title: "Ingredient Based",
                                    isOn: $isIngredientBased
                                )

                                if !isIngredientBased {
                                    TextInputRow(
                                        icon: .custom(Image("Calorie")),
                                        title: "Calories",
                                        titleExtension: "(kcal)",
                                        placeholder: "-",
                                        text: $calorieValue,
                                        keyboardType: .numberPad
                                    )
                                    TextInputRow(
                                        icon: .custom(Image("Protein")),
                                        title: "Protein",
                                        titleExtension: "(g)",
                                        placeholder: "-",
                                        text: $proteinValue,
                                        keyboardType: .numberPad
                                    )
                                    TextInputRow(
                                        icon: .custom(Image("Carbs")),
                                        title: "Carbohydrates",
                                        titleExtension: "(g)",
                                        placeholder: "-",
                                        text: $carbsValue,
                                        keyboardType: .numberPad
                                    )
                                    TextInputRow(
                                        icon: .custom(Image("Fat")),
                                        title: "Fat",
                                        titleExtension: "(g)",
                                        placeholder: "-",
                                        text: $fatValue,
                                        keyboardType: .numberPad
                                    )
                                    TextInputRow(
                                        icon: .custom(Image("Fiber")),
                                        title: "Fiber",
                                        titleExtension: "(g)",
                                        placeholder: "-",
                                        text: $fiberValue,
                                        keyboardType: .numberPad
                                    )
                                }

                                ToggleRow(
                                    title: "AI Estimated Macros",
                                    isOn: $isAIEstimated
                                )
                            }
                        }
                        .padding([.leading, .trailing])

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
                                            keyboardType: .numberPad
                                        )
                                    }
                                }
                            }
                        }
                        .padding([.top, .leading, .trailing])

                        Spacer()
                    }
                }
                .navigationTitle("Add New Food")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundStyle(.tertiary)
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        if name.trimmingCharacters(in: .whitespacesAndNewlines)
                            .isEmpty
                        {
                            Button {
                            } label: {
                                Image(systemName: "plus")
                            }
                            .disabled(true)
                            .tint(Color.tertiary)
                            .buttonStyle(.borderless)

                        } else {
                            Button {
                                addFood()
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
                            name: name.isEmpty ? "New Food" : name,
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
        .alert(
            "\(name) Saved!",
            isPresented: $showSuccessAlert,
            presenting: newlySavedFood
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
    AddFoodSheetView()
}
