//
//  ProgressCard.swift
//  Macro
//
//  Created by Shrey Gangwar on 7/29/26.
//

import SwiftUI

struct DailyProgress {
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double
}

struct ProgressCard: View {
    var goals: UserGoals
    var progress: DailyProgress

    struct MacroConfig: Identifiable {
        var id: String { title }
        var title: String
        var iconSymbol: AppSymbols
        var tintColor: Color
        var current: Double
        var goal: Double
        var mode: GoalLimitMode
        var unit: String
    }

    private var sortedMacros: [MacroConfig] {
        let allMacros = [
            MacroConfig(
                title: "Calories",
                iconSymbol: .calorie,
                tintColor: .red,
                current: progress.calories,
                goal: goals.calories,
                mode: goals.calorieMode,
                unit: "kcal"
            ),
            MacroConfig(
                title: "Protein",
                iconSymbol: .protein,
                tintColor: .blue,
                current: progress.protein,
                goal: goals.protein,
                mode: goals.proteinMode,
                unit: "g"
            ),
            MacroConfig(
                title: "Carbohydrates",
                iconSymbol: .carbs,
                tintColor: .green,
                current: progress.carbs,
                goal: goals.carbs,
                mode: goals.carbsMode,
                unit: "g"
            ),
            MacroConfig(
                title: "Fat",
                iconSymbol: .fatfiber,
                tintColor: .purple,
                current: progress.fat,
                goal: goals.fat,
                mode: goals.fatMode,
                unit: "g"
            ),
            MacroConfig(
                title: "Fiber",
                iconSymbol: .fatfiber,
                tintColor: .yellow,
                current: progress.fiber,
                goal: goals.fiber,
                mode: goals.fiberMode,
                unit: "g"
            ),
        ]

        let tracked = allMacros.filter { $0.mode != .off }
        let untracked = allMacros.filter { $0.mode == .off }

        return tracked + untracked
    }

    var body: some View {
        Card("Progress") {
            VStack(spacing: 20) {
                ForEach(sortedMacros) { config in
                    MacroProgressRow(
                        title: config.title,
                        iconSymbol: config.iconSymbol,
                        tintColor: config.tintColor,
                        current: config.current,
                        goal: config.goal,
                        mode: config.mode,
                        unit: config.unit
                    )
                }
            }
            .padding(.top, 12)
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }
}

#Preview {
    let mockGoals = UserGoals(
        calories: 2500,
        calorieMode: .ceiling,
        protein: 180,
        proteinMode: .floor,
        carbs: 200,
        carbsMode: .off,
        fat: 150,
        fatMode: .off,
        fiber: 25,
        fiberMode: .off
    )

    let mockProgress = DailyProgress(
        calories: 1254,
        protein: 95,
        carbs: 220,
        fat: 220,
        fiber: 25
    )

    ScrollView {
        ProgressCard(goals: mockGoals, progress: mockProgress)
            .padding()
    }
}
