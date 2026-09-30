//
//  CompactMealRow.swift
//  Macro
//
//  Created by Shrey Gangwar on 9/29/26.
//

import SwiftUI

struct CompactMealRow: View {
    var food: FoodItem

    private var multiplier: Double {
        EntryHelper.defaultPortionMultiplier(for: food)
    }

    var body: some View {
        HStack(spacing: 10) {
            food.type.appSymbol.image
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(food.name.isEmpty ? "New Food" : food.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                macrosLine
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
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
