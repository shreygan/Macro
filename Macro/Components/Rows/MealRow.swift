//
//  MealRow.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/7/26.
//

import SwiftUI

struct MealRow<Content: View>: View {
    var name: String
    var subtitle: String

    var calorie: String
    var protein: String?
    var carbs: String?
    var fat: String?
    var fiber: String?

    var action: (() -> Void)?

    let content: Content

    init(
        name: String,
        source: String,
        isCustomDefaultServing: Bool,
        customServingSize: String,
        servingSize: String,
        servingSizeUnit: String,
        servingWeight: String,
        servingWeightUnit: String,
        servingUnits: [ServingSizeUnit],
        calorie: String,
        protein: String? = nil,
        carbs: String? = nil,
        fat: String? = nil,
        fiber: String? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.name = name
        self.calorie = calorie
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.action = action
        self.content = content()

        let activeSize =
            isCustomDefaultServing ? customServingSize : servingSize

        let matchedUnitObject = servingUnits.first(where: {
            $0.unit == servingSizeUnit
        })
        let displayUnit =
            matchedUnitObject?.displayString(for: activeSize) ?? servingSizeUnit

        self.subtitle = Self.buildSubtitle(
            source: source,
            activeSize: activeSize,
            displayUnit: displayUnit,
            servingWeight: servingWeight,
            servingWeightUnit: servingWeightUnit,
            isCustomDefaultServing: isCustomDefaultServing,
            originalServingSize: servingSize
        )
    }

    init(
        item: FoodItem,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.name = item.name.isEmpty ? "New Food" : item.name
        self.calorie = String(item.calories)
        self.protein = String(item.protein)
        self.carbs = String(item.carbs)
        self.fat = String(item.fat)
        self.fiber = String(item.fiber)
        self.action = action
        self.content = content()

        let activeSizeNum =
            item.isCustomDefaultServing
            ? (item.customServingSize ?? 0) : item.servingSize
        let activeSizeStr = String(format: "%g", activeSizeNum)

        let displayUnit =
            item.servingUnit?.displayString(for: activeSizeStr) ?? ""

        self.subtitle = Self.buildSubtitle(
            source: item.source?.source ?? "",
            activeSize: activeSizeStr,
            displayUnit: displayUnit,
            servingWeight: item.servingWeight.map { String($0) } ?? "",
            servingWeightUnit: item.servingWeightUnit,
            isCustomDefaultServing: item.isCustomDefaultServing,
            originalServingSize: String(item.servingSize)
        )
    }

    private static func buildSubtitle(
        source: String,
        activeSize: String,
        displayUnit: String,
        servingWeight: String,
        servingWeightUnit: String,
        isCustomDefaultServing: Bool,
        originalServingSize: String
    ) -> String {
        var text =
            source.isEmpty
            ? "\(activeSize) \(displayUnit)"
            : "\(source), \(activeSize) \(displayUnit)"

        if !servingWeight.isEmpty {
            var activeWeightText = servingWeight

            if isCustomDefaultServing,
                let originalSizeNum = Double(originalServingSize),
                let customSizeNum = Double(activeSize),
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

    var body: some View {
        let rowContent = HStack(alignment: .center, spacing: 12) {

            VStack(alignment: .leading, spacing: 2) {

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.tertiary)
                }

                HStack(spacing: 4) {
                    let formattedCalorie =
                        Double(calorie).map {
                            $0.formatted(
                                .number.precision(.fractionLength(0...1))
                            )
                        } ?? calorie
                    macroStat(imageName: "Calorie", text: formattedCalorie)

                    if let protein, let val = Double(protein), val > 0 {
                        macroStat(
                            imageName: "Protein",
                            text: val.formatted(
                                .number.precision(.fractionLength(0...1))
                            )
                        )
                    }

                    if let carbs, let val = Double(carbs), val > 0 {
                        macroStat(
                            imageName: "Carbs",
                            text: val.formatted(
                                .number.precision(.fractionLength(0...1))
                            )
                        )
                    }

                    if let fat, let val = Double(fat), val > 0 {
                        macroStat(
                            imageName: "Fat",
                            text: val.formatted(
                                .number.precision(.fractionLength(0...1))
                            )
                        )
                    }

                    if let fiber, let val = Double(fiber), val > 0 {
                        macroStat(
                            imageName: "Fiber",
                            text: val.formatted(
                                .number.precision(.fractionLength(0...1))
                            )
                        )
                    }
                }
            }

            Spacer(minLength: 16)

            content

            if action != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.tertiary)
            }

        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())

        if let action = action {
            rowContent
                .onTapGesture {
                    action()
                }
        } else {
            rowContent
        }
    }

    private func macroStat(imageName: String, text: String) -> some View {
        HStack(spacing: 3) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .scaleEffect(1.5)
                .frame(width: 8, height: 14)

            Text(text)
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(.primary)
                .padding(.trailing, 5)
        }
    }
}

