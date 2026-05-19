//
//  AddRecipeSheetView.swift
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

struct AddRecipeSheetView: View {
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

    var recipeDivisor: Double {
        let size = Double(servingSize) ?? 1.0
        return size > 0 ? size : 1.0
    }

    var allIngredientsHaveWeight: Bool {
        !draftIngredients.isEmpty
            && draftIngredients.allSatisfy { $0.activeWeight != nil }
    }

    var calculatedTotalWeight: Double {
        draftIngredients.compactMap { $0.activeWeight }.reduce(0, +)
    }

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
                                    // Auto-fill logic based on your requirements
                                    if allIngredientsHaveWeight {
                                        // UNEDITABLE: All ingredients have weights
                                        Text(
                                            String(
                                                format: "%.1f",
                                                calculatedTotalWeight
                                            )
                                        )
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Color.secondary.opacity(0.1)
                                        )
                                        .cornerRadius(8)
                                    } else {
                                        // EDITABLE: Sum what we can, but let user change it
                                        InputPill(
                                            text: Binding(
                                                get: {
                                                    servingWeight.isEmpty
                                                        && calculatedTotalWeight
                                                            > 0
                                                        ? String(
                                                            format: "%.1f",
                                                            calculatedTotalWeight
                                                        ) : servingWeight
                                                },
                                                set: { servingWeight = $0 }
                                            ),
                                            keyboardType: .decimalPad,
                                            placeholder: calculatedTotalWeight
                                                > 0
                                                ? String(
                                                    format: "%.1f",
                                                    calculatedTotalWeight
                                                ) : "-"
                                        )
                                    }
                                    DropdownPill(
                                        options: ["g", "ml"],
                                        displayCustomOption: false,
                                        selection: $servingWeightUnit
                                    )
                                }
                            }
                        }
                        .padding([.top, .leading, .trailing])

                        // THE INGREDIENTS SECTION
                        Card("Ingredients") {
                            RowGroup(.divider) {
                                ForEach($draftIngredients) { $draft in
                                    let item = draft.item

                                    let baseUnit =
                                        item.servingUnit?.unit ?? "serving"
                                    let hasWeight = item.servingWeight != nil

                                    MealRow(
                                        name: item.name,
                                        source: item.source?.source ?? "",
                                        isCustomDefaultServing: item
                                            .isCustomDefaultServing,
                                        customServingSize: EntryHelper.format(
                                            item.customServingSize
                                        ),
                                        servingSize: EntryHelper.format(
                                            item.servingSize
                                        ),
                                        servingSizeUnit: item.servingUnit?.unit
                                            ?? "serving",
                                        servingWeight: EntryHelper.format(
                                            item.servingWeight
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
                                    ) {
                                        Text("Test")
                                    }
                                }

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
                    IngredientSelectionSheetView { selectedItem in
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
                            servingSize: servingSize,
                            servingSizeUnit: servingSizeUnit,
                            servingWeight: servingWeight,
                            servingWeightUnit: servingWeightUnit,
                            servingUnits: servingUnits,
                            calorie: EntryHelper.format(
                                totalCalories / recipeDivisor
                            ),
                            protein: EntryHelper.format(
                                totalProtein / recipeDivisor
                            ),
                            carbs: EntryHelper.format(
                                totalCarbs / recipeDivisor
                            ),
                            fat: EntryHelper.format(totalFat / recipeDivisor),
                            fiber: EntryHelper.format(
                                totalFiber / recipeDivisor
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
    AddRecipeSheetView()
}
