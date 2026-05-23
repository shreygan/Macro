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

    var icon: AppSymbols?

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
        icon: AppSymbols? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.name = name
        self.calorie = calorie
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.icon = icon
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
        icon: AppSymbols? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.name = item.name.isEmpty ? "New Food" : item.name
        self.calorie = String(item.calories)
        self.protein = String(item.protein)
        self.carbs = String(item.carbs)
        self.fat = String(item.fat)
        self.fiber = String(item.fiber)
        self.icon = icon
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
        let parts = subtitle.components(separatedBy: ", ")
        let topText =
            parts.count > 1 ? parts.dropLast().joined(separator: ", ") : ""
        let bottomText = parts.last ?? subtitle

        let rowContent = HStack(alignment: .center, spacing: 12) {

            VStack(alignment: .leading, spacing: 0) {

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        if let icon = icon {
                            icon.image
                                .font(.system(size: 13))
                                .foregroundColor(.tertiary)
                        }
                    }

                    ViewThatFits(in: .horizontal) {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundColor(.tertiary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)

                        VStack(alignment: .leading, spacing: 1) {
                            if !topText.isEmpty {
                                Text(topText)
                                    .font(.system(size: 13))
                                    .foregroundColor(.tertiary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            Text(bottomText)
                                .font(.system(size: 13))
                                .foregroundColor(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                }

                buildAllMacrosText()
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            content
                .layoutPriority(1)
                .padding(.leading, -10)

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

    private func buildMacroText(
        _ icon: RowIcon,
        text: String,
        isFirst: Bool = false
    ) -> Text {
        let prefix = isFirst ? Text("") : Text("  ")

        if case .appSymbol(let symbol, let tint) = icon {
            let imageText = Text(Image(systemName: symbol.rawValue))
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(tint)

            let valueText = Text("\u{00A0}\(text)")
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.primary)

            let strut = Text("\u{200B}")
                .font(.system(size: 16))

            return Text("\(prefix)\(imageText)\(valueText)\(strut)")
        }

        return Text("")
    }

    private func buildAllMacrosText() -> Text {
        let formattedCalorie =
            Double(calorie).map {
                $0.formatted(.number.precision(.fractionLength(0...1)))
            } ?? calorie

        var resultText = buildMacroText(
            .calorie,
            text: formattedCalorie,
            isFirst: true
        )

        if let protein, let val = Double(protein), val > 0 {
            let pText = buildMacroText(
                .protein,
                text: val.formatted(.number.precision(.fractionLength(0...1)))
            )
            resultText = Text("\(resultText)\(pText)")
        }

        if let carbs, let val = Double(carbs), val > 0 {
            let cText = buildMacroText(
                .carbs,
                text: val.formatted(.number.precision(.fractionLength(0...1)))
            )
            resultText = Text("\(resultText)\(cText)")
        }

        if let fat, let val = Double(fat), val > 0 {
            let fText = buildMacroText(
                .fat,
                text: val.formatted(.number.precision(.fractionLength(0...1)))
            )
            resultText = Text("\(resultText)\(fText)")
        }

        if let fiber, let val = Double(fiber), val > 0 {
            let fibText = buildMacroText(
                .fiber,
                text: val.formatted(.number.precision(.fractionLength(0...1)))
            )
            resultText = Text("\(resultText)\(fibText)")
        }

        return resultText
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
        icon: AppSymbols? = nil,
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
            icon: icon,
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
                fiber: "6",
                icon: AppSymbols.food
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
                fat: "2",
                icon: AppSymbols.ingredient
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

            Divider().padding(.leading, 16)

            MealRow(
                name:
                    "Chips Chips Chips Chips Chips Chips Chips Chips Chips Chips",
                source: "Lays Lays Lays Lays ",
                isCustomDefaultServing: false,
                customServingSize: "",
                servingSize: "11",
                servingSizeUnit: "chip",
                servingWeight: "50",
                servingWeightUnit: "g",
                servingUnits: mockUnits,
                calorie: "2400000",
                protein: "48000000",
                carbs: "60000000000000000000",
                fat: "200000",
                fiber: "100",
                icon: .ingredient
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