extension MealRow where Content == EmptyView {
    init(
        name: String,
        source: String,
        isCustomDefaultServing: Bool,
        customServingSize: String,
        servingSize: String,
        servingSizeUnit: String,
        servingWeight: String,
        servingWeightUnit: String,
        servingUnits: [ServingSizeUnit],
        calorie: String,
        protein: String? = nil,
        carbs: String? = nil,
        fat: String? = nil,
        fiber: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.init(
            name: name,
            source: source,
            isCustomDefaultServing: isCustomDefaultServing,
            customServingSize: customServingSize,
            servingSize: servingSize,
            servingSizeUnit: servingSizeUnit,
            servingWeight: servingWeight,
            servingWeightUnit: servingWeightUnit,
            servingUnits: servingUnits,
            calorie: calorie,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: fiber,
            action: action,
            content: { EmptyView() }
        )
    }

    init(
        item: FoodItem,
        action: (() -> Void)? = nil
    ) {
        self.init(
            item: item,
            action: action,
            content: { EmptyView() }
        )
    }
}

#Preview {
    let mockUnits = [
        ServingSizeUnit(unit: "bowl", displayOrder: 1),
        ServingSizeUnit(unit: "chip", pluralVariant: "chips", displayOrder: 2),
    ]

    ZStack {
        Color.gray.opacity(0.15).ignoresSafeArea()

        Card {
            MealRow(
                name: "Grilled Chicken Salad",
                source: "Sweetgreen",
                isCustomDefaultServing: false,
                customServingSize: "",
                servingSize: "1",
                servingSizeUnit: "bowl",
                servingWeight: "",
                servingWeightUnit: "",
                servingUnits: mockUnits,
                calorie: "450",
                protein: "42",
                carbs: "12",
                fat: "18",
                fiber: "6"
            )

            Divider().padding(.leading, 16)

            MealRow(
                name: "Chips",
                source: "Lays",
                isCustomDefaultServing: false,
                customServingSize: "",
                servingSize: "11",
                servingSizeUnit: "chip",
                servingWeight: "50",
                servingWeightUnit: "g",
                servingUnits: mockUnits,
                calorie: "240",
                protein: "48",
                carbs: "6",
                fat: "2"
            ) {
                print("Navigating to meal details...")
            }

            Divider().padding(.leading, 16)

            MealRow(
                name: "Chips Chips Chips ",
                source: "Lays",
                isCustomDefaultServing: false,
                customServingSize: "",
                servingSize: "11",
                servingSizeUnit: "chip",
                servingWeight: "50",
                servingWeightUnit: "g",
                servingUnits: mockUnits,
                calorie: "240",
                protein: "48",
                carbs: "6",
                fat: "2"
            ) {
                HStack(spacing: 8) {
                    InputPill(
                        text: .constant("4"),
                        keyboardType: .decimalPad
                    )
                    DropdownPill(
                        options: ["serving", "g"],
                        displayCustomOption: false,
                        selection: .constant("serving")
                    )
                }
            }
        }
        .padding()
    }
}
