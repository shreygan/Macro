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
    var servingVolumeML: Double?

    var icon: AppSymbols?
    var source = ""
    var drink: DrinkRowInfo?

    var calorie: String
    var protein: String?
    var carbs: String?
    var fat: String?
    var fiber: String?

    var action: (() -> Void)?
    var isSelected: Bool?
    var tag: LocalizedStringKey?
    var nameLineLimit: Int?
    var location: String?
    var hasNote = false
    var hasPhotos = false
    var alias: String?

    let content: Content

    @Environment(\.volumeUnit) private var volumeUnit
    @Environment(\.tracksHydration) private var tracksHydration

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
        self.source = source
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

        (self.subtitle, self.servingVolumeML) = Self.buildSubtitle(
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
        self.source = item.source?.source ?? ""
        self.drink = DrinkRowInfo(food: item)
        self.action = action
        self.content = content()

        let activeSizeNum =
            item.isCustomDefaultServing
            ? (item.customServingSize ?? 0) : item.servingSize
        let activeSizeStr = String(format: "%g", activeSizeNum)

        let displayUnit =
            item.servingUnit?.displayString(for: activeSizeStr) ?? ""

        (self.subtitle, self.servingVolumeML) = Self.buildSubtitle(
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
    ) -> (String, Double?) {
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

            if servingWeightUnit == VolumeUnit.milliliters.rawValue,
                let milliliters = Double(activeWeightText)
            {
                return (text, milliliters)
            }
            text += " (\(activeWeightText) \(servingWeightUnit))"
        }
        return (text, nil)
    }

    var body: some View {
        let drinkAmount = drink?.amountText(unit: volumeUnit)
        let servingSubtitle = servingVolumeML.map {
            "\(self.subtitle) (\(volumeUnit.formattedAmount($0)))"
        } ?? self.subtitle
        let parts: [String] =
            drinkAmount.map { [source, $0].filter { !$0.isEmpty } }
            ?? servingSubtitle.components(separatedBy: ", ")
        let separator = drinkAmount == nil ? ", " : " · "
        let subtitle = drinkAmount == nil ? servingSubtitle : parts.joined(separator: separator)
        let topText =
            parts.count > 1 ? parts.dropLast().joined(separator: separator) : ""
        let bottomText = parts.last ?? subtitle

        let rowContent = HStack(alignment: .center, spacing: 12) {

            VStack(alignment: .leading, spacing: 0) {

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(name)
                            .font(.compactTitle)
                            .foregroundColor(.primary)
                            .lineLimit(nameLineLimit)
                            .fixedSize(horizontal: false, vertical: true)

                        if let drink {
                            DrinkBadge(symbol: drink.symbol, tint: drink.tint)
                        } else if let icon = icon {
                            icon.image
                                .font(.smallIcon)
                                .foregroundColor(.tertiaryText)
                        }

                        if let tag {
                            Text(tag)
                                .tagStyle()
                                .fixedSize()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    ViewThatFits(in: .horizontal) {
                        subtitleLine(subtitle)
                            .font(.subtitle)
                            .foregroundColor(.tertiaryText)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)

                        VStack(alignment: .leading, spacing: 1) {
                            if !topText.isEmpty {
                                Text(topText)
                                    .font(.subtitle)
                                    .foregroundColor(.tertiaryText)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            subtitleLine(bottomText)
                                .font(.subtitle)
                                .foregroundColor(.tertiaryText)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }

                    if let facts = drink?.factsText(unit: volumeUnit, includesHydration: tracksHydration) {
                        Text(facts)
                            .font(.subtitle)
                            .foregroundColor(.tertiaryText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }

                if drink?.hasMacros ?? true {
                    buildAllMacrosText()
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            content
                .layoutPriority(1)
                .padding(.leading, -10)

            if let alias {
                AliasNote(alias: alias)
            }

            AttachmentHints(hasNote: hasNote, hasPhotos: hasPhotos)

            if let isSelected {
                Image(
                    systemName: isSelected ? "checkmark.circle.fill" : "circle"
                )
                .font(.system(size: 22))
                .foregroundStyle(isSelected ? Color.accentColor : .tertiaryText)
                .contentTransition(.symbolEffect(.replace))
            } else if action != nil {
                Image(systemName: "chevron.right")
                    .font(.chevron)
                    .foregroundColor(.tertiaryText)
            }

        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())

        if let action, let isSelected {
            rowContent
                .onTapGesture {
                    action()
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(
                    isSelected ? [.isButton, .isSelected] : .isButton
                )
        } else if let action = action {
            rowContent
                .onTapGesture {
                    action()
                }
        } else {
            rowContent
        }
    }

    private func subtitleLine(_ text: String) -> Text {
        Text.detailLine([text], location: location) ?? Text(text)
    }

    private func buildMacroText(
        _ icon: RowIcon,
        text: String,
        isFirst: Bool = false
    ) -> Text {
        guard case .appSymbol = icon else { return Text("") }

        let macro = icon.macroText(
            text,
            iconSize: 12,
            valueSize: 12,
            valueColor: .primary,
            isFirst: isFirst
        )
        let strut = Text("\u{200B}")
            .font(.rowValue)

        return Text("\(macro)\(strut)")
    }

    private func buildAllMacrosText() -> Text {
        let formattedCalorie = Double(calorie).map(EntryHelper.formatMacro) ?? calorie

        var resultText = buildMacroText(
            .calorie,
            text: formattedCalorie,
            isFirst: true
        )

        if let protein, let val = Double(protein), val > 0 {
            let pText = buildMacroText(
                .protein,
                text: EntryHelper.formatMacro(val)
            )
            resultText = Text("\(resultText)\(pText)")
        }

        if let carbs, let val = Double(carbs), val > 0 {
            let cText = buildMacroText(
                .carbs,
                text: EntryHelper.formatMacro(val)
            )
            resultText = Text("\(resultText)\(cText)")
        }

        if let fat, let val = Double(fat), val > 0 {
            let fText = buildMacroText(
                .fat,
                text: EntryHelper.formatMacro(val)
            )
            resultText = Text("\(resultText)\(fText)")
        }

        if let fiber, let val = Double(fiber), val > 0 {
            let fibText = buildMacroText(
                .fiber,
                text: EntryHelper.formatMacro(val)
            )
            resultText = Text("\(resultText)\(fibText)")
        }

        return resultText
    }

    func selectionState(_ isSelected: Bool) -> Self {
        var row = self
        row.isSelected = isSelected
        return row
    }

    func nameTag(_ tag: LocalizedStringKey?) -> Self {
        var row = self
        row.tag = tag
        return row
    }

    func nameLineLimit(_ limit: Int?) -> Self {
        var row = self
        row.nameLineLimit = limit
        return row
    }

    func location(_ name: String?) -> Self {
        var row = self
        row.location = name
        return row
    }

    func drink(_ info: DrinkRowInfo?) -> Self {
        var row = self
        row.drink = info
        return row
    }

    func aliasNote(_ alias: String?) -> Self {
        var row = self
        row.alias = alias
        return row
    }

    func attachmentHints(hasNote: Bool, hasPhotos: Bool) -> Self {
        var row = self
        row.hasNote = hasNote
        row.hasPhotos = hasPhotos
        return row
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

    init(
        food: FoodItem,
        servingUnits: [ServingSizeUnit],
        icon: AppSymbols? = nil,
        action: (() -> Void)? = nil
    ) {
        let displayPortion = EntryHelper.defaultPortion(for: food)
        let multiplier = EntryHelper.defaultPortionMultiplier(for: food)
        let scaled = { (value: Double) in
            EntryHelper.scale(EntryHelper.format(value), by: multiplier)
        }

        self.init(
            name: food.name,
            source: food.source?.source ?? "",
            isCustomDefaultServing: food.isCustomDefaultServing,
            customServingSize: EntryHelper.format(food.customServingSize),
            servingSize: EntryHelper.format(displayPortion),
            servingSizeUnit: food.servingUnit?.unit ?? "serving",
            servingWeight: EntryHelper.format(food.servingWeight),
            servingWeightUnit: food.servingWeightUnit,
            servingUnits: servingUnits,
            calorie: scaled(food.calories),
            protein: scaled(food.protein),
            carbs: scaled(food.carbs),
            fat: scaled(food.fat),
            fiber: scaled(food.fiber),
            icon: icon,
            action: action
        )
        self.drink = DrinkRowInfo(food: food)
    }
}

#Preview {
    let mockUnits = [
        ServingSizeUnit(unit: "bowl", displayOrder: 1),
        ServingSizeUnit(unit: "chip", pluralVariant: "chips", displayOrder: 2),
    ]

    ZStack {
        Color.background.ignoresSafeArea()

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
