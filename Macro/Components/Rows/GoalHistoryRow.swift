//
//  GoalHistoryRow.swift
//  Macro
//
//  Created by Shrey Gangwar on 9/28/26.
//

import SwiftUI

struct GoalHistoryRow: View {
    var goals: UserGoals
    var title: String
    var isCurrent: Bool = false

    private struct MacroDisplay: Identifiable {
        var id: String { title }
        var title: String
        var symbol: AppSymbols
        var tint: Color
        var value: Double
        var mode: GoalLimitMode
        var unit: String
    }

    private var trackedMacros: [MacroDisplay] {
        [
            MacroDisplay(
                title: "Calories",
                symbol: .calorie,
                tint: .calorie,
                value: goals.calories,
                mode: goals.calorieMode,
                unit: "kcal"
            ),
            MacroDisplay(
                title: "Protein",
                symbol: .protein,
                tint: .protein,
                value: goals.protein,
                mode: goals.proteinMode,
                unit: "g"
            ),
            MacroDisplay(
                title: "Carbs",
                symbol: .carbs,
                tint: .carbs,
                value: goals.carbs,
                mode: goals.carbsMode,
                unit: "g"
            ),
            MacroDisplay(
                title: "Fat",
                symbol: .fatfiber,
                tint: .fat,
                value: goals.fat,
                mode: goals.fatMode,
                unit: "g"
            ),
            MacroDisplay(
                title: "Fiber",
                symbol: .fatfiber,
                tint: .fiber,
                value: goals.fiber,
                mode: goals.fiberMode,
                unit: "g"
            ),
        ].filter { $0.mode != .off }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.sectionTitle)
                    .foregroundStyle(.primary)

                if isCurrent {
                    Text("Current")
                        .tagStyle(.accent)
                }

                Spacer()
            }

            if trackedMacros.isEmpty {
                Text("No macros tracked")
                    .font(.subtitle)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(trackedMacros) { macro in
                        HStack(spacing: 6) {
                            Image(systemName: macro.symbol.rawValue)
                                .font(.system(size: 12))
                                .foregroundStyle(macro.tint)
                                .frame(width: 14)

                            Text(macro.title)
                                .font(.subtitle)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text(
                                "\(Int(macro.value)) \(macro.unit) \(macro.mode == .floor ? "min" : "max")"
                            )
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    let goals = UserGoals(
        calories: 2500,
        calorieMode: .ceiling,
        protein: 180,
        proteinMode: .floor,
        carbs: 200,
        carbsMode: .floor,
        fat: 150,
        fatMode: .ceiling,
        fiber: 25,
        fiberMode: .off
    )

    return VStack(spacing: 0) {
        GoalHistoryRow(goals: goals, title: "Since Oct 5", isCurrent: true)
        Divider().padding(.horizontal, 16)
        GoalHistoryRow(goals: goals, title: "Until Oct 4")
    }
    .background(Color(white: 0.96))
    .cornerRadius(24)
    .padding()
}
