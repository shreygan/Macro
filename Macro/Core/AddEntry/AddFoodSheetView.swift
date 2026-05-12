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

    var activeMultiplier: Double {
        if isCustomDefaultServing,
            let originalSize = Double(servingSize),
            let customSize = Double(customServingSize),
            originalSize > 0
        {
            return customSize / originalSize
        }
        return 1.0
    }

    func scale(_ valueString: String) -> String? {
        guard !valueString.isEmpty, let value = Double(valueString) else {
            return nil
        }

        let scaledValue = value * activeMultiplier
        return String(format: "%g", scaledValue)
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
                                        keyboardType: .numberPad
                                    )
                                    DropdownPill(
                                        options: servingUnits.map { $0.unit },
                                        selection: $servingSizeUnit
                                    )
                                }

                                BaseRowLayout(title: "Serving Weight") {
                                    InputPill(
                                        text: $servingWeight,
                                        keyboardType: .numberPad,
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
                        Button {
                            //                            addFood()
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
                            title: name.isEmpty ? "New Food" : name,
                            subtitle: formattedSubtitle,
                            calorie: scale(calorieValue) ?? "0",
                            protein: scale(proteinValue),
                            carbs: scale(carbsValue),
                            fat: scale(fatValue),
                            fiber: scale(fiberValue)
                        )
                    }
                    .padding([.leading, .trailing])
                    .padding(.bottom, 16)
                    .background(.ultraThinMaterial)
                }

            }
        }
    }
}

#Preview {
    AddFoodSheetView()
}
