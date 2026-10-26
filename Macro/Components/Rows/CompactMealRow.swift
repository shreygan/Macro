//
//  CompactMealRow.swift
//  Macro
//
//  Created by Shrey Gangwar on 9/29/26.
//

import SwiftUI

struct CompactMealRow: View {
    var food: FoodItem
    var note: String?

    @Environment(\.volumeUnit) private var volumeUnit
    @Environment(\.tracksHydration) private var tracksHydration

    private var multiplier: Double {
        EntryHelper.defaultPortionMultiplier(for: food)
    }

    var body: some View {
        HStack(spacing: 10) {
            if food.type == .drink {
                DrinkBadge(symbol: food.drinkSymbol, tint: food.drinkTint)
                    .frame(width: 18)
            } else {
                Image(systemName: food.rowSymbolName)
                    .font(.smallIcon)
                    .foregroundStyle(Color.tertiaryText)
                    .frame(width: 18)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(food.name.isEmpty ? "New Food" : food.name)
                    .font(.compactTitle)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let drinkLine {
                    Text(drinkLine)
                        .font(.detail)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    macrosLine
                }
            }

            Spacer(minLength: 0)

            if let note {
                Text(note)
                    .font(.detail)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var drinkLine: String? {
        guard let drink = DrinkRowInfo(food: food), !drink.hasMacros else { return nil }
        let line = [drink.amountText(unit: volumeUnit), drink.factsText(unit: volumeUnit, includesHydration: tracksHydration)]
            .compactMap(\.self)
            .joined(separator: " · ")
        return line.isEmpty ? nil : line
    }

    private var visibleMacros: [(RowIcon, Double)] {
        [
            (RowIcon.protein, food.protein),
            (RowIcon.carbs, food.carbs),
            (RowIcon.fat, food.fat),
            (RowIcon.fiber, food.fiber),
        ].filter { $0.1 > 0 }
    }

    private var macrosLine: some View {
        let multiplier = multiplier
        let macros = visibleMacros.map { ($0.0, $0.1 * multiplier) }
        let calories = food.calories * multiplier

        return ViewThatFits(in: .horizontal) {
            ForEach(Array(stride(from: macros.count, to: 0, by: -1)), id: \.self) { count in
                macrosText(calories: calories, macros: Array(macros.prefix(count)))
                    .fixedSize(horizontal: true, vertical: false)
            }

            macrosText(calories: calories, macros: [])
                .lineLimit(1)
        }
        .font(.system(size: 11, design: .rounded))
    }

    private func macrosText(calories: Double, macros: [(RowIcon, Double)]) -> Text {
        var result = macroText(.calorie, value: calories, isFirst: true)
        for (icon, value) in macros {
            result = Text("\(result)\(macroText(icon, value: value, isFirst: false))")
        }
        return result
    }

    private func macroText(_ icon: RowIcon, value: Double, isFirst: Bool) -> Text {
        icon.macroText(
            EntryHelper.formatMacro(value),
            iconSize: 10,
            valueSize: 11,
            valueColor: .secondary,
            isFirst: isFirst
        )
    }
}
