//
//  GoalHistoryRow.swift
//  Macro
//
//  Created by Shrey Gangwar on 9/28/26.
//

import SwiftUI

struct GoalHistoryRow: View {
    @Environment(\.volumeUnit) private var volumeUnit
    @Environment(\.tracksHydration) private var tracksHydration

    var goals: UserGoals
    var title: String
    var isCurrent: Bool = false

    private struct MacroDisplay: Identifiable {
        var id: String { title }
        var title: String
        var symbol: String
        var tint: Color
        var valueText: String
        var mode: GoalLimitMode
    }

    private var trackedMacros: [MacroDisplay] {
        [
            MacroDisplay(
                title: "Calories",
                symbol: AppSymbols.calorie.rawValue,
                tint: .calorie,
                valueText: "\(Int(goals.calories)) kcal",
                mode: goals.calorieMode
            ),
            MacroDisplay(
                title: "Protein",
                symbol: AppSymbols.protein.rawValue,
                tint: .protein,
                valueText: "\(Int(goals.protein)) g",
                mode: goals.proteinMode
            ),
            MacroDisplay(
                title: "Carbs",
                symbol: AppSymbols.carbs.rawValue,
                tint: .carbs,
                valueText: "\(Int(goals.carbs)) g",
                mode: goals.carbsMode
            ),
            MacroDisplay(
                title: "Fat",
                symbol: AppSymbols.fatfiber.rawValue,
                tint: .fat,
                valueText: "\(Int(goals.fat)) g",
                mode: goals.fatMode
            ),
            MacroDisplay(
                title: "Fiber",
                symbol: AppSymbols.fatfiber.rawValue,
                tint: .fiber,
                valueText: "\(Int(goals.fiber)) g",
                mode: goals.fiberMode
            ),
            MacroDisplay(
                title: "Water",
                symbol: "drop.fill",
                tint: DrinkTint.blue.color,
                valueText: volumeUnit.formattedTotal(goals.water),
                mode: tracksHydration && goals.water > 0 ? goals.waterMode : .off
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
                Text("No goals tracked")
                    .font(.subtitle)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(trackedMacros) { macro in
                        HStack(spacing: 6) {
                            Image(systemName: macro.symbol)
                                .font(.detail)
                                .foregroundStyle(macro.tint)
                                .frame(width: 14)

                            Text(macro.title)
                                .font(.subtitle)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Group {
                                if macro.mode == .floor {
                                    Text("\(macro.valueText) min")
                                } else {
                                    Text("\(macro.valueText) max")
                                }
                            }
                            .font(.subtitleEmphasis)
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
